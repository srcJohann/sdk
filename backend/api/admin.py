"""
DOM360 Admin API - Master Management Endpoints
"""
import json
import logging
import sys
import os
from typing import Optional, List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Request
import psycopg2
from pydantic import BaseModel, Field
from psycopg2.extras import RealDictCursor

try:
    from ..auth import (
        AuthContext,
        UserRole,
        get_current_user,
        require_master,
        set_rls_context,
        log_audit
    )
except ImportError:
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    from auth import (
        AuthContext,
        UserRole,
        get_current_user,
        require_master,
        set_rls_context,
        log_audit
    )

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin", tags=["Admin - Master Only"])


# ============================================================================
# Models
# ============================================================================

class TenantCreate(BaseModel):
    """Create tenant request"""
    name: str = Field(..., min_length=1, max_length=255)
    # Chatwoot account id is required and will be used as the tenant ID
    chatwoot_account_id: int = Field(..., description="Chatwoot account id; used as tenant ID")


class TenantUpdate(BaseModel):
    """Update tenant request"""
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    is_active: Optional[bool] = None
    chatwoot_account_id: Optional[int] = None


class TenantResponse(BaseModel):
    """Tenant response"""
    id: int  # Changed from str to int (INTEGER in database)
    name: str
    is_active: bool
    chatwoot_account_id: Optional[int] = None
    created_at: str
    updated_at: str
    
    # Metrics (computed)
    inbox_count: int = 0
    user_count: int = 0
    conversation_count: int = 0


class InboxAssociation(BaseModel):
    """Associate inbox to tenant"""
    inbox_id: int = Field(..., description="Inbox ID (integer, Chatwoot inbox id)")


class InboxBulkAssociation(BaseModel):
    """Associate multiple inboxes to tenant"""
    inbox_ids: List[int] = Field(..., description="List of Inbox IDs (integers)")


class InboxCreate(BaseModel):
    """Create inbox request"""
    tenant_id: int = Field(..., description="Tenant ID (INTEGER)")
    name: str = Field(..., min_length=1, max_length=255)
    external_id: Optional[str] = Field(None, description="Chatwoot inbox ID (int as string)")
    agent_type: Optional[str] = Field('SDR', pattern=r'^(SDR|COPILOT)$')
    is_active: bool = True


class InboxUpdate(BaseModel):
    """Update inbox request"""
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    external_id: Optional[str] = None  # Maps to chatwoot_inbox_id
    agent_type: Optional[str] = Field(None, pattern=r'^(SDR|COPILOT)$')
    is_active: Optional[bool] = None


class InboxResponse(BaseModel):
    """Inbox response"""
    id: int
    tenant_id: int  # Changed from str to int
    name: str
    external_id: Optional[str] = None  # Maps to chatwoot_inbox_id
    agent_type: str = 'SDR'
    inbox_type: Optional[str] = None  # Changed from channel_type
    is_active: bool
    created_at: str
    updated_at: str
    tenant_name: Optional[str] = None
    conversation_count: int = 0


class MasterSettingsResponse(BaseModel):
    """Master settings response"""
    id: int
    sdr_agent_endpoint: str
    sdr_agent_timeout_ms: int
    server_config: dict
    health_check_enabled: Optional[bool] = True
    health_check_interval_seconds: Optional[int] = 300
    last_health_check_at: Optional[str] = None
    health_status: Optional[str] = 'unknown'
    updated_at: str


class MasterSettingsUpdate(BaseModel):
    """Update master settings"""
    sdr_agent_endpoint: Optional[str] = Field(None, pattern=r'^https?://')
    sdr_agent_api_key: Optional[str] = None
    sdr_agent_timeout_ms: Optional[int] = Field(None, gt=0)
    server_config: Optional[dict] = None
    health_check_enabled: Optional[bool] = None
    health_check_interval_seconds: Optional[int] = Field(None, gt=0)


class GlobalMetricsResponse(BaseModel):
    """Global metrics response"""
    total_tenants: int
    active_tenants: int
    total_inboxes: int
    total_conversations: int
    total_messages: int
    total_tokens: int
    avg_latency_ms: int
    period_start: Optional[str] = None
    period_end: Optional[str] = None


# ============================================================================
# Helper Functions
# ============================================================================

def get_db_from_request(request: Request):
    """Get database connection from request state"""
    if not hasattr(request.state, 'db'):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database connection not available"
        )
    return request.state.db


# ============================================================================
# Tenant Management
# ============================================================================

