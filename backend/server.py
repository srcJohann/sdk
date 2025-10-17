"""
DOM360 Backend API - FastAPI
Integra PostgreSQL com Agent API (SDR/COPILOT)
"""

import os
import json
import logging
from datetime import datetime
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager

import httpx
import psycopg2
from psycopg2.pool import SimpleConnectionPool
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Header, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# Carregar variáveis de ambiente
# Carrega do diretório raiz se existir, senão do diretório atual
env_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env')
if not os.path.exists(env_path):
    env_path = '.env'
load_dotenv(dotenv_path=env_path)

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configurações
DATABASE_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': int(os.getenv('DB_PORT', 5432)),
    'database': os.getenv('DB_NAME', 'dom360_db'),
    'user': os.getenv('DB_USER', 'postgres'),
    'password': os.getenv('DB_PASSWORD', ''),
}

AGENT_API_URL = os.getenv('AGENT_API_URL', 'http://localhost:8000')
PORT = int(os.getenv('BACKEND_PORT', 3001))

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
    logger.info("Iniciando DOM360 Backend API...")
    try:
        db_pool = SimpleConnectionPool(
            minconn=2,
            maxconn=10,
            **DATABASE_CONFIG
        )
        logger.info("✓ Pool de conexões PostgreSQL criado")
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
    description="API para integração com PostgreSQL e Agent API",
    version="1.0.0",
    lifespan=lifespan
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Em produção, especificar domínios
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================================
# Models
# ============================================================================

class ChatMessage(BaseModel):
    """Mensagem de chat"""
    message: str = Field(..., min_length=1, description="Conteúdo da mensagem")
    conversation_id: Optional[str] = Field(None, description="ID da conversa existente")
    agent_type: str = Field("SDR", description="Tipo de agente (SDR ou COPILOT)")
    user_phone: str = Field(..., description="Telefone do usuário")
    user_name: Optional[str] = Field(None, description="Nome do usuário")


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
# Database Helpers
# ============================================================================

def get_db_connection():
    """Obtém conexão do pool"""
    if not db_pool:
        raise HTTPException(status_code=500, detail="Database pool not initialized")
    try:
        conn = db_pool.getconn()
        return conn
    except Exception as e:
        logger.error(f"Erro ao obter conexão: {e}")
        raise HTTPException(status_code=500, detail="Database connection failed")


def release_db_connection(conn):
    """Devolve conexão ao pool"""
    if db_pool and conn:
        db_pool.putconn(conn)


def query_with_tenant(conn, query: str, params: tuple, tenant_id: str):
    """Executa query com contexto de tenant (RLS)"""
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    try:
        # Definir contexto do tenant
        cursor.execute(f"SET app.tenant_id = '{tenant_id}'")
        
        # Executar query
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

async def call_agent_api(agent_type: str, message: str, conversation_history: List[Dict] = None) -> Dict:
    """Chama API do Agente (SDR ou COPILOT)"""
    endpoint = f"{AGENT_API_URL}/chat"
    
    payload = {
        "agent_type": agent_type,
        "message": message,
        "conversation_history": conversation_history or []
    }
    
    logger.info(f"Chamando Agent API: {endpoint}")
    
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(endpoint, json=payload)
            response.raise_for_status()
            data = response.json()
            
            logger.info(f"✓ Agent API respondeu: {len(data.get('response', ''))} chars")
            return data
            
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
# Endpoints
# ============================================================================

@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
        release_db_connection(conn)
        
        return {
            "status": "healthy",
            "database": "connected",
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "database": "disconnected",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }


