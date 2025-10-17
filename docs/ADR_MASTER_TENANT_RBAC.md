# ADR: Master & Tenant RBAC System

**Status:** ✅ Implemented  
**Date:** 2025-10-15  
**Authors:** DOM360 Development Team

---

## Context

The DOM360 system needed to evolve from a single-tenant architecture to a **multi-tenant SaaS platform** with hierarchical access control. This required implementing:

1. **Role-Based Access Control (RBAC)** with three roles: `MASTER`, `TENANT_ADMIN`, `TENANT_USER`
2. **Multi-tenant data isolation** using PostgreSQL Row Level Security (RLS)
3. **N:N relationship** between tenants and inboxes (one tenant can manage multiple inboxes)
4. **Centralized configuration** for SDR agent endpoint and server settings (Master only)
5. **Aggregated metrics** for Master to monitor all tenants

---

## Decision

We implemented a **Master & Tenant RBAC system** with the following architecture:

### 1. Role Hierarchy

```
MASTER (hierarchy_level: 100)
  ├─ Can manage all tenants
  ├─ Can create/edit/delete any user
  ├─ Can access global metrics
  ├─ Can configure sdr_agent_endpoint
  └─ Can associate inboxes to tenants

TENANT_ADMIN (hierarchy_level: 50)
  ├─ Can manage users in their tenant
  ├─ Can create TENANT_USER only
  ├─ Can view tenant-specific metrics
  └─ Cannot access other tenants

TENANT_USER (hierarchy_level: 10)
  ├─ Can use the application
  ├─ Can view own conversations
  ├─ Cannot manage users
  └─ Cannot access configuration
```

### 2. Database Schema

#### New Tables

- **`tenant_inboxes`**: N:N junction table
  - `(tenant_id, inbox_id)` → Primary Key
  - Allows one tenant to manage multiple inboxes

- **`master_settings`**: Global configuration
  - `sdr_agent_endpoint` (REQUIRED): Base URL for SDR agent API
  - `sdr_agent_api_key`: Encrypted API key
  - `server_config`: JSONB with versioned configuration (token limits, retry policies, providers)
  - `health_check_enabled`: Enable/disable automatic health checks

- **`audit_logs`**: Audit trail (partitioned by month)
  - Logs all sensitive operations (CREATE_TENANT, UPDATE_MASTER_SETTINGS, etc.)
  - Includes `user_id`, `action`, `resource_type`, `old_values`, `new_values`

#### Modified Tables

- **`users`**:
  - Added `role` column: `user_role_enum` (MASTER, TENANT_ADMIN, TENANT_USER)
  - Indexed by `(tenant_id, role)`

### 3. Row Level Security (RLS)

All tenant-scoped tables have RLS policies:

```sql
-- Example: messages table
CREATE POLICY message_rbac_policy ON messages
    FOR ALL
    USING (
        is_master_user() OR 
        tenant_id = current_tenant_id()
    );
```

**Session Variables:**
- `app.tenant_id`: Set by middleware for each request
- `app.user_role`: Set by middleware for role-based policies

**Helper Functions:**
- `current_tenant_id()`: Returns `app.tenant_id` from session
- `current_user_role()`: Returns `app.user_role` from session
- `is_master_user()`: Returns TRUE if role is MASTER

### 4. Backend Architecture (FastAPI)

#### Auth Module (`backend/auth/`)

- **`models.py`**: Pydantic models for `UserRole`, `AuthContext`, `TokenPayload`
- **`middleware.py`**: JWT authentication, password hashing, dependencies
  - `get_current_user()`: Extract user from JWT
  - `require_master()`: Enforce MASTER role
  - `require_tenant_admin()`: Enforce TENANT_ADMIN or MASTER
  - `set_rls_context()`: Set PostgreSQL session variables for RLS
  
- **`rbac.py`**: `RBACManager` class for user CRUD with permission checks

#### API Routes

- **`/api/auth/login`**: Login (returns JWT)
- **`/api/auth/me`**: Get current user info
- **`/api/auth/users`**: User CRUD (RBAC protected)

- **`/api/admin/tenants`**: Tenant CRUD (MASTER only)
- **`/api/admin/tenants/{id}/inboxes`**: Associate inboxes (MASTER only)
- **`/api/admin/metrics`**: Global metrics (MASTER only)
- **`/api/admin/master-settings`**: Configure SDR endpoint (MASTER only)