@router.post("/tenants", response_model=TenantResponse, status_code=status.HTTP_201_CREATED)
async def create_tenant(
    data: TenantCreate,
    request: Request,
    user: AuthContext = Depends(require_master)
):
    """
    **[MASTER ONLY]** Create new tenant
    
    Creates a new tenant organization in the system.
    """
    conn = get_db_from_request(request)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        # Check for existing tenant by id/chatwoot_account_id or name to provide clearer errors
        cursor.execute("SELECT id, name, chatwoot_account_id FROM tenants WHERE id = %s OR chatwoot_account_id = %s OR LOWER(name) = LOWER(%s)", (data.chatwoot_account_id, data.chatwoot_account_id, data.name))
        existing = cursor.fetchone()
        if existing:
            # ID / chatwoot_account_id conflict
            if existing.get('id') == data.chatwoot_account_id or existing.get('chatwoot_account_id') == data.chatwoot_account_id:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Tenant with chatwoot_account_id '{data.chatwoot_account_id}' already exists (id={existing.get('id')})"
                )
            # Name conflict
            if existing.get('name') and existing.get('name').lower() == data.name.lower():
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Tenant with name '{data.name}' already exists"
                )

        # The tenants table in the migrated DB uses integer id (chatwoot_account_id) and does
        # not provide an automatic sequence. We must explicitly insert id = chatwoot_account_id.
        query = """
            INSERT INTO tenants (id, name, chatwoot_account_id, is_active)
            VALUES (%s, %s, %s, TRUE)
            RETURNING id, name, is_active, chatwoot_account_id, created_at, updated_at
        """

        cursor.execute(query, (
            data.chatwoot_account_id,
            data.name,
            data.chatwoot_account_id
        ))
        
        tenant = cursor.fetchone()
        conn.commit()
        
        # Audit log
        await log_audit(
            user=user,
            action="CREATE_TENANT",
            resource_type="tenant",
            resource_id=str(tenant['id']),
            new_values=dict(tenant),
            ip_address=request.client.host if request.client else None,
            conn=conn
        )
        
        logger.info(f"Tenant created: {tenant['name']} (ID: {tenant['id']}) by {user.username}")
        
        result = dict(tenant)
        # Convert datetime to ISO strings
        if result.get('created_at'):
            result['created_at'] = result['created_at'].isoformat()
        if result.get('updated_at'):
            result['updated_at'] = result['updated_at'].isoformat()
        result['inbox_count'] = 0
        result['user_count'] = 0
        result['conversation_count'] = 0
        
        return result
        
    except psycopg2.IntegrityError as e:
        # Handle DB integrity errors (duplicate keys) with more specific messages
        conn.rollback()
        logger.error(f"Error creating tenant: {e}")

        msg = str(e).lower()
        constraint = None
        try:
            constraint = e.diag.constraint_name if hasattr(e, 'diag') else None
        except Exception:
            constraint = None

        # Primary key / id conflict
        if constraint and 'tenants_pkey' in constraint.lower():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Tenant with chatwoot_account_id '{data.chatwoot_account_id}' already exists"
            )

        # Generic textual checks
        if 'key (id)' in msg or 'tenants_pkey' in msg:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Tenant with chatwoot_account_id '{data.chatwoot_account_id}' already exists"
            )

        if 'chatwoot_account_id' in msg or 'chatwoot_account' in msg:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Tenant with chatwoot_account_id '{data.chatwoot_account_id}' already exists"
            )

        if 'name' in msg or ('tenant' in msg and 'name' in msg):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Tenant with name '{data.name}' already exists"
            )

        # Fallback for other integrity errors
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Tenant creation conflict: {str(e)}"
        )
    except Exception as e:
        conn.rollback()
        logger.error(f"Error creating tenant: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create tenant: {str(e)}"
        )
    finally:
        cursor.close()


@router.get("/tenants", response_model=List[TenantResponse])
async def list_tenants(
    request: Request,
    user: AuthContext = Depends(require_master),
    is_active: Optional[bool] = None,
    limit: int = 100,
    offset: int = 0
):
    """
    **[MASTER ONLY]** List all tenants with metrics
    """
    conn = get_db_from_request(request)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        query = """
            SELECT 
                t.id, t.name, t.is_active,
                t.chatwoot_account_id,
                t.created_at, t.updated_at,
                COUNT(DISTINCT ti.inbox_id) as inbox_count,
                COUNT(DISTINCT u.id) as user_count,
                COUNT(DISTINCT c.id) as conversation_count
            FROM tenants t
            LEFT JOIN tenant_inboxes ti ON ti.tenant_id = t.id AND ti.is_active = TRUE
            LEFT JOIN users u ON u.tenant_id = t.id AND u.is_active = TRUE
            LEFT JOIN conversations c ON c.tenant_id = t.id
            WHERE 1=1
        """
        params = []
        
        if is_active is not None:
            query += " AND t.is_active = %s"
            params.append(is_active)
        
        query += """
            GROUP BY t.id, t.name, t.is_active, t.chatwoot_account_id, 
                     t.created_at, t.updated_at
            ORDER BY t.created_at DESC
            LIMIT %s OFFSET %s
        """
        params.extend([limit, offset])
        
        cursor.execute(query, tuple(params))
        tenants = cursor.fetchall()
        
        # Convert datetime objects to ISO strings
        result = []
        for t in tenants:
            tenant_dict = dict(t)
            if tenant_dict.get('created_at'):
                tenant_dict['created_at'] = tenant_dict['created_at'].isoformat()
            if tenant_dict.get('updated_at'):
                tenant_dict['updated_at'] = tenant_dict['updated_at'].isoformat()
            result.append(tenant_dict)
        
        return result
        
    finally:
        cursor.close()


