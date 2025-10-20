"""
DOM360 Backend API - FastAPI with RBAC
Integra PostgreSQL com Agent API (SDR/COPILOT) + Master/Tenant RBAC
"""

import os
import json
import logging
from datetime import datetime
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager
import re
import sys

import httpx
import psycopg2
from psycopg2.pool import SimpleConnectionPool
from psycopg2.extras import RealDictCursor
from fastapi import FastAPI, HTTPException, Header, Depends, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# Add parent directory to path to import config
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from config import (
    DATABASE_CONFIG,
    BACKEND_BIND_HOST,
    BACKEND_BIND_PORT,
    CORS_ORIGINS,
    LOG_LEVEL
)

# Import RBAC modules - handle both relative and absolute imports
try:
    # Try relative imports first (when imported as backend.server_rbac)
    from .auth import (
        AuthContext,
        UserRole,
        get_current_user,
        get_optional_user,
        require_tenant_access,
        set_rls_context
    )
    from .api import auth_router, admin_router
except ImportError:
    # Fall back to absolute imports (when run directly as python server_rbac.py)
    sys.path.insert(0, os.path.dirname(__file__))
    from auth import (
        AuthContext,
        UserRole,
        get_current_user,
        get_optional_user,
        require_tenant_access,
        set_rls_context
    )
    from api import auth_router, admin_router

# Configuração de logging
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL, logging.INFO),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configurações
PORT = BACKEND_BIND_PORT

# Pool de conexões global
db_pool: Optional[SimpleConnectionPool] = None


# ============================================================================
# Lifecycle Management
# ============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Gerencia o ciclo de vida da aplicação"""
    global db_pool
    
    # Startup
    logger.info("🚀 Iniciando DOM360 Backend API com RBAC...")
    try:
        db_pool = SimpleConnectionPool(
            minconn=2,
            maxconn=10,
            **DATABASE_CONFIG
        )
        logger.info("✓ Pool de conexões PostgreSQL criado")
        logger.info("✓ RBAC Master/Tenant ativado")
    except Exception as e:
        logger.error(f"✗ Erro ao conectar PostgreSQL: {e}")
        raise
    
    yield
    
    # Shutdown
    logger.info("Encerrando DOM360 Backend API...")
    if db_pool:
        db_pool.closeall()
        logger.info("✓ Pool de conexões fechado")


# ============================================================================
# FastAPI App
# ============================================================================

app = FastAPI(
    title="DOM360 Backend API",
    description="API com RBAC Master/Tenant para PostgreSQL e Agent API",
    version="2.0.0",
    lifespan=lifespan
)

# CORS - Configuração segura para produção
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)


# ============================================================================
# Middleware: Database Connection
# ============================================================================

@app.middleware("http")
async def db_session_middleware(request: Request, call_next):
    """
    Injects database connection into request.state
    """
    conn = None
    try:
        if db_pool:
            conn = db_pool.getconn()
            request.state.db = conn
        
        response = await call_next(request)
        return response
        
    finally:
        if conn and db_pool:
            db_pool.putconn(conn)


# ============================================================================
# Include Routers
# ============================================================================

# Authentication & User Management
app.include_router(auth_router)

# Admin (Master Only)
app.include_router(admin_router)


# ============================================================================
# Models (Chat-specific)
# ============================================================================

class ChatMessage(BaseModel):
    """Mensagem de chat"""
    message: str = Field(..., min_length=1, description="Conteúdo da mensagem")
    conversation_id: Optional[str] = Field(None, description="ID da conversa existente")
    agent_type: str = Field("SDR", description="Tipo de agente (SDR ou COPILOT)")
    user_phone: str = Field(..., description="Telefone do usuário")
    user_name: Optional[str] = Field(None, description="Nome do usuário")
    
    def get_db_agent_type(self) -> str:
        """Convert frontend agent_type to database enum value"""
        mapping = {
            'SDR': 'chat_sdr',
            'COPILOT': 'chat_closer',
            'SUPPORT': 'chat_support',
            # Also accept database values directly
            'chat_sdr': 'chat_sdr',
            'chat_closer': 'chat_closer',
            'chat_support': 'chat_support',
        }
        return mapping.get(self.agent_type.upper(), 'chat_sdr')