- **`/api/chat`**: Send messages (RLS applied)
- **`/api/conversations`**: List conversations (RLS applied)
- **`/api/dashboard`**: Metrics (MASTER sees all, others see own tenant)

#### Middleware Flow

```
Request → JWT Authentication → Extract AuthContext
       → DB Connection → Set RLS Context (tenant_id, user_role)
       → Route Handler → Query with RLS → Response
```

### 5. SDR Agent Endpoint Configuration

The **`sdr_agent_endpoint`** is stored in `master_settings` table and retrieved dynamically:

```python
def get_sdr_agent_endpoint(conn) -> str:
    cursor.execute("SELECT sdr_agent_endpoint, sdr_agent_timeout_ms FROM master_settings LIMIT 1")
    settings = cursor.fetchone()
    return settings['sdr_agent_endpoint'], settings['sdr_agent_timeout_ms']
```

**Health Check:**
- `POST /api/admin/master-settings/health-check` (MASTER only)
- Calls `{sdr_agent_endpoint}/health`
- Updates `health_status` and `last_health_check_at` in database

---

## Consequences

### Positive

✅ **Scalability**: Multi-tenant architecture allows SaaS growth  
✅ **Security**: RLS ensures data isolation at database level  
✅ **Flexibility**: N:N tenant-inbox relationship supports complex use cases  
✅ **Centralized Config**: Master can configure SDR endpoint without code changes  
✅ **Auditability**: All sensitive operations logged in `audit_logs`  
✅ **Performance**: Indexes on `(tenant_id, created_at)` for efficient queries  

### Negative

⚠️ **Complexity**: More complex permission logic in application and database  
⚠️ **Migration Risk**: Existing data must be migrated carefully (default tenant created)  
⚠️ **RLS Overhead**: Small performance penalty (mitigated by indexes)  
⚠️ **Master Account Security**: Critical to secure MASTER credentials (rotate immediately)  

---

## Implementation Status

### ✅ Completed

- [x] SQL migrations: `004_master_tenant_rbac.sql` (UP) and `_down.sql` (ROLLBACK)
- [x] ENUM: `user_role_enum` (MASTER, TENANT_ADMIN, TENANT_USER)
- [x] Tables: `tenant_inboxes`, `master_settings`, `audit_logs`
- [x] RLS policies for all tenant-scoped tables
- [x] Helper functions: `is_master_user()`, `current_user_role()`, etc.
- [x] Views: `v_tenant_metrics`, `v_inbox_metrics`
- [x] Function: `get_global_metrics(from_date, to_date)`
- [x] Seed: Initial MASTER user and `master_settings` record
- [x] Backend: `auth` module (models, middleware, RBAC manager)
- [x] Backend: `/api/auth/*` endpoints (login, users CRUD)
- [x] Backend: `/api/admin/*` endpoints (tenants, inboxes, metrics, master-settings)
- [x] Backend: Integrated `server_rbac.py` with RLS context injection
- [x] Dependencies: Added `pyjwt`, `bcrypt` to `requirements.txt`

### 🚧 Pending

- [ ] Frontend: React components for Master area (TenantManagement, MasterSettings, GlobalMetrics)
- [ ] Frontend: Role-based feature gating (hide Master features from non-MASTER users)
- [ ] Frontend: Auth context provider and hooks
- [ ] Unit tests: RBAC permissions, RLS policies
- [ ] Integration tests: Master creates tenant, associates inbox, views metrics
- [ ] Documentation: API docs, deployment guide

---

## Migration Guide

### 1. Run Migration

```bash
cd /home/johann/SDK/database
psql -U postgres -d dom360_db -f 004_master_tenant_rbac.sql
```

**Expected Output:**
```
✅ Master & Tenant RBAC migration completed successfully!
⚠️  IMPORTANT: Change the master user password immediately!
⚠️  Configure sdr_agent_endpoint in master_settings table!
```

### 2. Update Master Password

```sql
-- Generate new password hash (use bcrypt online tool or Python)
-- Example: bcrypt.hashpw(b'YourSecurePassword123!', bcrypt.gensalt())

UPDATE users
SET password_hash = '$2b$12$NEW_HASH_HERE'
WHERE role = 'MASTER' AND email = 'master@dom360.local';
```

### 3. Configure SDR Endpoint