@router.get("/tenants/{tenant_id}", response_model=TenantResponse)
async def get_tenant(
    tenant_id: int,  # Changed from str to int
    request: Request,
    user: AuthContext = Depends(require_master)
):
    """
    **[MASTER ONLY]** Get tenant details
    """
    conn = get_db_from_request(request)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        query = """
            SELECT 
                t.*,
                COUNT(DISTINCT ti.inbox_id) as inbox_count,
                COUNT(DISTINCT u.id) as user_count,
                COUNT(DISTINCT c.id) as conversation_count
            FROM tenants t
            LEFT JOIN tenant_inboxes ti ON ti.tenant_id = t.id AND ti.is_active = TRUE
            LEFT JOIN users u ON u.tenant_id = t.id AND u.is_active = TRUE
            LEFT JOIN conversations c ON c.tenant_id = t.id
            WHERE t.id = %s
            GROUP BY t.id
        """
        
        cursor.execute(query, (tenant_id,))
        tenant = cursor.fetchone()
        
        if not tenant:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Tenant {tenant_id} not found"
            )
        
        # Convert datetime objects to ISO strings
        tenant_dict = dict(tenant)
        if tenant_dict.get('created_at'):
            tenant_dict['created_at'] = tenant_dict['created_at'].isoformat()
        if tenant_dict.get('updated_at'):
            tenant_dict['updated_at'] = tenant_dict['updated_at'].isoformat()
        
        return tenant_dict
        
    finally:
        cursor.close()


@router.put("/tenants/{tenant_id}", response_model=TenantResponse)
async def update_tenant(
    tenant_id: int,  # Changed from str to int
    data: TenantUpdate,
    request: Request,
    user: AuthContext = Depends(require_master)
):
    """
    **[MASTER ONLY]** Update tenant
    """
    conn = get_db_from_request(request)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        # Get existing tenant
        cursor.execute("SELECT * FROM tenants WHERE id = %s", (tenant_id,))
        existing = cursor.fetchone()
        
        if not existing:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Tenant {tenant_id} not found"
            )
        
        # Build update
        updates = []
        params = []
        
        if data.name is not None:
            updates.append("name = %s")
            params.append(data.name)
        
        if data.is_active is not None:
            updates.append("is_active = %s")
            params.append(data.is_active)
        
        if data.chatwoot_account_id is not None:
            updates.append("chatwoot_account_id = %s")
            params.append(data.chatwoot_account_id)
        
        if not updates:
            # No updates, return existing
            result = dict(existing)
            # Convert datetime to ISO strings
            if result.get('created_at'):
                result['created_at'] = result['created_at'].isoformat()
            if result.get('updated_at'):
                result['updated_at'] = result['updated_at'].isoformat()
            result['inbox_count'] = 0
            result['user_count'] = 0
            result['conversation_count'] = 0
            return result
        
        updates.append("updated_at = NOW()")
        params.append(tenant_id)
        
        query = f"""
            UPDATE tenants 
            SET {', '.join(updates)}
            WHERE id = %s
            RETURNING *
        """
        
        cursor.execute(query, tuple(params))
        updated = cursor.fetchone()
        conn.commit()
        
        # Audit log
        await log_audit(
            user=user,
            action="UPDATE_TENANT",
            resource_type="tenant",
            resource_id=str(tenant_id),  # Convert to string for audit log
            old_values=dict(existing),
            new_values=dict(updated),
            ip_address=request.client.host if request.client else None,
            conn=conn
        )
        
        result = dict(updated)
        # Convert datetime to ISO strings
        if result.get('created_at'):
            result['created_at'] = result['created_at'].isoformat()
        if result.get('updated_at'):
            result['updated_at'] = result['updated_at'].isoformat()
        result['inbox_count'] = 0
        result['user_count'] = 0
        result['conversation_count'] = 0
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        logger.error(f"Error updating tenant: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update tenant: {str(e)}"
        )
    finally:
        cursor.close()


@router.delete("/tenants/{tenant_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_tenant(
    tenant_id: int,  # Changed from str to int
    request: Request,
    user: AuthContext = Depends(require_master)
):
    """
    **[MASTER ONLY]** Delete tenant
    
    WARNING: This will cascade delete all related data (users, conversations, etc.)
    """
    conn = get_db_from_request(request)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        # Get existing tenant
        cursor.execute("SELECT * FROM tenants WHERE id = %s", (tenant_id,))
        existing = cursor.fetchone()
        
        if not existing:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Tenant {tenant_id} not found"
            )
        
        # Delete tenant (CASCADE will handle related records)
        cursor.execute("DELETE FROM tenants WHERE id = %s", (tenant_id,))
        conn.commit()
        
        # Audit log
        await log_audit(
            user=user,
            action="DELETE_TENANT",
            resource_type="tenant",
            resource_id=str(tenant_id),  # Convert to string for audit log
            old_values=dict(existing),
            ip_address=request.client.host if request.client else None,
            conn=conn
        )
        
        return None
        
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        logger.error(f"Error deleting tenant: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete tenant: {str(e)}"
        )
    finally:
        cursor.close()