class MessageResponse(BaseModel):
    """Resposta com mensagem"""
    conversation_id: str
    message_id: str
    agent_response: str
    tokens_used: int
    created_at: str


class ConversationMessage(BaseModel):
    """Mensagem de uma conversa"""
    message_id: str
    role: str
    content: str
    created_at: str
    metadata: Optional[Dict[str, Any]] = None


class DashboardData(BaseModel):
    """Dados do dashboard"""
    total_conversations: int
    total_messages: int
    total_tokens: int
    conversations_by_agent: Dict[str, int]
    daily_consumption: List[Dict[str, Any]]


# ============================================================================
# Helper Functions
# ============================================================================

def get_sdr_agent_endpoint(conn) -> str:
    """Get SDR agent endpoint from master_settings"""
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cursor.execute("SELECT sdr_agent_endpoint, sdr_agent_timeout_ms FROM master_settings LIMIT 1")
        settings = cursor.fetchone()
        
        if settings:
            return settings['sdr_agent_endpoint'], settings['sdr_agent_timeout_ms']
        
        logger.warning("Master settings not found, using fallback endpoint")
        pass
        
    finally:
        cursor.close()


def query_with_rls(conn, query: str, params: tuple, user: AuthContext):
    """Executa query com contexto RLS do usuário"""
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    try:
        # Set RLS context
        set_rls_context(cursor, user)
        
        # Execute query
        cursor.execute(query, params)
        
        if query.strip().upper().startswith('SELECT'):
            result = cursor.fetchall()
            return result
        else:
            conn.commit()
            if cursor.description:
                return cursor.fetchall()
            return None
    except Exception as e:
        conn.rollback()
        logger.error(f"Erro na query: {e}")
        raise
    finally:
        cursor.close()


# ============================================================================
# Agent API Integration
# ============================================================================