@app.post("/api/chat", response_model=MessageResponse)
async def send_chat_message(
    data: ChatMessage,
    x_tenant_id: str = Header(..., alias="X-Tenant-ID"),
    x_inbox_id: str = Header(..., alias="X-Inbox-ID")
):
    """
    Envia mensagem para o agente e salva no banco
    
    Fluxo:
    1. Buscar/criar conversa
    2. Salvar mensagem do usuário
    3. Chamar Agent API
    4. Salvar resposta do agente
    5. Retornar resposta
    """
    conn = None
    
    try:
        conn = get_db_connection()
        
        # 1. Buscar ou criar conversa
        if data.conversation_id:
            conversation_id = data.conversation_id
        else:
            # Criar nova conversa
            query = """
                INSERT INTO conversations (tenant_id, inbox_id, agent_type, contact_phone_e164, contact_name, status)
                VALUES (%s, %s, %s, %s, %s, 'open')
                RETURNING id
            """
            result = query_with_tenant(
                conn, query,
                (x_tenant_id, x_inbox_id, data.agent_type, data.user_phone, data.user_name or 'Usuário'),
                x_tenant_id
            )
            conversation_id = str(result[0]['id'])
            logger.info(f"✓ Nova conversa criada: {conversation_id}")
        
        # 2. Salvar mensagem do usuário
        query = """
            INSERT INTO messages (
                tenant_id, conversation_id, inbox_id, role, user_message,
                agent_type, created_at
            )
            VALUES (%s, %s, %s, 'user', %s, %s, NOW())
            RETURNING id, message_index
        """
        result = query_with_tenant(
            conn, query,
            (x_tenant_id, conversation_id, x_inbox_id, data.message, data.agent_type),
            x_tenant_id
        )
        user_message_id = str(result[0]['id'])
        
        # 3. Buscar histórico da conversa (últimas 10 mensagens)
        query = """
            SELECT 
                role,
                COALESCE(user_message, assistant_message) as content
            FROM messages
            WHERE conversation_id = %s
            ORDER BY message_index DESC
            LIMIT 10
        """
        history_result = query_with_tenant(
            conn, query,
            (conversation_id,),
            x_tenant_id
        )
        conversation_history = [
            {"role": msg['role'], "content": msg['content']}
            for msg in reversed(history_result)
        ]
        
        # 4. Chamar Agent API
        agent_response = await call_agent_api(
            data.agent_type,
            data.message,
            conversation_history
        )
        
        response_text = agent_response.get('response', 'Erro ao processar resposta')
        tokens_used = agent_response.get('tokens_used', 0)
        agent_metadata = agent_response.get('metadata', {})
        
        # 5. Salvar resposta do agente
        query = """
            INSERT INTO messages (
                tenant_id, conversation_id, inbox_id, role, assistant_message,
                agent_type, input_tokens, output_tokens, metadata, created_at
            )
            VALUES (%s, %s, %s, 'assistant', %s, %s, %s, %s, %s, NOW())
            RETURNING id, created_at
        """
        result = query_with_tenant(
            conn, query,
            (x_tenant_id, conversation_id, x_inbox_id, response_text, 
             data.agent_type, tokens_used, tokens_used, json.dumps(agent_metadata)),
            x_tenant_id
        )
        agent_message_id = str(result[0]['id'])
        created_at = result[0]['created_at'].isoformat()
        
        # 6. Registrar consumo
        query = """
            INSERT INTO consumption_inbox_daily (
                tenant_id, inbox_id, date_window, agent_id,
                total_tokens, total_messages, total_conversations
            )
            VALUES (%s, %s, CURRENT_DATE, 
                    (SELECT id FROM agents WHERE tenant_id = %s AND agent_type = %s LIMIT 1),
                    %s, 1, 1)
            ON CONFLICT (tenant_id, inbox_id, date_window, agent_id)
            DO UPDATE SET
                total_tokens = consumption_inbox_daily.total_tokens + %s,
                total_messages = consumption_inbox_daily.total_messages + 1,
                updated_at = NOW()
        """
        query_with_tenant(
            conn, query,
            (x_tenant_id, x_inbox_id, x_tenant_id, data.agent_type, tokens_used, tokens_used),
            x_tenant_id
        )
        
        logger.info(f"✓ Mensagem processada: {agent_message_id}")
        
        return MessageResponse(
            conversation_id=conversation_id,
            message_id=agent_message_id,
            agent_response=response_text,
            tokens_used=tokens_used,
            created_at=created_at
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao processar chat: {e}")
        raise HTTPException(status_code=500, detail=f"Error processing chat: {str(e)}")
    finally:
        if conn:
            release_db_connection(conn)


@app.get("/api/conversations/{conversation_id}/messages")
async def get_conversation_messages(
    conversation_id: str,
    x_tenant_id: str = Header(..., alias="X-Tenant-ID")
) -> List[ConversationMessage]:
    """Busca todas as mensagens de uma conversa"""
    conn = None
    
    try:
        conn = get_db_connection()
        
        query = """
            SELECT 
                id::text as message_id,
                role,
                COALESCE(user_message, assistant_message) as content,
                created_at,
                metadata,
                input_tokens,
                output_tokens,
                total_tokens
            FROM messages
            WHERE conversation_id = %s
            ORDER BY message_index ASC
        """
        
        result = query_with_tenant(
            conn, query,
            (conversation_id,),
            x_tenant_id
        )
        
        messages = [
            ConversationMessage(
                message_id=msg['message_id'],
                role=msg['role'],
                content=msg['content'],
                created_at=msg['created_at'].isoformat(),
                metadata=msg['metadata']
            )
            for msg in result
        ]
        
        return messages
        
    except Exception as e:
        logger.error(f"Erro ao buscar mensagens: {e}")
        raise HTTPException(status_code=500, detail=f"Error fetching messages: {str(e)}")
    finally:
        if conn:
            release_db_connection(conn)


@app.get("/api/conversations")
async def list_conversations(
    x_tenant_id: str = Header(..., alias="X-Tenant-ID"),
    x_inbox_id: str = Header(..., alias="X-Inbox-ID"),
    limit: int = 50
):
    """Lista conversas do inbox"""
    conn = None
    
    try:
        conn = get_db_connection()
        
        query = """
            SELECT 
                c.id::text as conversation_id,
                c.contact_name,
                c.contact_phone,
                c.status,
                c.created_at,
                c.updated_at,
                COUNT(m.id) as message_count,
                MAX(m.created_at) as last_message_at
            FROM conversations c
            LEFT JOIN messages m ON m.conversation_id = c.id
            WHERE c.inbox_id = %s
            GROUP BY c.id
            ORDER BY last_message_at DESC NULLS LAST
            LIMIT %s
        """
        
        result = query_with_tenant(
            conn, query,
            (x_inbox_id, limit),
            x_tenant_id
        )
        
        conversations = [
            {
                "conversation_id": conv['conversation_id'],
                "contact_name": conv['contact_name'],
                "contact_phone": conv['contact_phone'],
                "status": conv['status'],
                "message_count": conv['message_count'],
                "created_at": conv['created_at'].isoformat(),
                "updated_at": conv['updated_at'].isoformat() if conv['updated_at'] else None,
                "last_message_at": conv['last_message_at'].isoformat() if conv['last_message_at'] else None
            }
            for conv in result
        ]
        
        return conversations
        
    except Exception as e:
        logger.error(f"Erro ao listar conversas: {e}")
        raise HTTPException(status_code=500, detail=f"Error listing conversations: {str(e)}")
    finally:
        if conn:
            release_db_connection(conn)


@app.get("/api/dashboard/consumption", response_model=DashboardData)
async def get_consumption_dashboard(
    x_tenant_id: str = Header(..., alias="X-Tenant-ID"),
    x_inbox_id: str = Header(..., alias="X-Inbox-ID"),
    days: int = 30
):
    """Retorna dados de consumo para dashboard"""
    conn = None
    
    try:
        conn = get_db_connection()
        
        # Total de conversas
        query = "SELECT COUNT(*) as total FROM conversations WHERE inbox_id = %s"
        result = query_with_tenant(conn, query, (x_inbox_id,), x_tenant_id)
        total_conversations = result[0]['total']
        
        # Total de mensagens
        query = """
            SELECT COUNT(*) as total 
            FROM messages m
            JOIN conversations c ON c.id = m.conversation_id
            WHERE c.inbox_id = %s
        """
        result = query_with_tenant(conn, query, (x_inbox_id,), x_tenant_id)
        total_messages = result[0]['total']
        
        # Total de tokens
        query = """
            SELECT COALESCE(SUM(total_tokens), 0) as total
            FROM consumption_inbox_daily
            WHERE inbox_id = %s
        """
        result = query_with_tenant(conn, query, (x_inbox_id,), x_tenant_id)
        total_tokens = result[0]['total']
        
        # Conversas por agente
        query = """
            SELECT 
                a.agent_type,
                COUNT(DISTINCT c.id) as count
            FROM conversations c
            JOIN inbox_agents ia ON ia.inbox_id = c.inbox_id
            JOIN agents a ON a.id = ia.agent_id
            WHERE c.inbox_id = %s
            GROUP BY a.agent_type
        """
        result = query_with_tenant(conn, query, (x_inbox_id,), x_tenant_id)
        conversations_by_agent = {row['agent_type']: row['count'] for row in result}
        
        # Consumo diário
        query = """
            SELECT 
                date_window::text as date,
                SUM(total_tokens) as tokens,
                SUM(total_messages) as messages,
                SUM(total_conversations) as conversations
            FROM consumption_inbox_daily
            WHERE inbox_id = %s
              AND date_window >= CURRENT_DATE - INTERVAL '%s days'
            GROUP BY date_window
            ORDER BY date_window DESC
        """
        result = query_with_tenant(conn, query, (x_inbox_id, days), x_tenant_id)
        daily_consumption = [
            {
                "date": row['date'],
                "tokens": row['tokens'],
                "messages": row['messages'],
                "conversations": row['conversations']
            }
            for row in result
        ]
        
        return DashboardData(
            total_conversations=total_conversations,
            total_messages=total_messages,
            total_tokens=total_tokens,
            conversations_by_agent=conversations_by_agent,
            daily_consumption=daily_consumption
        )
        
    except Exception as e:
        logger.error(f"Erro ao buscar dashboard: {e}")
        raise HTTPException(status_code=500, detail=f"Error fetching dashboard: {str(e)}")
    finally:
        if conn:
            release_db_connection(conn)


# ============================================================================
# Main
# ============================================================================

if __name__ == "__main__":
    import uvicorn
    
    logger.info(f"Iniciando servidor na porta {PORT}")
    uvicorn.run(
        "server:app",
        host="0.0.0.0",
        port=PORT,
        reload=False,  # Desabilitado para evitar loops
        log_level="info"
    )
