# 🚀 Guia Rápido: Master & Tenant RBAC

**Objetivo:** Ativar o sistema de RBAC Master/Tenant no DOM360 em **5 passos**.

---

## 📋 Pré-requisitos

- PostgreSQL 12+ rodando
- Python 3.9+
- Banco `dom360_db` criado e migração `001_schema_up.sql` aplicada
- Backend FastAPI instalado

---

## 🔧 Passo 1: Instalar Dependências

```bash
cd /home/johann/SDK/backend
pip install -r requirements.txt
```

**Novas dependências:**
- `pyjwt==2.8.0` (autenticação JWT)
- `bcrypt==4.1.2` (hash de senhas)

---

## 🗄️ Passo 2: Aplicar Migração SQL

```bash
cd /home/johann/SDK/database

# Aplicar migração
psql -U postgres -d dom360_db -f 004_master_tenant_rbac.sql
```

**O que foi criado:**
- ✅ ENUM `user_role_enum` (MASTER, TENANT_ADMIN, TENANT_USER)
- ✅ Coluna `users.role`
- ✅ Tabela `tenant_inboxes` (N:N tenant ↔ inbox)
- ✅ Tabela `master_settings` (configuração SDR endpoint)
- ✅ Tabela `audit_logs` (auditoria de ações sensíveis)
- ✅ RLS policies com suporte a MASTER (bypass de tenant_id)
- ✅ Views `v_tenant_metrics`, `v_inbox_metrics`
- ✅ Função `get_global_metrics(from_date, to_date)`
- ✅ Usuário MASTER inicial (email: `master@dom360.local`, senha: `ChangeMe123!`)

---

## 🔐 Passo 3: Configurar Autenticação

Crie/edite `.env` no diretório raiz:

```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=dom360_db
DB_USER=postgres
DB_PASSWORD=seu_password_aqui

# JWT Authentication
JWT_SECRET="change-this-to-a-strong-random-secret-at-least-32-characters-long"
JWT_EXPIRATION_HOURS=24

# Agent API (fallback - será sobrescrito por master_settings)
AGENT_API_URL=http://localhost:8000

# Backend
BACKEND_PORT=3001
```

**⚠️ IMPORTANTE:** Gere um `JWT_SECRET` forte:

```bash
# Gerar secret aleatório
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

---

## 🔑 Passo 4: Atualizar Senha do MASTER

**Senha padrão:** `ChangeMe123!` → **ALTERE IMEDIATAMENTE!**

### Opção A: Via Python

```bash
cd /home/johann/SDK/backend
python -c "
import bcrypt
password = b'SuaSenhaForte123!'
hash = bcrypt.hashpw(password, bcrypt.gensalt()).decode('utf-8')
print(f'Hash: {hash}')
"
```

Copie o hash e atualize no banco:

```sql
UPDATE users
SET password_hash = '$2b$12$COLE_O_HASH_AQUI'
WHERE email = 'master@dom360.local' AND role = 'MASTER';
```

### Opção B: Via API (depois de iniciar servidor)

```bash
# Primeiro login com senha padrão para pegar token
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"master@dom360.local","password":"ChangeMe123!"}'

# Depois usar PUT /api/auth/users/{user_id} para trocar senha
```

---

## 🚀 Passo 5: Iniciar Servidor com RBAC

```bash
cd /home/johann/SDK/backend

# Usar o novo server com RBAC
python server_rbac.py
```

**Output esperado:**
```
🚀 Iniciando DOM360 Backend API com RBAC...
✓ Pool de conexões PostgreSQL criado
✓ RBAC Master/Tenant ativado
INFO:     Uvicorn running on http://0.0.0.0:3001 (Press CTRL+C to quit)
```

---

## 🧪 Testar Autenticação

### 1. Login como MASTER

```bash
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "master@dom360.local",
    "password": "ChangeMe123!"
  }'
```

**Resposta:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user": {
    "id": "uuid-aqui",
    "tenant_id": "master-tenant-uuid",
    "role": "MASTER",
    "name": "Master Admin",
    "email": "master@dom360.local",
    "is_active": true
  },
  "expires_in": 86400
}
```

Salve o `access_token` para próximas requisições!

### 2. Verificar Usuário Atual

```bash
TOKEN="cole-o-token-aqui"

curl http://localhost:3001/api/auth/me \
  -H "Authorization: Bearer $TOKEN"
```

### 3. Criar Tenant (MASTER only)

```bash
curl -X POST http://localhost:3001/api/admin/tenants \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Empresa Teste",
    "slug": "empresa-teste"
  }'
```

### 4. Configurar SDR Endpoint (MASTER only)

```bash
curl -X PUT http://localhost:3001/api/admin/master-settings \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "sdr_agent_endpoint": "http://localhost:8000",
    "sdr_agent_timeout_ms": 30000
  }'
```

### 5. Testar Health Check do SDR