# ============================================================================
# Inbox Management
# ============================================================================

@router.get("/inboxes", response_model=List[dict])
async def list_all_inboxes(
    request: Request,
    user: AuthContext = Depends(require_master),
    is_active: Optional[bool] = None,
    limit: int = 200,
    offset: int = 0
):
    """
    **[MASTER ONLY]** List all inboxes in the system
    
    Used for associating inboxes to tenants.
    """
    conn = get_db_from_request(request)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        query = """
            SELECT 
                i.id, i.tenant_id, i.name, i.inbox_type, i.chatwoot_inbox_id as external_id,
                i.is_active, i.created_at, i.updated_at,
                i.config->>'agent_type' as agent_type,
                t.name as tenant_name,
                COUNT(DISTINCT c.id) as conversation_count
            FROM inboxes i
            LEFT JOIN tenants t ON t.id = i.tenant_id
            LEFT JOIN conversations c ON c.inbox_id = i.id
            WHERE 1=1
        """
        params = []
        
        if is_active is not None:
            query += " AND i.is_active = %s"
            params.append(is_active)
        
        query += """
            GROUP BY i.id, i.tenant_id, i.name, i.inbox_type, i.chatwoot_inbox_id,
                     i.is_active, i.created_at, i.updated_at, i.config, t.name
            ORDER BY i.created_at DESC
            LIMIT %s OFFSET %s
        """
        params.extend([limit, offset])
        
        cursor.execute(query, tuple(params))
        inboxes = cursor.fetchall()
        
        # Convert datetime to ISO string and set default agent_type
        result = []
        for inbox in inboxes:
            inbox_dict = dict(inbox)
            if inbox_dict.get('created_at'):
                inbox_dict['created_at'] = inbox_dict['created_at'].isoformat()
            if inbox_dict.get('updated_at'):
                inbox_dict['updated_at'] = inbox_dict['updated_at'].isoformat()
            if not inbox_dict.get('agent_type'):
                inbox_dict['agent_type'] = 'SDR'
            result.append(inbox_dict)
        
        return result
        
    finally:
        cursor.close()


@router.post("/inboxes", response_model=InboxResponse, status_code=status.HTTP_201_CREATED)
async def create_inbox(
    data: InboxCreate,
    request: Request,
    user: AuthContext = Depends(require_master)
):
    """
    **[MASTER ONLY]** Create new inbox for a tenant
    """
    conn = get_db_from_request(request)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        # Verify tenant exists
        cursor.execute("SELECT id, name FROM tenants WHERE id = %s", (data.tenant_id,))
        tenant = cursor.fetchone()
        if not tenant:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Tenant {data.tenant_id} not found"
            )
        
        # Build config with agent_type
        config = {"agent_type": data.agent_type or "SDR"}
        
        # Insert inbox (note: id and chatwoot_inbox_id must be provided)
        # The database schema requires `id` (integer) to be provided (no default sequence),
        # so we must set id = external_id (chatwoot inbox id).
        query = """
            INSERT INTO inboxes (id, tenant_id, name, chatwoot_inbox_id, config, is_active)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id, tenant_id, name, chatwoot_inbox_id, inbox_type, is_active, created_at, updated_at, config
        """

        # Use external_id as both id and chatwoot_inbox_id if provided
        inbox_id = int(data.external_id) if data.external_id else None
        if not inbox_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="external_id (inbox ID) is required"
            )

        cursor.execute(query, (
            inbox_id,
            data.tenant_id,
            data.name,
            inbox_id,
            json.dumps(config),
            data.is_active
        ))
        
        new_inbox = cursor.fetchone()
        conn.commit()
        
        # Audit log
        await log_audit(
            user=user,
            action="CREATE_INBOX",
            resource_type="inbox",
            resource_id=new_inbox['id'],
            new_values=dict(new_inbox),
            ip_address=request.client.host if request.client else None,
            conn=conn
        )
        
        # Format response
        result = dict(new_inbox)
        result['created_at'] = result['created_at'].isoformat()
        result['updated_at'] = result['updated_at'].isoformat()
        result['agent_type'] = result['config'].get('agent_type', 'SDR')
        result['external_id'] = str(result['chatwoot_inbox_id'])  # Map chatwoot_inbox_id to external_id
        result['tenant_name'] = tenant['name']
        result['conversation_count'] = 0
        
        return result
        
    except HTTPException:
        raise
    except psycopg2.IntegrityError as e:
        # Handle DB integrity errors like duplicate primary key (id)
        conn.rollback()
        logger.error(f"Integrity error creating inbox: {e}")

        msg = str(e).lower()
        constraint = None
        try:
            constraint = e.diag.constraint_name if hasattr(e, 'diag') else None
        except Exception:
            constraint = None

        if constraint and 'inboxes_pkey' in constraint.lower():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Inbox with id '{inbox_id}' already exists"
            )

        if 'key (id)' in msg or 'inboxes_pkey' in msg:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Inbox with id '{inbox_id}' already exists"
            )

        # Fallback for other integrity errors
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Inbox creation conflict: {str(e)}"
        )
    except Exception as e:
        conn.rollback()
        logger.error(f"Error creating inbox: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create inbox: {str(e)}"
        )
    finally:
        cursor.close()