async def call_agent_api(
    conn,
    agent_type: str,
    message: str,
    conversation_history: List[Dict] = None,
    tenant_id: int = 1,
    inbox_id: int = 27,
    user_phone: str = "+5511999999999",
    conversation_id: str = None
) -> Dict:
    """Chama API do Agente (SDR ou COPILOT) usando endpoint configurado"""
    
    # Get endpoint from master_settings
    agent_endpoint, timeout_ms = get_sdr_agent_endpoint(conn)
    
    # Determine the correct endpoint based on agent type
    # Map database enum values to API endpoints
    agent_type_upper = agent_type.upper()
    if agent_type_upper in ('SDR', 'CHAT_SDR'):
        endpoint_path = "/sdr"
    elif agent_type_upper in ('COPILOT', 'CHAT_CLOSER'):
        endpoint_path = "/copilot"
    elif agent_type_upper in ('SUPPORT', 'CHAT_SUPPORT'):
        endpoint_path = "/support"
    else:
        # Default to SDR
        endpoint_path = "/sdr"
    
    endpoint = f"{agent_endpoint.rstrip('/')}{endpoint_path}"
    
    # Convert database enum back to API format
    agent_type_for_api = {
        'chat_sdr': 'SDR',
        'chat_closer': 'COPILOT',
        'chat_support': 'SUPPORT',
        'SDR': 'SDR',
        'COPILOT': 'COPILOT',
        'SUPPORT': 'SUPPORT'
    }.get(agent_type, 'SDR')
    
    # Build payload according to SDR API spec
    payload = {
        "request_id": f"req_{datetime.utcnow().timestamp()}",
        "tenant": {
            "tenant_id": tenant_id,
            "chatwoot_account_id": tenant_id,
            "chatwoot_account_name": f"Tenant {tenant_id}",
            "chatwoot_host": "app.chatwoot.com"
        },
        "routing": {
            "inbox_id": inbox_id,
            "agent_type": agent_type_for_api
        },
        "message": {
            "content": message,
            "content_type": "text"
        },
        "sender": {
            "phone_e164": user_phone
        },
        "conversation": {
            "id": conversation_id or "new"
        },
        "rag_options": {
            "enabled": True,
            "top_k": 5,
            "return_chunks": True,
            "match_threshold": 0.7
        }
    }
    
    # Defensive validations before sending to Agent API
    # Ensure routing.agent_type matches endpoint expectations
    if endpoint_path == "/sdr":
        # Agent contract requires routing.agent_type == "SDR"
        if payload.get('routing', {}).get('agent_type') != 'SDR':
            logger.warning("routing.agent_type did not equal 'SDR' for /sdr endpoint, forcing to 'SDR'")
            payload.setdefault('routing', {})['agent_type'] = 'SDR'

    # Validate phone is in E.164 format if provided
    phone = payload.get('sender', {}).get('phone_e164')
    if phone:
        # Basic E.164 check: starts with + and digits, reasonable length (7-15 digits)
        if not re.match(r'^\+\d{7,15}$', phone):
            logger.error(f"Invalid phone format for Agent API call: {phone}")
            raise HTTPException(status_code=400, detail=f"INVALID_PHONE_FORMAT: expected E.164, got: {phone}")

    logger.info(f"Chamando Agent API: {endpoint} (timeout: {timeout_ms}ms)")
    logger.debug(f"Payload: {payload}")
    
    try:
        async with httpx.AsyncClient(timeout=timeout_ms / 1000.0) as client:
            headers = {
                "Content-Type": "application/json",
                "X-Request-ID": payload.get('request_id', '')
            }

            response = await client.post(endpoint, json=payload, headers=headers)

            # If the agent returned 4xx/5xx, capture the body for easier debugging
            if response.status_code >= 400:
                body = None
                try:
                    body = response.text
                except Exception:
                    body = '<unreadable body>'
                logger.error(f"Agent API returned status={response.status_code}, body={body}")
                # Raise HTTPException with safe detail (avoid leaking sensitive internals)
                raise HTTPException(status_code=502, detail=f"Agent API error: {response.status_code}")

            data = response.json()
            
            # Transform SDR response to our expected format
            agent_output = data.get('agent_output', {})
            usage = data.get('usage', {})
            
            transformed_response = {
                'response': agent_output.get('text', ''),
                'tokens': {
                    'input': usage.get('input_tokens', 0),
                    'output': usage.get('output_tokens', 0),
                    'total': usage.get('total_tokens', 0)
                },
                'latency_ms': data.get('latency_ms', 0),
                'model': usage.get('model', 'unknown'),
                'tool_calls': agent_output.get('tool_calls', []),
                'rag_context': agent_output.get('rag_context', [])
            }
            
            logger.info(f"✓ Agent API respondeu: {len(transformed_response['response'])} chars")
            return transformed_response
            
    except httpx.TimeoutException:
        logger.error("Timeout ao chamar Agent API")
        raise HTTPException(status_code=504, detail="Agent API timeout")
    except httpx.HTTPError as e:
        logger.error(f"Erro HTTP na Agent API: {e}")
        raise HTTPException(status_code=502, detail=f"Agent API error: {str(e)}")
    except Exception as e:
        logger.error(f"Erro ao chamar Agent API: {e}")
        raise HTTPException(status_code=500, detail=f"Agent API call failed: {str(e)}")


# ============================================================================
# Public Endpoints
# ============================================================================

@app.get("/api/health")
async def health_check(request: Request):
    """Health check endpoint"""
    conn = request.state.db
    
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
        
        return {
            "status": "healthy",
            "database": "connected",
            "rbac": "enabled",
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "database": "disconnected",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }


# ============================================================================
# Chat Endpoints (RBAC Protected)
# ============================================================================

