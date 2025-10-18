"""
DOM360 RBAC Manager
Database operations for user/role management
"""
import logging
from typing import Optional, List, Dict, Any
from uuid import UUID
import json

from psycopg2.extras import RealDictCursor

from .models import UserRole, UserCreate, UserUpdate, UserResponse, AuthContext
from .middleware import hash_password, set_rls_context

logger = logging.getLogger(__name__)


class RBACManager:
    """Manager for RBAC operations"""
    
    def __init__(self, conn):
        """Initialize with database connection"""
        self.conn = conn
    
    def authenticate_user(self, email: str, password: str) -> Optional[Dict[str, Any]]:
        """
        Authenticate user by email and password
        
        Returns:
            User dict if authenticated, None otherwise
        """
        from .middleware import verify_password
        
        cursor = self.conn.cursor(cursor_factory=RealDictCursor)
        
        try:
            query = """
                SELECT 
                    u.id, u.tenant_id, u.role, u.full_name, u.username, 
                    u.email, u.password_hash, u.is_active,
                    u.created_at, u.updated_at, u.last_login_at
                FROM users u
                WHERE (LOWER(u.email) = LOWER(%s) OR LOWER(u.username) = LOWER(%s))
                LIMIT 1
            """
            # Use email parameter for both comparisons; caller may pass username into the email param
            cursor.execute(query, (email, email))
            user = cursor.fetchone()
            
            if not user:
                logger.warning(f"Authentication failed: user not found ({email})")
                return None
            
            if not user['is_active']:
                logger.warning(f"Authentication failed: user inactive ({email})")
                return None
            
            # Verify password
            if not verify_password(password, user['password_hash']):
                logger.warning(f"Authentication failed: invalid password ({email})")
                return None
            
            # Update last login
            update_query = "UPDATE users SET last_login_at = NOW() WHERE id = %s"
            cursor.execute(update_query, (user['id'],))
            self.conn.commit()
            
            # Remove password_hash from response
            user = dict(user)
            del user['password_hash']
            
            logger.info(f"User authenticated: {email} (role: {user['role']})")
            return user
            
        except Exception as e:
            logger.error(f"Error authenticating user: {e}")
            self.conn.rollback()
            return None
        finally:
            cursor.close()
    
    def get_user_by_id(self, user_id: str, requester: AuthContext) -> Optional[Dict[str, Any]]:
        """Get user by ID (with RBAC check)"""
        cursor = self.conn.cursor(cursor_factory=RealDictCursor)
        
        try:
            set_rls_context(cursor, requester)
            
            query = """
                SELECT 
                    id, tenant_id, role, full_name, username, email, 
                    is_active, created_at, updated_at, last_login_at
                FROM users
                WHERE id = %s
            """
            
            cursor.execute(query, (user_id,))
            return cursor.fetchone()
            
        finally:
            cursor.close()
    
    def list_users(
        self,
        requester: AuthContext,
        tenant_id: Optional[str] = None,
        role: Optional[UserRole] = None,
        is_active: Optional[bool] = None,
        limit: int = 100,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """
        List users with filters (respects RBAC)
        
        MASTER can see all users
        TENANT_ADMIN can see users in their tenant
        TENANT_USER can only see themselves
        """
        cursor = self.conn.cursor(cursor_factory=RealDictCursor)
        
        try:
            set_rls_context(cursor, requester)
            
            query = """
                SELECT 
                    id, tenant_id, role, full_name, username, email, 
                    is_active, created_at, updated_at, last_login_at
                FROM users
                WHERE 1=1
            """
            params = []
            
            # Apply filters
            if tenant_id:
                query += " AND tenant_id = %s"
                params.append(tenant_id)
            
            if role:
                query += " AND role = %s"
                params.append(role.value)
            
            if is_active is not None:
                query += " AND is_active = %s"
                params.append(is_active)
            
            # TENANT_USER can only see themselves
            if requester.is_tenant_user:
                query += " AND id = %s"
                params.append(requester.user_id)
            
            query += " ORDER BY created_at DESC LIMIT %s OFFSET %s"
            params.extend([limit, offset])
            
            cursor.execute(query, tuple(params))
            return cursor.fetchall()
            
        finally:
            cursor.close()
    
    def create_user(
        self,
        user_data: UserCreate,
        requester: AuthContext
    ) -> Dict[str, Any]:
        """
        Create new user (with RBAC validation)
        
        MASTER can create any user
        TENANT_ADMIN can create TENANT_USER in their tenant
        """
        # Validate role assignment
        if not requester.role.can_assign_role(user_data.role):
            raise PermissionError(
                f"Role {requester.role.value} cannot assign role {user_data.role.value}"
            )
        
        # TENANT_ADMIN can only create users in their own tenant
        if requester.is_tenant_admin and user_data.tenant_id != requester.tenant_id:
            raise PermissionError("TENANT_ADMIN can only create users in their own tenant")
        
        cursor = self.conn.cursor(cursor_factory=RealDictCursor)
        
        try:
            # Hash password
            password_hash = hash_password(user_data.password)
            
            query = """
                INSERT INTO users (
                    tenant_id, role, full_name, username, email, password_hash, is_active
                )
                VALUES (%s, %s, %s, %s, %s, %s, TRUE)
                RETURNING id, tenant_id, role, full_name, username, email, 
                          is_active, created_at, updated_at, last_login_at
            """
            
            cursor.execute(query, (
                user_data.tenant_id,
                user_data.role.value,
                user_data.name,
                user_data.username,
                user_data.email,
                password_hash
            ))
            
            new_user = cursor.fetchone()
            self.conn.commit()
            
            logger.info(f"User created: {new_user['email']} by {requester.username}")
            return new_user
            
        except Exception as e:
            self.conn.rollback()
            logger.error(f"Error creating user: {e}")
            raise
        finally:
            cursor.close()
    
    def update_user(
        self,
        user_id: str,
        user_data: UserUpdate,
        requester: AuthContext
    ) -> Dict[str, Any]:
        """
        Update user (with RBAC validation)
        
        Users can update themselves (except role)
        TENANT_ADMIN can update users in their tenant (except MASTER users)
        MASTER can update any user
        """
        cursor = self.conn.cursor(cursor_factory=RealDictCursor)
        
        try:
            # Get existing user
            set_rls_context(cursor, requester)
            
            query = "SELECT * FROM users WHERE id = %s"
            cursor.execute(query, (user_id,))
            existing_user = cursor.fetchone()
            
            if not existing_user:
                raise ValueError(f"User {user_id} not found")
            
            # Permission checks
            is_self = user_id == requester.user_id
            
            # TENANT_USER can only update themselves and not their role
            if requester.is_tenant_user and not is_self:
                raise PermissionError("TENANT_USER can only update themselves")
            
            if requester.is_tenant_user and user_data.role is not None:
                raise PermissionError("TENANT_USER cannot change their role")
            
            # TENANT_ADMIN cannot update MASTER users or change roles to MASTER
            if requester.is_tenant_admin:
                if existing_user['role'] == 'MASTER':
                    raise PermissionError("TENANT_ADMIN cannot update MASTER users")
                if user_data.role == UserRole.MASTER:
                    raise PermissionError("TENANT_ADMIN cannot assign MASTER role")
            
            # Build update query
            updates = []
            params = []
            
            if user_data.name is not None:
                # Database stores the user's human-readable name in 'full_name'
                updates.append("full_name = %s")
                params.append(user_data.name)
            
            if user_data.email is not None:
                updates.append("email = %s")
                params.append(user_data.email)
            
            if user_data.role is not None:
                updates.append("role = %s")
                params.append(user_data.role.value)
            
            if user_data.is_active is not None:
                updates.append("is_active = %s")
                params.append(user_data.is_active)
            
            if not updates:
                # No updates
                logger.debug(f"No updates requested for user {user_id}. incoming data: {user_data}")
                return existing_user
            
            updates.append("updated_at = NOW()")
            
            query = f"""
                UPDATE users
                SET {', '.join(updates)}
                WHERE id = %s
                RETURNING id, tenant_id, role, full_name, username, email, 
                          is_active, created_at, updated_at, last_login_at
            """
            params.append(user_id)
            
            logger.debug(f"Executing user update: query={query} params={params}")
            cursor.execute(query, tuple(params))
            updated_user = cursor.fetchone()
            self.conn.commit()
            
            logger.info(f"User updated: {updated_user['email']} by {requester.username}")
            return updated_user
            
        except Exception as e:
            self.conn.rollback()
            logger.error(f"Error updating user: {e}")
            raise
        finally:
            cursor.close()
    
    def delete_user(self, user_id: str, requester: AuthContext) -> bool:
        """
        Soft delete user (set is_active = false)
        
        MASTER can delete any user
        TENANT_ADMIN can delete TENANT_USER in their tenant
        """
        cursor = self.conn.cursor(cursor_factory=RealDictCursor)
        
        try:
            set_rls_context(cursor, requester)
            
            # Get existing user
            query = "SELECT * FROM users WHERE id = %s"
            cursor.execute(query, (user_id,))
            existing_user = cursor.fetchone()
            
            if not existing_user:
                raise ValueError(f"User {user_id} not found")
            
            # Permission checks
            if requester.is_tenant_admin:
                if existing_user['role'] in ('MASTER', 'TENANT_ADMIN'):
                    raise PermissionError("TENANT_ADMIN can only delete TENANT_USER")
            
            # Cannot delete yourself
            if user_id == requester.user_id:
                raise PermissionError("Cannot delete your own account")
            
            # Soft delete
            query = "UPDATE users SET is_active = FALSE, updated_at = NOW() WHERE id = %s"
            cursor.execute(query, (user_id,))
            self.conn.commit()
            
            logger.info(f"User deleted: {existing_user['email']} by {requester.username}")
            return True
            
        except Exception as e:
            self.conn.rollback()
            logger.error(f"Error deleting user: {e}")
            raise
        finally:
            cursor.close()