@router.put("/inboxes/{inbox_id}", response_model=InboxResponse)
async def update_inbox(
    inbox_id: int,
    data: InboxUpdate,
    request: Request,
    user: AuthContext = Depends(require_master)
):
    """
    **[MASTER ONLY]** Update inbox
    """
    conn = get_db_from_request(request)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        # Get existing inbox
        cursor.execute("SELECT * FROM inboxes WHERE id = %s", (inbox_id,))
        existing = cursor.fetchone()
        
        if not existing:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Inbox {inbox_id} not found"
            )
        
        # Build update
        updates = []
        params = []
        
        if data.name is not None:
            updates.append("name = %s")
            params.append(data.name)
        
        if data.external_id is not None:
            updates.append("chatwoot_inbox_id = %s")
            params.append(int(data.external_id))
        
        if data.is_active is not None:
            updates.append("is_active = %s")
            params.append(data.is_active)
        
        # Handle agent_type in config
        if data.agent_type is not None:
            current_config = existing['config'] or {}
            current_config['agent_type'] = data.agent_type
            updates.append("config = %s")
            params.append(json.dumps(current_config))
        
        if not updates:
            # No updates, return existing
            result = dict(existing)
            result['created_at'] = result['created_at'].isoformat()
            result['updated_at'] = result['updated_at'].isoformat()
            result['agent_type'] = result['config'].get('agent_type', 'SDR') if result['config'] else 'SDR'
            result['external_id'] = str(result['chatwoot_inbox_id'])  # Map chatwoot_inbox_id to external_id
            result['conversation_count'] = 0
            return result
        
        updates.append("updated_at = NOW()")
        params.append(inbox_id)
        
        query = f"""
            UPDATE inboxes 
            SET {', '.join(updates)}
            WHERE id = %s
            RETURNING *
        """
        
        cursor.execute(query, tuple(params))
        updated = cursor.fetchone()
        conn.commit()
        
        # Audit log
        await log_audit(
            user=user,
            action="UPDATE_INBOX",
            resource_type="inbox",
            resource_id=inbox_id,
            old_values=dict(existing),
            new_values=dict(updated),
            ip_address=request.client.host if request.client else None,
            conn=conn
        )
        
        # Get tenant name
        cursor.execute("SELECT name FROM tenants WHERE id = %s", (updated['tenant_id'],))
        tenant = cursor.fetchone()
        
        result = dict(updated)
        result['created_at'] = result['created_at'].isoformat()
        result['updated_at'] = result['updated_at'].isoformat()
        result['agent_type'] = result['config'].get('agent_type', 'SDR') if result['config'] else 'SDR'
        result['external_id'] = str(result['chatwoot_inbox_id'])  # Map chatwoot_inbox_id to external_id
        result['tenant_name'] = tenant['name'] if tenant else None
        result['conversation_count'] = 0
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        logger.error(f"Error updating inbox: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update inbox: {str(e)}"
        )
    finally:
        cursor.close()


@router.delete("/inboxes/{inbox_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_inbox(
    inbox_id: int,
    request: Request,
    user: AuthContext = Depends(require_master)
):
    """
    **[MASTER ONLY]** Delete inbox
    
    WARNING: This will cascade delete all related conversations and messages
    """
    conn = get_db_from_request(request)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        # Get existing inbox
        cursor.execute("SELECT * FROM inboxes WHERE id = %s", (inbox_id,))
        existing = cursor.fetchone()
        
        if not existing:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Inbox {inbox_id} not found"
            )
        
        # Delete inbox (CASCADE will handle related records)
        cursor.execute("DELETE FROM inboxes WHERE id = %s", (inbox_id,))
        conn.commit()
        
        # Audit log
        await log_audit(
            user=user,
            action="DELETE_INBOX",
            resource_type="inbox",
            resource_id=inbox_id,
            old_values=dict(existing),
            ip_address=request.client.host if request.client else None,
            conn=conn
        )
        
        return None
        
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        logger.error(f"Error deleting inbox: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete inbox: {str(e)}"
        )
    finally:
        cursor.close()


