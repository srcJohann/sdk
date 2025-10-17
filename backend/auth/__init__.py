"""
DOM360 Authentication & Authorization Module
"""
from .models import UserRole, AuthContext, TokenPayload, UserCreate, UserUpdate, UserResponse, LoginRequest, LoginResponse
from .middleware import (
    get_current_user, 
    get_optional_user,
    require_role, 
    require_master, 
    require_tenant_admin,
    require_tenant_access,
    set_rls_context,
    create_access_token,
    log_audit,
    JWT_EXPIRATION_HOURS
)
from .rbac import RBACManager

__all__ = [
    'UserRole',
    'AuthContext',
    'TokenPayload',
    'UserCreate',
    'UserUpdate',
    'UserResponse',
    'LoginRequest',
    'LoginResponse',
    'get_current_user',
    'get_optional_user',
    'require_role',
    'require_master',
    'require_tenant_admin',
    'require_tenant_access',
    'set_rls_context',
    'create_access_token',
    'log_audit',
    'JWT_EXPIRATION_HOURS',
    'RBACManager',
]