@app.post("/api/chat")
async def send_chat_message(
    data: ChatMessage,
    request: Request,
    user: AuthContext = Depends(get_current_user),
    x_inbox_id: str = Header(..., alias="X-Inbox-ID")
):
    """
    Envia mensagem para o agente e salva no banco
    
    **Requires authentication** (JWT token)
    
    Fluxo:
    1. Buscar/criar conversa (com RLS tenant_id)
    2. Salvar mensagem do usuário
    3. Chamar Agent API (endpoint configurado em master_settings)
    4. Salvar resposta do agente
    5. Retornar resposta
    """
    conn = request.state.db

    # Log incoming headers for debugging auth/tenant issues
    try:
        logger.info(f"Incoming /api/chat request headers: {dict(request.headers)}")
    except Exception:
        # Non-fatal, continue
        logger.debug("Could not stringify request headers")

    # Convert inbox_id to integer (after migration, inbox_id is INTEGER not UUID)
    try:
        inbox_id_int = int(x_inbox_id)
    except (ValueError, TypeError):
        raise HTTPException(
            status_code=400,
            detail=f"X-Inbox-ID must be a valid integer, got: {x_inbox_id}"
        )
    
    # Log do payload recebido para debug
    logger.info(f"📨 Chat payload - message='{data.message}', conversation_id='{data.conversation_id}', agent_type='{data.agent_type}', user_phone='{data.user_phone}', user_name='{data.user_name}'")

    try:
        # 1. Buscar ou criar conversa
        conversation_id = None
        
        # Validar se conversation_id é um UUID válido
        if data.conversation_id:
            try:
                import uuid
                uuid.UUID(data.conversation_id)
                conversation_id = data.conversation_id
            except (ValueError, AttributeError):
                # Não é um UUID válido, será criada uma nova conversa
                logger.warning(f"conversation_id inválido recebido: {data.conversation_id}, criando nova conversa")
                conversation_id = None
        
        if not conversation_id:
            # Criar nova conversa (RLS aplicado)
            db_agent_type = data.get_db_agent_type()
            logger.info(f"Creating conversation with: tenant_id={user.tenant_id}, inbox_id={inbox_id_int}, agent_type={db_agent_type}, user_phone={data.user_phone}, user_name={data.user_name}")
            
            query = """
                INSERT INTO conversations (tenant_id, inbox_id, agent_type, contact_phone_e164, contact_name, status)
                VALUES (%s, %s, %s, %s, %s, 'open')
                RETURNING id
            """
            result = query_with_rls(
                conn, query,
                (user.tenant_id, inbox_id_int, db_agent_type, data.user_phone, data.user_name or 'Usuário'),
                user
            )
            conversation_id = str(result[0]['id'])
            logger.info(f"✓ Nova conversa criada: {conversation_id} (tenant: {user.tenant_id}, inbox: {inbox_id_int})")
        
        # 2. Obter próximo message_index
        query = """
            SELECT COALESCE(MAX(message_index), 0) + 1 as next_index
            FROM messages
            WHERE conversation_id = %s
        """
        result = query_with_rls(conn, query, (conversation_id,), user)
        message_index = result[0]['next_index']
        
        # 3. Salvar mensagem do usuário
        db_agent_type = data.get_db_agent_type()
        query = """
            INSERT INTO messages (
                tenant_id, conversation_id, inbox_id, message_index, role, user_message,
                agent_type, created_at
            )
            VALUES (%s, %s, %s, %s, 'user', %s, %s, NOW())
            RETURNING id, created_at
        """
        result = query_with_rls(
            conn, query,
            (user.tenant_id, conversation_id, inbox_id_int, message_index, data.message, db_agent_type),
            user
        )
        user_message_id = str(result[0]['id'])
        # capture created_at returned by the INSERT
        try:
            user_message_created_at = result[0]['created_at'].isoformat()
        except Exception:
            user_message_created_at = datetime.utcnow().isoformat()
        
        # 3. Buscar histórico da conversa
        query = """
            SELECT role, user_message, assistant_message
            FROM messages
            WHERE conversation_id = %s
            ORDER BY message_index ASC
        """
        history_result = query_with_rls(conn, query, (conversation_id,), user)
        
        conversation_history = []
        for msg in history_result:
            if msg['role'] == 'user' and msg['user_message']:
                conversation_history.append({
                    "role": "user",
                    "content": msg['user_message']
                })
            elif msg['role'] == 'assistant' and msg['assistant_message']:
                conversation_history.append({
                    "role": "assistant",
                    "content": msg['assistant_message']
                })
        
        # 4. Chamar Agent API (usando endpoint configurado)
        agent_response = await call_agent_api(
            conn,
            db_agent_type,  # Use converted value
            data.message,
            conversation_history,
            tenant_id=int(user.tenant_id) if user.tenant_id else 1,
            inbox_id=inbox_id_int,
            user_phone=data.user_phone,
            conversation_id=conversation_id
        )
        
        # 5. Obter próximo message_index para resposta
        query = """
            SELECT COALESCE(MAX(message_index), 0) + 1 as next_index
            FROM messages
            WHERE conversation_id = %s
        """
        result = query_with_rls(conn, query, (conversation_id,), user)
        assistant_message_index = result[0]['next_index']
        
        # 6. Salvar resposta do agente
        query = """
            INSERT INTO messages (
                tenant_id, conversation_id, inbox_id, message_index, role, assistant_message,
                agent_type, input_tokens, output_tokens, latency_ms, model_used, created_at
            )
            VALUES (%s, %s, %s, %s, 'assistant', %s, %s, %s, %s, %s, %s, NOW())
            RETURNING id, created_at
        """
        result = query_with_rls(
            conn, query,
            (
                user.tenant_id,
                conversation_id,
                inbox_id_int,
                assistant_message_index,
                agent_response.get('response', ''),
                db_agent_type,  # Use converted value
                agent_response.get('tokens', {}).get('input', 0),
                agent_response.get('tokens', {}).get('output', 0),
                agent_response.get('latency_ms', 0),
                agent_response.get('model', 'unknown')
            ),
            user
        )
        
        assistant_message_id = str(result[0]['id'])
        created_at = result[0]['created_at'].isoformat()
        
        total_tokens = (
            agent_response.get('tokens', {}).get('input', 0) +
            agent_response.get('tokens', {}).get('output', 0)
        )
        
        logger.info(f"✓ Mensagem processada: conversation_id={conversation_id}, tokens={total_tokens}")

        # Build response payload expected by frontend
        response_payload = {
            'conversation_id': conversation_id,
            'user_message': {
                'id': user_message_id,
                'index': message_index,
                'content': data.message,
                'created_at': user_message_created_at,
            },
            'assistant_message': {
                'id': assistant_message_id,
                'index': assistant_message_index,
                'content': agent_response.get('response', ''),
                'tool_calls': agent_response.get('tool_calls', []),
                'rag_context': agent_response.get('rag_context', []),
                'created_at': created_at,
            },
            'tokens_used': total_tokens,
            'agent_response': agent_response.get('response', ''),
        }

        return response_payload
        
    except HTTPException:
        raise
    except Exception as e:
        # Log full traceback for debugging
        logger.exception("Unhandled error while processing /api/chat")
        # Return a clearer error detail to the caller (avoid leaking sensitive internals)
        raise HTTPException(
            status_code=500,
            detail=f"Failed to process message: {str(e)}"
        )