@router.get("/tenants/{tenant_id}/inboxes", response_model=List[dict])
async def get_tenant_inboxes(
    tenant_id: int,  # Changed from str to int
    request: Request,
    user: AuthContext = Depends(require_master)
):
    """
    **[MASTER ONLY]** Get inboxes associated with a tenant
    """
    conn = get_db_from_request(request)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        query = """
            SELECT 
                i.id, i.name, i.inbox_type, i.is_active,
                ti.created_at as associated_at,
                COUNT(DISTINCT c.id) as conversation_count
            FROM tenant_inboxes ti
            INNER JOIN inboxes i ON i.id = ti.inbox_id
            LEFT JOIN conversations c ON c.inbox_id = i.id AND c.tenant_id = ti.tenant_id
            WHERE ti.tenant_id = %s AND ti.is_active = TRUE
            GROUP BY i.id, i.name, i.inbox_type, i.is_active, ti.created_at
            ORDER BY ti.created_at DESC
        """
        
        cursor.execute(query, (tenant_id,))
        inboxes = cursor.fetchall()
        
        return [dict(inbox) for inbox in inboxes]
        
    finally:
        cursor.close()


# ============================================================================
# Inbox Association
# ============================================================================

@router.post("/tenants/{tenant_id}/inboxes", status_code=status.HTTP_201_CREATED)
async def associate_inbox_to_tenant(
    tenant_id: int,  # Changed from str to int
    data: InboxAssociation,
    request: Request,
    user: AuthContext = Depends(require_master)
):
    """
    **[MASTER ONLY]** Associate inbox to tenant
    
    Allows a tenant to access an inbox.
    """
    conn = get_db_from_request(request)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        # Verify tenant exists
        cursor.execute("SELECT id FROM tenants WHERE id = %s", (tenant_id,))
        if not cursor.fetchone():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Tenant {tenant_id} not found"
            )
        
        # Verify inbox exists
        cursor.execute("SELECT id FROM inboxes WHERE id = %s", (data.inbox_id,))
        if not cursor.fetchone():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Inbox {data.inbox_id} not found"
            )
        
        # Associate
        query = """
            INSERT INTO tenant_inboxes (tenant_id, inbox_id, is_active)
            VALUES (%s, %s, TRUE)
            ON CONFLICT (tenant_id, inbox_id) DO UPDATE
            SET is_active = TRUE, updated_at = NOW()
            RETURNING *
        """
        
        cursor.execute(query, (tenant_id, data.inbox_id))
        association = cursor.fetchone()
        conn.commit()
        
        # Audit log
        await log_audit(
            user=user,
            action="ASSOCIATE_INBOX",
            resource_type="tenant_inbox",
            resource_id=f"{tenant_id}:{data.inbox_id}",
            new_values=dict(association),
            ip_address=request.client.host if request.client else None,
            conn=conn
        )
        
        return {"message": "Inbox associated successfully", "association": dict(association)}
        
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        logger.error(f"Error associating inbox: {e}")
        
        if "duplicate key" in str(e).lower():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Inbox already associated with tenant"
            )
        
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to associate inbox: {str(e)}"
        )
    finally:
        cursor.close()


@router.post("/tenants/{tenant_id}/inboxes/bulk", status_code=status.HTTP_201_CREATED)
async def associate_multiple_inboxes_to_tenant(
    tenant_id: int,  # Changed from str to int
    data: InboxBulkAssociation,
    request: Request,
    user: AuthContext = Depends(require_master)
):
    """
    **[MASTER ONLY]** Associate multiple inboxes to tenant
    
    Replaces all current associations with the provided inbox list.
    """
    conn = get_db_from_request(request)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        # Verify tenant exists
        cursor.execute("SELECT id FROM tenants WHERE id = %s", (tenant_id,))
        if not cursor.fetchone():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Tenant {tenant_id} not found"
            )
        
        # Deactivate all current associations
        cursor.execute("""
            UPDATE tenant_inboxes
            SET is_active = FALSE, updated_at = NOW()
            WHERE tenant_id = %s
        """, (tenant_id,))
        
        # Associate new inboxes
        associated = []
        for inbox_id in data.inbox_ids:
            # Verify inbox exists
            cursor.execute("SELECT id FROM inboxes WHERE id = %s", (inbox_id,))
            if not cursor.fetchone():
                conn.rollback()
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Inbox {inbox_id} not found"
                )
            
            # Associate
            cursor.execute("""
                INSERT INTO tenant_inboxes (tenant_id, inbox_id, is_active)
                VALUES (%s, %s, TRUE)
                ON CONFLICT (tenant_id, inbox_id) DO UPDATE
                SET is_active = TRUE, updated_at = NOW()
                RETURNING *
            """, (tenant_id, inbox_id))
            
            associated.append(dict(cursor.fetchone()))
        
        conn.commit()
        
        # Audit log
        await log_audit(
            user=user,
            action="BULK_ASSOCIATE_INBOXES",
            resource_type="tenant_inbox",
            resource_id=str(tenant_id),  # Convert to string for audit log
            new_values={"inbox_ids": data.inbox_ids},
            ip_address=request.client.host if request.client else None,
            conn=conn
        )
        
        return {
            "message": f"Successfully associated {len(associated)} inboxes",
            "associations": associated
        }
        
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        logger.error(f"Error bulk associating inboxes: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to associate inboxes: {str(e)}"
        )
    finally:
        cursor.close()