```sql
UPDATE master_settings
SET 
    sdr_agent_endpoint = 'http://your-agent-api:8000',
    sdr_agent_timeout_ms = 30000,
    updated_at = NOW();
```

### 4. Create First Tenant

```bash
# Use POST /api/admin/tenants API or SQL:
INSERT INTO tenants (name, slug, is_active)
VALUES ('Acme Corp', 'acme-corp', TRUE);
```

### 5. Associate Inbox to Tenant

```bash
# Use POST /api/admin/tenants/{id}/inboxes API or SQL:
INSERT INTO tenant_inboxes (tenant_id, inbox_id, is_active)
VALUES ('tenant-uuid', 'inbox-uuid', TRUE);
```

---

## Security Considerations

### 1. JWT Secret

⚠️ **Change `JWT_SECRET` in `.env`:**

```bash
# Generate strong secret (32+ characters)
JWT_SECRET="your-super-secret-jwt-key-minimum-32-chars"
JWT_EXPIRATION_HOURS=24
```

### 2. RLS Context

Always set RLS context before queries:

```python
from auth import set_rls_context

cursor = conn.cursor()
set_rls_context(cursor, user)  # Sets app.tenant_id and app.user_role
cursor.execute("SELECT * FROM messages")  # RLS policies applied
```

### 3. API Key Encryption

Master settings `sdr_agent_api_key` should be encrypted using `pgcrypto`:

```sql
-- Encrypt (TODO: implement in backend)
UPDATE master_settings
SET sdr_agent_api_key = pgp_sym_encrypt('api-key', 'encryption-password');

-- Decrypt
SELECT pgp_sym_decrypt(sdr_agent_api_key::bytea, 'encryption-password') 
FROM master_settings;
```

### 4. Audit Logs

Review audit logs regularly:

```sql
SELECT 
    created_at, 
    action, 
    u.email as performed_by,
    resource_type,
    resource_id
FROM audit_logs al
LEFT JOIN users u ON u.id = al.user_id
WHERE action IN ('CREATE_TENANT', 'UPDATE_MASTER_SETTINGS', 'ASSOCIATE_INBOX')
ORDER BY created_at DESC
LIMIT 50;
```

---

## Testing

### Test RBAC Permissions

```python
# Test: MASTER can create tenant
response = client.post(
    "/api/admin/tenants",
    headers={"Authorization": f"Bearer {master_token}"},
    json={"name": "Test Tenant", "slug": "test-tenant"}
)
assert response.status_code == 201

# Test: TENANT_USER cannot create tenant
response = client.post(
    "/api/admin/tenants",
    headers={"Authorization": f"Bearer {tenant_user_token}"},
    json={"name": "Test Tenant", "slug": "test-tenant"}
)
assert response.status_code == 403
```

### Test RLS Isolation

```sql
-- As MASTER (can see all)
SET app.user_role = 'MASTER';
SELECT COUNT(*) FROM messages;  -- Returns all messages

-- As TENANT_USER (sees only own tenant)
SET app.tenant_id = 'tenant-uuid-1';
SET app.user_role = 'TENANT_USER';
SELECT COUNT(*) FROM messages;  -- Returns only tenant-uuid-1 messages
```

---

## Rollback

If needed, rollback migration:

```bash
psql -U postgres -d dom360_db -f 004_master_tenant_rbac_down.sql
```

**⚠️ WARNING:** This will:
- Drop `master_settings`, `tenant_inboxes`, `audit_logs` tables
- Remove `role` column from `users`
- Restore simple tenant isolation policies

---

## Future Enhancements

1. **Multi-Factor Authentication (MFA)** for MASTER accounts
2. **API Rate Limiting** per tenant
3. **Tenant Quotas** (max messages/tokens per month)
4. **Tenant Suspension** (set `is_active = false`)
5. **Advanced Metrics** (cost per tenant, revenue tracking)
6. **Webhooks** (notify Master when tenant reaches quota)
7. **Tenant Self-Service** (TENANT_ADMIN can update billing info)

---

## References

- [PostgreSQL Row Level Security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- [FastAPI Security](https://fastapi.tiangolo.com/tutorial/security/)
- [JWT Best Practices](https://datatracker.ietf.org/doc/html/rfc8725)
- [RBAC Patterns](https://en.wikipedia.org/wiki/Role-based_access_control)

---

**Questions?** Contact DOM360 DevOps team.
