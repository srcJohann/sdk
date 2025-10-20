"""
DOM360 Authentication API Endpoints
"""
import logging
import sys
import os
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, status, Request
from pydantic import BaseModel

try:
    from ..auth import (
        AuthContext,
        UserRole,
        LoginRequest,
        LoginResponse,
        UserCreate,
        UserUpdate,
        UserResponse,
        get_current_user,
        require_role,
        require_master,
        require_tenant_admin,
        RBACManager,
        create_access_token,
        JWT_EXPIRATION_HOURS
    )
except ImportError:
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    from auth import (
        AuthContext,
        UserRole,
        LoginRequest,
        LoginResponse,
        UserCreate,
        UserUpdate,
        UserResponse,
        get_current_user,
        require_role,
        require_master,
        require_tenant_admin,
        RBACManager,
        create_access_token,
        JWT_EXPIRATION_HOURS
    )

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/auth", tags=["Authentication"])


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
# Authentication Endpoints
# ============================================================================

@router.post("/login", response_model=LoginResponse)
async def login(data: LoginRequest, request: Request):
    """
    Login endpoint
    
    Returns JWT token and user information.
    """
    conn = get_db_from_request(request)
    rbac = RBACManager(conn)
    
    try:
        # Authenticate user (support either email or username)
        identifier = data.email or data.username
        user = rbac.authenticate_user(identifier, data.password)

        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        # Create access token
        access_token = create_access_token(
            user_id=str(user['id']),
            tenant_id=str(user['tenant_id']),
            role=user['role'],
            username=user['username'],
            email=user['email']
        )
        
        # Convert user to response
        user_response = UserResponse(
            id=str(user['id']),
            tenant_id=str(user['tenant_id']),
            role=UserRole(user['role']),
            name=user.get('full_name', user.get('name', '')),  # Support both full_name and name
            username=user['username'],
            email=user['email'],
            is_active=user['is_active'],
            created_at=user['created_at'],
            updated_at=user['updated_at'],
            last_login_at=user.get('last_login_at')
        )
        
        logger.info(f"User logged in: {user['email']} (role: {user['role']})")
        
        return LoginResponse(
            access_token=access_token,
            token_type="bearer",
            user=user_response,
            expires_in=JWT_EXPIRATION_HOURS * 3600
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Login error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Login failed"
        )


@router.get("/me", response_model=UserResponse)
async def get_current_user_info(user: AuthContext = Depends(get_current_user), request: Request = None):
    """
    Get current user information from token
    """
    conn = get_db_from_request(request)
    rbac = RBACManager(conn)
    
    user_data = rbac.get_user_by_id(user.user_id, user)
    
    if not user_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    return UserResponse(
        id=str(user_data['id']),
        tenant_id=str(user_data['tenant_id']),
        role=UserRole(user_data['role']),
        name=user_data['name'],
        username=user_data['username'],
        email=user_data['email'],
        is_active=user_data['is_active'],
        created_at=user_data['created_at'],
        updated_at=user_data['updated_at'],
        last_login_at=user_data.get('last_login_at')
    )


# ============================================================================
# User Management Endpoints
# ============================================================================

@router.post("/users", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(
    data: UserCreate,
    request: Request,
    user: AuthContext = Depends(require_tenant_admin)
):
    """
    Create new user
    
    **Permissions:**
    - MASTER: Can create any user (MASTER, TENANT_ADMIN, TENANT_USER)
    - TENANT_ADMIN: Can create TENANT_USER in their own tenant
    """
    conn = get_db_from_request(request)
    rbac = RBACManager(conn)
    
    try:
        new_user = rbac.create_user(data, user)
        
        return UserResponse(
            id=str(new_user['id']),
            tenant_id=str(new_user['tenant_id']),
            role=UserRole(new_user['role']),
            name=new_user.get('full_name', new_user.get('name', '')),
            username=new_user['username'],
            email=new_user['email'],
            is_active=new_user['is_active'],
            created_at=new_user['created_at'],
            updated_at=new_user['updated_at'],
            last_login_at=new_user.get('last_login_at')
        )
        
    except PermissionError as e:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"Error creating user: {e}")
        
        if "duplicate key" in str(e).lower():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="User with this email or username already exists"
            )
        
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create user: {str(e)}"
        )


@router.get("/users", response_model=list[UserResponse])
async def list_users(
    request: Request,
    user: AuthContext = Depends(get_current_user),
    tenant_id: str = None,
    role: UserRole = None,
    is_active: bool = None,
    limit: int = 100,
    offset: int = 0
):
    """
    List users
    
    **Permissions:**
    - MASTER: Can list all users
    - TENANT_ADMIN: Can list users in their tenant
    - TENANT_USER: Can only see themselves
    """
    conn = get_db_from_request(request)
    rbac = RBACManager(conn)
    
    users = rbac.list_users(
        requester=user,
        tenant_id=tenant_id,
        role=role,
        is_active=is_active,
        limit=limit,
        offset=offset
    )
    
    return [
        UserResponse(
            id=str(u['id']),
            tenant_id=str(u['tenant_id']),
            role=UserRole(u['role']),
            name=u.get('full_name', u.get('name', '')),
            username=u['username'],
            email=u['email'],
            is_active=u['is_active'],
            created_at=u['created_at'],
            updated_at=u['updated_at'],
            last_login_at=u.get('last_login_at')
        )
        for u in users
    ]


@router.get("/users/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: str,
    request: Request,
    user: AuthContext = Depends(get_current_user)
):
    """Get user by ID"""
    conn = get_db_from_request(request)
    rbac = RBACManager(conn)
    
    user_data = rbac.get_user_by_id(user_id, user)
    
    if not user_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    return UserResponse(
        id=str(user_data['id']),
        tenant_id=str(user_data['tenant_id']),
        role=UserRole(user_data['role']),
        name=user_data['name'],
        username=user_data['username'],
        email=user_data['email'],
        is_active=user_data['is_active'],
        created_at=user_data['created_at'],
        updated_at=user_data['updated_at'],
        last_login_at=user_data.get('last_login_at')
    )


@router.put("/users/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: str,
    data: UserUpdate,
    request: Request,
    user: AuthContext = Depends(get_current_user)
):
    """
    Update user
    
    **Permissions:**
    - Users can update themselves (except role)
    - TENANT_ADMIN can update users in their tenant (except MASTER users)
    - MASTER can update any user
    """
    conn = get_db_from_request(request)
    rbac = RBACManager(conn)
    
    try:
        updated_user = rbac.update_user(user_id, data, user)
        
        return UserResponse(
            id=str(updated_user['id']),
            tenant_id=str(updated_user['tenant_id']),
            role=UserRole(updated_user['role']),
            name=updated_user.get('full_name', updated_user.get('name', '')),
            username=updated_user['username'],
            email=updated_user['email'],
            is_active=updated_user['is_active'],
            created_at=updated_user['created_at'],
            updated_at=updated_user['updated_at'],
            last_login_at=updated_user.get('last_login_at')
        )
        
    except PermissionError as e:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(e)
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"Error updating user: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update user: {str(e)}"
        )


@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(
    user_id: str,
    request: Request,
    user: AuthContext = Depends(require_tenant_admin)
):
    """
    Delete user (soft delete - set is_active = false)
    
    **Permissions:**
    - MASTER: Can delete any user
    - TENANT_ADMIN: Can delete TENANT_USER in their tenant
    """
    conn = get_db_from_request(request)
    rbac = RBACManager(conn)
    
    try:
        rbac.delete_user(user_id, user)
        return None
        
    except PermissionError as e:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(e)
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"Error deleting user: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete user: {str(e)}"
        )