@router.delete("/tenants/{tenant_id}/inboxes/{inbox_id}", status_code=status.HTTP_204_NO_CONTENT)
async def dissociate_inbox_from_tenant(
    tenant_id: int,  # Changed from str to int
    inbox_id: int,
    request: Request,
    user: AuthContext = Depends(require_master)
):
    """
    **[MASTER ONLY]** Remove inbox association from tenant
    """
    conn = get_db_from_request(request)
    cursor = conn.cursor()
    
    try:
        query = """
            UPDATE tenant_inboxes
            SET is_active = FALSE, updated_at = NOW()
            WHERE tenant_id = %s AND inbox_id = %s
        """
        
        cursor.execute(query, (tenant_id, inbox_id))
        conn.commit()
        
        # Audit log
        await log_audit(
            user=user,
            action="DISSOCIATE_INBOX",
            resource_type="tenant_inbox",
            resource_id=f"{tenant_id}:{inbox_id}",
            ip_address=request.client.host if request.client else None,
            conn=conn
        )
        
        return None
        
    except Exception as e:
        conn.rollback()
        logger.error(f"Error dissociating inbox: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to dissociate inbox: {str(e)}"
        )
    finally:
        cursor.close()


# ============================================================================
# Global Metrics
# ============================================================================

@router.get("/metrics", response_model=GlobalMetricsResponse)
async def get_global_metrics(
    request: Request,
    user: AuthContext = Depends(require_master),
    from_date: Optional[str] = None,
    to_date: Optional[str] = None
):
    """
    **[MASTER ONLY]** Get global system metrics
    
    Query parameters:
    - from_date: YYYY-MM-DD
    - to_date: YYYY-MM-DD
    """
    conn = get_db_from_request(request)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        query = "SELECT * FROM get_global_metrics(%s, %s)"
        cursor.execute(query, (from_date, to_date))
        metrics = cursor.fetchone()
        
        return dict(metrics)
        
    finally:
        cursor.close()


# ============================================================================
# Master Settings
# ============================================================================

@router.get("/master-settings", response_model=MasterSettingsResponse)
async def get_master_settings(
    request: Request,
    user: AuthContext = Depends(require_master)
):
    """
    **[MASTER ONLY]** Get master settings (SDR endpoint, server config)
    """
    conn = get_db_from_request(request)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        query = "SELECT * FROM master_settings LIMIT 1"
        cursor.execute(query)
        settings = cursor.fetchone()
        
        if not settings:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Master settings not initialized"
            )
        
        result = dict(settings)
        
        # Convert datetime fields to ISO format strings
        if result.get('created_at'):
            result['created_at'] = result['created_at'].isoformat()
        if result.get('updated_at'):
            result['updated_at'] = result['updated_at'].isoformat()
        if result.get('last_health_check_at'):
            result['last_health_check_at'] = result['last_health_check_at'].isoformat()
        
        # Set defaults for fields that might not exist
        if 'health_check_enabled' not in result:
            result['health_check_enabled'] = True
        if 'health_check_interval_seconds' not in result:
            result['health_check_interval_seconds'] = 300
        if 'health_status' not in result:
            result['health_status'] = 'unknown'
        
        return result
        
    finally:
        cursor.close()