@app.get("/api/conversations")
async def list_conversations(
    request: Request,
    user: AuthContext = Depends(get_current_user),
    limit: int = 50,
    offset: int = 0
):
    """
    Lista conversas do tenant do usuário (RLS aplicado)
    """
    conn = request.state.db
    
    try:
        query = """
            SELECT 
                c.id, c.agent_type, c.status, c.contact_name, c.contact_phone_e164,
                c.lead_status, c.lead_score, c.created_at, c.last_message_at,
                COUNT(m.id) as message_count
            FROM conversations c
            LEFT JOIN messages m ON m.conversation_id = c.id
            WHERE c.tenant_id = %s
            GROUP BY c.id
            ORDER BY c.last_message_at DESC NULLS LAST, c.created_at DESC
            LIMIT %s OFFSET %s
        """
        
        conversations = query_with_rls(
            conn, query,
            (user.tenant_id, limit, offset),
            user
        )
        
        return [dict(c) for c in conversations]
        
    except Exception as e:
        logger.error(f"Erro ao listar conversas: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to list conversations: {str(e)}"
        )


@app.get("/api/conversations/{conversation_id}/messages")
async def get_conversation_messages(
    conversation_id: str,
    request: Request,
    user: AuthContext = Depends(get_current_user),
    limit: int = 100,
    offset: int = 0
):
    """
    Retorna mensagens de uma conversa (RLS aplicado)
    """
    conn = request.state.db
    
    try:
        query = """
            SELECT 
                m.id, m.role, m.user_message, m.assistant_message,
                m.input_tokens, m.output_tokens, m.latency_ms,
                m.created_at, m.metadata
            FROM messages m
            WHERE m.conversation_id = %s
            ORDER BY m.message_index ASC
            LIMIT %s OFFSET %s
        """
        
        messages = query_with_rls(
            conn, query,
            (conversation_id, limit, offset),
            user
        )
        
        result = []
        for msg in messages:
            content = msg['user_message'] if msg['role'] == 'user' else msg['assistant_message']
            result.append(ConversationMessage(
                message_id=str(msg['id']),
                role=msg['role'],
                content=content or '',
                created_at=msg['created_at'].isoformat(),
                metadata=msg.get('metadata')
            ))
        
        return result
        
    except Exception as e:
        logger.error(f"Erro ao buscar mensagens: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get messages: {str(e)}"
        )


