"""
DOM360 RBAC Models
"""
from enum import Enum
from typing import Optional, List
from pydantic import BaseModel, Field
from datetime import datetime


class UserRole(str, Enum):
    """User roles for RBAC"""
    MASTER = "MASTER"
    TENANT_ADMIN = "TENANT_ADMIN"
    TENANT_USER = "TENANT_USER"
    
    @property
    def hierarchy_level(self) -> int:
        """Returns hierarchy level (higher = more permissions)"""
        return {
            UserRole.MASTER: 100,
            UserRole.TENANT_ADMIN: 50,
            UserRole.TENANT_USER: 10,
        }[self]
    
    def can_assign_role(self, target_role: 'UserRole') -> bool:
        """Check if this role can assign target role"""
        if self == UserRole.MASTER:
            return True
        if self == UserRole.TENANT_ADMIN and target_role == UserRole.TENANT_USER:
            return True
        return False


class AuthContext(BaseModel):
    """Authentication context for requests"""
    user_id: str = Field(..., description="User UUID")
    tenant_id: int = Field(..., description="Tenant ID (INTEGER, Chatwoot account ID)")
    role: UserRole = Field(..., description="User role")
    username: str = Field(..., description="Username")
    email: str = Field(..., description="User email")
    is_active: bool = Field(True, description="User active status")
    
    @property
    def is_master(self) -> bool:
        """Check if user is MASTER"""
        return self.role == UserRole.MASTER
    
    @property
    def is_tenant_admin(self) -> bool:
        """Check if user is TENANT_ADMIN"""
        return self.role == UserRole.TENANT_ADMIN
    
    @property
    def is_tenant_user(self) -> bool:
        """Check if user is TENANT_USER"""
        return self.role == UserRole.TENANT_USER
    
    def can_access_tenant(self, target_tenant_id: int) -> bool:
        """Check if user can access specific tenant"""
        # MASTER can access all tenants
        if self.is_master:
            return True
        # Others can only access their own tenant
        return self.tenant_id == target_tenant_id
    
    def has_role(self, *roles: UserRole) -> bool:
        """Check if user has any of the specified roles"""
        return self.role in roles


class TokenPayload(BaseModel):
    """JWT token payload"""
    sub: str = Field(..., description="Subject (user_id)")
    tenant_id: int = Field(..., description="Tenant ID (INTEGER)")
    role: str = Field(..., description="User role")
    username: str = Field(..., description="Username")
    email: str = Field(..., description="Email")
    exp: int = Field(..., description="Expiration timestamp")
    iat: int = Field(..., description="Issued at timestamp")
    
    def to_auth_context(self) -> AuthContext:
        """Convert to AuthContext"""
        return AuthContext(
            user_id=self.sub,
            tenant_id=self.tenant_id,
            role=UserRole(self.role),
            username=self.username,
            email=self.email,
            is_active=True
        )


class UserCreate(BaseModel):
    """User creation request"""
    tenant_id: int = Field(..., description="Tenant ID (INTEGER)")
    role: UserRole = Field(UserRole.TENANT_USER, description="User role")
    name: str = Field(..., min_length=1, max_length=255)
    username: str = Field(..., min_length=3, max_length=100)
    email: str = Field(..., pattern=r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
    password: str = Field(..., min_length=8, description="Plain password (will be hashed)")


class UserUpdate(BaseModel):
    """User update request"""
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    email: Optional[str] = Field(None, pattern=r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
    role: Optional[UserRole] = None
    is_active: Optional[bool] = None


class UserResponse(BaseModel):
    """User response"""
    id: str
    tenant_id: str
    role: UserRole
    name: str
    username: str
    email: str
    is_active: bool
    created_at: datetime
    updated_at: datetime
    last_login_at: Optional[datetime] = None


class LoginRequest(BaseModel):
    """Login request"""
    email: str = Field(..., description="User email")
    password: str = Field(..., description="User password")


class LoginResponse(BaseModel):
    """Login response"""
    access_token: str
    token_type: str = "bearer"
    user: UserResponse
    expires_in: int = Field(..., description="Token expiration in seconds")