@router.put("/master-settings", response_model=MasterSettingsResponse)
async def update_master_settings(
    data: MasterSettingsUpdate,
    request: Request,
    user: AuthContext = Depends(require_master)
):
    """
    **[MASTER ONLY]** Update master settings
    
    Updates SDR agent endpoint, timeout, and server configuration.
    """
    conn = get_db_from_request(request)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        # Get existing settings
        cursor.execute("SELECT * FROM master_settings LIMIT 1")
        existing = cursor.fetchone()
        
        if not existing:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Master settings not initialized"
            )
        
        # Build update
        updates = []
        params = []
        
        # Check which columns exist
        cursor.execute("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name = 'master_settings'
        """)
        existing_columns = {row['column_name'] for row in cursor.fetchall()}
        
        if data.sdr_agent_endpoint is not None and 'sdr_agent_endpoint' in existing_columns:
            updates.append("sdr_agent_endpoint = %s")
            params.append(data.sdr_agent_endpoint)
        
        if data.sdr_agent_api_key is not None and 'sdr_agent_api_key' in existing_columns:
            # TODO: Encrypt API key
            updates.append("sdr_agent_api_key = %s")
            params.append(data.sdr_agent_api_key)
        
        if data.sdr_agent_timeout_ms is not None and 'sdr_agent_timeout_ms' in existing_columns:
            updates.append("sdr_agent_timeout_ms = %s")
            params.append(data.sdr_agent_timeout_ms)
        
        if data.server_config is not None and 'server_config' in existing_columns:
            import json
            updates.append("server_config = %s::jsonb")
            params.append(json.dumps(data.server_config))
        
        # Only update health check fields if they exist in the table
        if data.health_check_enabled is not None and 'health_check_enabled' in existing_columns:
            updates.append("health_check_enabled = %s")
            params.append(data.health_check_enabled)
        
        if data.health_check_interval_seconds is not None and 'health_check_interval_seconds' in existing_columns:
            updates.append("health_check_interval_seconds = %s")
            params.append(data.health_check_interval_seconds)
        
        if not updates:
            result = dict(existing)
            # Convert datetime fields
            if result.get('created_at'):
                result['created_at'] = result['created_at'].isoformat()
            if result.get('updated_at'):
                result['updated_at'] = result['updated_at'].isoformat()
            if result.get('last_health_check_at'):
                result['last_health_check_at'] = result['last_health_check_at'].isoformat()
            # Set defaults
            if 'health_check_enabled' not in result:
                result['health_check_enabled'] = True
            if 'health_check_interval_seconds' not in result:
                result['health_check_interval_seconds'] = 300
            if 'health_status' not in result:
                result['health_status'] = 'unknown'
            return result
        
        updates.append("updated_at = NOW()")
        params.append(existing['id'])
        
        query = f"""
            UPDATE master_settings
            SET {', '.join(updates)}
            WHERE id = %s
            RETURNING *
        """
        
        cursor.execute(query, tuple(params))
        updated = cursor.fetchone()
        conn.commit()
        
        # Audit log
        await log_audit(
            user=user,
            action="UPDATE_MASTER_SETTINGS",
            resource_type="master_settings",
            resource_id=str(existing['id']),
            old_values=dict(existing),
            new_values=dict(updated),
            ip_address=request.client.host if request.client else None,
            conn=conn
        )
        
        logger.info(f"Master settings updated by {user.username}")
        
        result = dict(updated)
        
        # Convert datetime fields to ISO format strings
        if result.get('created_at'):
            result['created_at'] = result['created_at'].isoformat()
        if result.get('updated_at'):
            result['updated_at'] = result['updated_at'].isoformat()
        if result.get('last_health_check_at'):
            result['last_health_check_at'] = result['last_health_check_at'].isoformat()
        
        # Set defaults for fields that might not exist
        if 'health_check_enabled' not in result:
            result['health_check_enabled'] = True
        if 'health_check_interval_seconds' not in result:
            result['health_check_interval_seconds'] = 300
        if 'health_status' not in result:
            result['health_status'] = 'unknown'
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        logger.error(f"Error updating master settings: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update master settings: {str(e)}"
        )
    finally:
        cursor.close()


@router.post("/master-settings/health-check")
async def run_sdr_health_check(
    request: Request,
    user: AuthContext = Depends(require_master)
):
    """
    **[MASTER ONLY]** Run health check on SDR agent endpoint
    """
    import httpx
    from datetime import datetime
    
    conn = get_db_from_request(request)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        # Get settings
        cursor.execute("SELECT * FROM master_settings LIMIT 1")
        settings = cursor.fetchone()
        
        if not settings:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Master settings not initialized"
            )
        
        endpoint = settings['sdr_agent_endpoint']
        timeout_ms = settings['sdr_agent_timeout_ms']
        
        # Call health endpoint
        health_url = f"{endpoint.rstrip('/')}/health"
        
        start_time = datetime.utcnow()
        
        try:
            async with httpx.AsyncClient(timeout=timeout_ms / 1000.0) as client:
                response = await client.get(health_url)
                response.raise_for_status()
                
                latency_ms = int((datetime.utcnow() - start_time).total_seconds() * 1000)
                
                # Update health status (only if columns exist)
                try:
                    cursor.execute("""
                        UPDATE master_settings
                        SET health_status = 'healthy',
                            last_health_check_at = NOW(),
                            updated_at = NOW()
                        WHERE id = %s
                    """, (settings['id'],))
                    conn.commit()
                except Exception:
                    # Rollback the failed transaction
                    conn.rollback()
                    # Columns may not exist, just update timestamp
                    cursor.execute("""
                        UPDATE master_settings
                        SET updated_at = NOW()
                        WHERE id = %s
                    """, (settings['id'],))
                    conn.commit()
                
                return {
                    "status": "healthy",
                    "endpoint": health_url,
                    "latency_ms": latency_ms,
                    "checked_at": datetime.utcnow().isoformat()
                }
                
        except Exception as e:
            # Update unhealthy status (only if columns exist)
            try:
                cursor.execute("""
                    UPDATE master_settings
                    SET health_status = 'unhealthy',
                        last_health_check_at = NOW(),
                        updated_at = NOW()
                    WHERE id = %s
                """, (settings['id'],))
                conn.commit()
            except Exception:
                # Rollback the failed transaction
                conn.rollback()
                # Columns may not exist, just update timestamp
                cursor.execute("""
                    UPDATE master_settings
                    SET updated_at = NOW()
                    WHERE id = %s
                """, (settings['id'],))
                conn.commit()
            
            return {
                "status": "unhealthy",
                "endpoint": health_url,
                "error": str(e),
                "checked_at": datetime.utcnow().isoformat()
            }
            
    finally:
        cursor.close()