```bash
curl -X POST http://localhost:3001/api/admin/master-settings/health-check \
  -H "Authorization: Bearer $TOKEN"
```

---

## 📊 Métricas Globais (MASTER)

```bash
# Métricas de todos os tenants
curl "http://localhost:3001/api/admin/metrics?from_date=2025-01-01&to_date=2025-12-31" \
  -H "Authorization: Bearer $TOKEN"
```

**Resposta:**
```json
{
  "total_tenants": 5,
  "active_tenants": 4,
  "total_inboxes": 12,
  "total_conversations": 1543,
  "total_messages": 8721,
  "total_tokens": 2456789,
  "avg_latency_ms": 342,
  "period_start": "2025-01-01",
  "period_end": "2025-12-31"
}
```

---

## 👥 Criar Usuários

### MASTER cria TENANT_ADMIN

```bash
curl -X POST http://localhost:3001/api/auth/users \
  -H "Authorization: Bearer $MASTER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "tenant-uuid-aqui",
    "role": "TENANT_ADMIN",
    "name": "João Silva",
    "username": "joao.silva",
    "email": "joao@empresa.com",
    "password": "SenhaSegura123!"
  }'
```

### TENANT_ADMIN cria TENANT_USER

```bash
# Login como TENANT_ADMIN primeiro
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "joao@empresa.com",
    "password": "SenhaSegura123!"
  }'

# Criar usuário operacional
curl -X POST http://localhost:3001/api/auth/users \
  -H "Authorization: Bearer $TENANT_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "tenant-uuid-aqui",
    "role": "TENANT_USER",
    "name": "Maria Santos",
    "username": "maria.santos",
    "email": "maria@empresa.com",
    "password": "OutraSenha123!"
  }'
```

---

## 📝 Associar Inbox a Tenant

```bash
# Apenas MASTER pode fazer isso
curl -X POST http://localhost:3001/api/admin/tenants/{tenant_id}/inboxes \
  -H "Authorization: Bearer $MASTER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "inbox_id": "inbox-uuid-aqui"
  }'
```

---

## 🔒 Testar Isolamento de Tenant (RLS)

### Como TENANT_USER

```bash
# Login
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"maria@empresa.com","password":"OutraSenha123!"}'

# Listar conversas (vê apenas do próprio tenant)
curl http://localhost:3001/api/conversations \
  -H "Authorization: Bearer $TENANT_USER_TOKEN"

# Tentar acessar endpoint Master (403 Forbidden)
curl http://localhost:3001/api/admin/tenants \
  -H "Authorization: Bearer $TENANT_USER_TOKEN"
# → {"detail": "Access denied. MASTER role required."}
```

---

## 🛠️ Comandos Úteis

### Listar Todos os Tenants

```bash
curl http://localhost:3001/api/admin/tenants \
  -H "Authorization: Bearer $MASTER_TOKEN"
```

### Ver Logs de Auditoria

```sql
-- No psql
SELECT 
    created_at, 
    action, 
    u.email as user,
    resource_type,
    resource_id
FROM audit_logs al
LEFT JOIN users u ON u.id = al.user_id
ORDER BY created_at DESC
LIMIT 20;
```

### Resetar Senha de Usuário (como MASTER)

```bash
# Gerar novo hash
python -c "import bcrypt; print(bcrypt.hashpw(b'NovaSenha123!', bcrypt.gensalt()).decode())"

# Atualizar no banco
UPDATE users SET password_hash = 'novo-hash-aqui' WHERE email = 'usuario@email.com';
```

---

## 📚 Próximos Passos

1. **Frontend:** Implementar área Master no React
   - Componente `TenantManagement` (CRUD de tenants)
   - Componente `MasterSettings` (configurar SDR endpoint)
   - Componente `GlobalMetricsDashboard` (métricas agregadas)

2. **Feature Gating:** Guards baseados em `user.role`
   ```jsx
   {user.role === 'MASTER' && <MasterMenu />}
   ```

3. **Testes:** Unit + integration tests para RBAC

4. **Segurança:** Rotacionar JWT_SECRET regularmente

---

## ❓ Troubleshooting

### Erro: "Database pool not initialized"

→ Verifique se o PostgreSQL está rodando e `.env` está correto.

### Erro: "Invalid authentication credentials"

→ Token JWT expirado ou inválido. Faça login novamente.

### Erro: "Access denied to tenant {uuid}"

→ Usuário tentando acessar dados de outro tenant. Verificar `X-Tenant-ID` header.

### Erro: "Master settings not initialized"

→ Migração não foi aplicada corretamente. Re-rodar `004_master_tenant_rbac.sql`.

---

## 📞 Suporte

- **Documentação completa:** `/docs/ADR_MASTER_TENANT_RBAC.md`
- **Migrações SQL:** `/database/004_master_tenant_rbac.sql`
- **Código backend:** `/backend/auth/`, `/backend/api/`

---

**🎉 Pronto! Sistema Master & Tenant RBAC ativado com sucesso!**
