"""
DOM360 RBAC Middleware & Dependencies
"""
import os
import logging
from typing import Optional, List
from datetime import datetime, timedelta

import jwt
import bcrypt
from fastapi import Depends, HTTPException, status, Header
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from .models import AuthContext, TokenPayload, UserRole

logger = logging.getLogger(__name__)

# JWT Configuration
JWT_SECRET = os.getenv("JWT_SECRET", "CHANGE_ME_IN_PRODUCTION_USE_STRONG_SECRET")
JWT_ALGORITHM = "HS256"
JWT_EXPIRATION_HOURS = int(os.getenv("JWT_EXPIRATION_HOURS", 24))

# Security scheme
security = HTTPBearer()


# ============================================================================
# Password Utilities
# ============================================================================

def hash_password(password: str) -> str:
    """Hash password using bcrypt"""
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify password against hash"""
    try:
        return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))
    except Exception as e:
        logger.error(f"Error verifying password: {e}")
        return False


# ============================================================================
# JWT Utilities
# ============================================================================

def create_access_token(
    user_id: str,
    tenant_id: int,
    role: str,
    username: str,
    email: str,
    expires_delta: Optional[timedelta] = None
) -> str:
    """Create JWT access token"""
    if expires_delta is None:
        expires_delta = timedelta(hours=JWT_EXPIRATION_HOURS)
    
    expire = datetime.utcnow() + expires_delta
    
    payload = {
        "sub": user_id,
        "tenant_id": tenant_id,  # Now INTEGER
        "role": role,
        "username": username,
        "email": email,
        "exp": int(expire.timestamp()),
        "iat": int(datetime.utcnow().timestamp()),
    }
    
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_access_token(token: str) -> TokenPayload:
    """Decode and validate JWT token"""
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return TokenPayload(**payload)
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expired",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.JWTError as e:
        logger.error(f"JWT decode error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )


# ============================================================================
# FastAPI Dependencies
# ============================================================================

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> AuthContext:
    """
    Extract and validate user from JWT token
    
    Usage:
        @app.get("/protected")
        async def protected_route(user: AuthContext = Depends(get_current_user)):
            return {"user_id": user.user_id, "role": user.role}
    """
    token = credentials.credentials
    token_payload = decode_access_token(token)
    auth_context = token_payload.to_auth_context()
    
    if not auth_context.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive"
        )
    
    return auth_context


async def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
) -> Optional[AuthContext]:
    """Get user if authenticated, None otherwise (for optional auth)"""
    if credentials is None:
        return None
    try:
        return await get_current_user(credentials)
    except HTTPException:
        return None


# ============================================================================
# Role-Based Access Control Dependencies
# ============================================================================

class RoleChecker:
    """Dependency to check user role"""
    
    def __init__(self, allowed_roles: List[UserRole]):
        self.allowed_roles = allowed_roles
    
    def __call__(self, user: AuthContext = Depends(get_current_user)) -> AuthContext:
        if user.role not in self.allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. Required roles: {[r.value for r in self.allowed_roles]}"
            )
        return user


def require_role(*roles: UserRole):
    """
    Dependency to require specific role(s)
    
    Usage:
        @app.get("/admin")
        async def admin_only(user: AuthContext = Depends(require_role(UserRole.MASTER, UserRole.TENANT_ADMIN))):
            return {"message": "Admin access granted"}
    """
    return Depends(RoleChecker(allowed_roles=list(roles)))


def require_master(user: AuthContext = Depends(get_current_user)) -> AuthContext:
    """
    Dependency to require MASTER role
    
    Usage:
        @app.get("/master")
        async def master_only(user: AuthContext = Depends(require_master)):
            return {"message": "Master access granted"}
    """
    if not user.is_master:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. MASTER role required."
        )
    return user


def require_tenant_admin(user: AuthContext = Depends(get_current_user)) -> AuthContext:
    """
    Dependency to require TENANT_ADMIN or MASTER role
    
    Usage:
        @app.get("/tenant-admin")
        async def tenant_admin_route(user: AuthContext = Depends(require_tenant_admin)):
            return {"message": "Tenant admin access granted"}
    """
    if not (user.is_master or user.is_tenant_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. TENANT_ADMIN or MASTER role required."
        )
    return user


# ============================================================================
# Tenant Access Control
# ============================================================================

class TenantAccessChecker:
    """Dependency to check tenant access"""
    
    def __init__(self, tenant_id_param: str = "tenant_id"):
        self.tenant_id_param = tenant_id_param
    
    def __call__(
        self,
        tenant_id: str = None,
        user: AuthContext = Depends(get_current_user)
    ) -> AuthContext:
        """
        Check if user can access the requested tenant
        
        tenant_id can come from:
        - Path parameter
        - Query parameter
        - Request body (must be passed explicitly)
        """
        if tenant_id and not user.can_access_tenant(tenant_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied to tenant {tenant_id}"
            )
        return user


def require_tenant_access(
    user: AuthContext = Depends(get_current_user),
    x_tenant_id: Optional[str] = Header(None, alias="X-Tenant-ID")
) -> AuthContext:
    """
    Dependency to check tenant access via header
    
    Usage:
        @app.get("/api/data")
        async def get_data(user: AuthContext = Depends(require_tenant_access)):
            # User's tenant_id is validated
            return {"tenant_id": user.tenant_id}
    """
    # If X-Tenant-ID header is provided, validate access
    if x_tenant_id:
        if not user.can_access_tenant(x_tenant_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied to tenant {x_tenant_id}"
            )
    
    return user


# ============================================================================
# Database Context Helper
# ============================================================================

def set_rls_context(cursor, user: AuthContext):
    """
    Set PostgreSQL session variables for RLS
    
    Usage:
        cursor = conn.cursor()
        set_rls_context(cursor, user)
        cursor.execute("SELECT * FROM messages")  # RLS policies applied
    """
    cursor.execute(f"SET LOCAL app.tenant_id = '{user.tenant_id}'")
    cursor.execute(f"SET LOCAL app.user_role = '{user.role.value}'")
    
    logger.debug(f"RLS context set: tenant_id={user.tenant_id}, role={user.role.value}")


# ============================================================================
# Audit Logger
# ============================================================================

async def log_audit(
    user: AuthContext,
    action: str,
    resource_type: str,
    resource_id: Optional[str] = None,
    old_values: Optional[dict] = None,
    new_values: Optional[dict] = None,
    metadata: Optional[dict] = None,
    ip_address: Optional[str] = None,
    user_agent: Optional[str] = None,
    conn = None
):
    """
    Log sensitive operation to audit_logs table
    
    Usage:
        await log_audit(
            user=user,
            action="CREATE_TENANT",
            resource_type="tenant",
            resource_id=str(new_tenant_id),
            new_values={"name": tenant_name},
            ip_address=request.client.host
        )
    """
    if conn is None:
        # Skip logging if no connection provided
        logger.warning("Audit log skipped: no database connection")
        return
    
    try:
        cursor = conn.cursor()
        
        query = """
            INSERT INTO audit_logs (
                user_id, user_role, tenant_id,
                action, resource_type, resource_id,
                old_values, new_values, metadata,
                ip_address, user_agent
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        
        import json

        # Use default=str to safely serialize datetimes and other non-serializable types
        old_values_json = json.dumps(old_values, default=str) if old_values is not None else None
        new_values_json = json.dumps(new_values, default=str) if new_values is not None else None
        metadata_json = json.dumps(metadata, default=str) if metadata is not None else None

        cursor.execute(query, (
            user.user_id,
            user.role.value,
            user.tenant_id,
            action,
            resource_type,
            resource_id,
            old_values_json,
            new_values_json,
            metadata_json,
            ip_address,
            user_agent
        ))
        
        conn.commit()
        cursor.close()
        
        logger.info(f"Audit log: {action} by {user.username} ({user.role.value})")
        
    except Exception as e:
        logger.error(f"Failed to log audit: {e}")
        # Don't raise exception - audit logging failure shouldn't break operations