@app.get("/api/dashboard", response_model=DashboardData)
async def get_dashboard_data(
    request: Request,
    user: AuthContext = Depends(get_current_user),
    from_date: Optional[str] = None,
    to_date: Optional[str] = None
):
    """
    Dashboard com métricas do tenant do usuário (RLS aplicado)
    
    MASTER vê métricas globais, outros veem apenas seu tenant
    """
    conn = request.state.db
    
    try:
        # Totals
        query = """
            SELECT 
                COUNT(DISTINCT c.id) as total_conversations,
                COUNT(DISTINCT m.id) as total_messages,
                COALESCE(SUM(m.input_tokens + m.output_tokens), 0) as total_tokens
            FROM conversations c
            LEFT JOIN messages m ON m.conversation_id = c.id
            WHERE c.tenant_id = %s
        """
        
        params = [user.tenant_id]
        
        if from_date:
            query += " AND c.created_at >= %s"
            params.append(from_date)
        
        if to_date:
            query += " AND c.created_at <= %s"
            params.append(to_date)
        
        totals = query_with_rls(conn, query, tuple(params), user)[0]
        
        # By agent type
        query = """
            SELECT agent_type, COUNT(*) as count
            FROM conversations
            WHERE tenant_id = %s
            GROUP BY agent_type
        """
        
        by_agent = query_with_rls(conn, query, (user.tenant_id,), user)
        conversations_by_agent = {row['agent_type']: row['count'] for row in by_agent}
        
        # Daily consumption
        query = """
            SELECT 
                date_window::text as date,
                SUM(total_tokens) as tokens,
                SUM(message_count) as messages
            FROM consumption_inbox_daily
            WHERE tenant_id = %s
            GROUP BY date_window
            ORDER BY date_window DESC
            LIMIT 30
        """
        
        daily = query_with_rls(conn, query, (user.tenant_id,), user)
        
        return DashboardData(
            total_conversations=totals['total_conversations'],
            total_messages=totals['total_messages'],
            total_tokens=totals['total_tokens'],
            conversations_by_agent=conversations_by_agent,
            daily_consumption=[dict(d) for d in daily]
        )
        
    except Exception as e:
        logger.error(f"Erro ao buscar dashboard: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get dashboard data: {str(e)}"
        )


# ============================================================================
# Main
# ============================================================================

if __name__ == "__main__":
    import uvicorn
    logger.info(f"🚀 Iniciando DOM360 Backend em {BACKEND_BIND_HOST}:{BACKEND_BIND_PORT}")
    uvicorn.run(
        app,
        host=BACKEND_BIND_HOST,
        port=BACKEND_BIND_PORT,
        reload=False,
        log_level=LOG_LEVEL.lower()
    )
