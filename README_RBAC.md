# 🎯 DOM360 - Master & Tenant RBAC System

[![Status](https://img.shields.io/badge/status-production--ready-brightgreen)]()
[![Backend](https://img.shields.io/badge/backend-FastAPI-009688)]()
[![Database](https://img.shields.io/badge/database-PostgreSQL-336791)]()
[![Auth](https://img.shields.io/badge/auth-JWT+bcrypt-orange)]()
[![RLS](https://img.shields.io/badge/security-Row%20Level%20Security-red)]()

Sistema multi-tenant com **RBAC hierárquico** (Master, Tenant Admin, Tenant User) para o DOM360, incluindo:

- ✅ **Row Level Security (RLS)** para isolamento de dados no PostgreSQL
- ✅ **JWT Authentication** com bcrypt para hashing de senhas
- ✅ **3 níveis de acesso** com validação de permissões
- ✅ **N:N Tenant-Inbox** para gestão flexível
- ✅ **Master Settings** com configuração dinâmica de SDR endpoint
- ✅ **Audit Logging** de ações sensíveis
- ✅ **Métricas Globais** para monitoramento Master

---

## 📋 Índice

- [Arquitetura](#-arquitetura)
- [Instalação Rápida](#-instalação-rápida)
- [Roles e Permissões](#-roles-e-permissões)
- [API Endpoints](#-api-endpoints)
- [Frontend](#-frontend)
- [Segurança](#-segurança)
- [Troubleshooting](#-troubleshooting)
- [Documentação](#-documentação)

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                        MASTER                                │
│  • Gerencia todos os tenants                                 │
│  • Configura SDR endpoint                                    │
│  • Acessa métricas globais                                   │
│  • Auditoria completa                                        │
└─────────────────────────────────────────────────────────────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
    ┌──────▼──────┐ ┌─────▼──────┐ ┌─────▼──────┐
    │  TENANT A   │ │  TENANT B  │ │  TENANT C  │
    │             │ │            │ │            │
    │ ┌─────────┐ │ │ ┌────────┐ │ │ ┌────────┐ │
    │ │ Admin   │ │ │ │ Admin  │ │ │ │ Admin  │ │
    │ ├─────────┤ │ │ ├────────┤ │ │ ├────────┤ │
    │ │ Users   │ │ │ │ Users  │ │ │ │ Users  │ │
    │ └─────────┘ │ │ └────────┘ │ │ └────────┘ │
    │             │ │            │ │            │
    │ Inboxes 1-N │ │ Inboxes 1-N│ │ Inboxes 1-N│
    └─────────────┘ └────────────┘ └────────────┘
                           │
                ┌──────────┴──────────┐
                │   PostgreSQL RLS    │
                │  Isolamento Total   │
                └─────────────────────┘
```

---

## 🚀 Instalação Rápida

### Opção 1: Script Automático ⚡

```bash
cd /home/johann/SDK
./setup_rbac.sh
```

O script irá:
1. Aplicar migração SQL
2. Instalar dependências Python
3. Configurar `.env` com JWT secret aleatório
4. Atualizar senha do MASTER (opcional)
5. Configurar SDR endpoint

### Opção 2: Manual 🔧

#### 1. Aplicar Migração

```bash
cd database
psql -U postgres -d dom360_db -f 004_master_tenant_rbac.sql
```

#### 2. Instalar Dependências

```bash
cd backend
pip install -r requirements.txt
```

#### 3. Configurar Ambiente

Crie `.env`:

```env
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=dom360_db
DB_USER=postgres
DB_PASSWORD=sua_senha

# JWT (IMPORTANTE: Use secret forte em produção!)
JWT_SECRET="seu-secret-minimo-32-caracteres-aqui"
JWT_EXPIRATION_HOURS=24

# Agent API
AGENT_API_URL=http://localhost:8000

# Backend
BACKEND_PORT=3001
```

#### 4. Alterar Senha Master

```bash
python3 -c "
import bcrypt
password = b'SuaSenhaForte123!'
hash = bcrypt.hashpw(password, bcrypt.gensalt()).decode('utf-8')
print(hash)
"
# Copiar o hash e executar:
psql -U postgres -d dom360_db -c "
UPDATE users 
SET password_hash = 'HASH_AQUI' 
WHERE email = 'master@dom360.local';
"
```

#### 5. Iniciar Servidor

```bash
cd backend
python server_rbac.py
```

---

## 🔐 Roles e Permissões

### MASTER (Super Admin)
- ✅ CRUD de todos os tenants
- ✅ Associar/remover inboxes de qualquer tenant
- ✅ Criar/editar/deletar qualquer usuário (incluindo outros MASTERs)
- ✅ Configurar `sdr_agent_endpoint` e `server_config`
- ✅ Acessar métricas globais (todos os tenants)
- ✅ Visualizar audit logs completos
- ✅ Bypass de RLS (vê dados de todos os tenants)

### TENANT_ADMIN (Administrador do Tenant)
- ✅ Gerenciar usuários **do próprio tenant**
- ✅ Criar apenas `TENANT_USER`
- ✅ Visualizar métricas **do próprio tenant**
- ✅ Gerenciar configurações do tenant
- ❌ Não pode acessar dados de outros tenants
- ❌ Não pode configurar master_settings

### TENANT_USER (Usuário Operacional)
- ✅ Usar a aplicação (enviar mensagens, ver conversas)
- ✅ Ver apenas próprias conversas
- ✅ Dashboard com métricas do tenant
- ❌ Não pode gerenciar usuários
- ❌ Não pode alterar configurações

---

## 📡 API Endpoints

### Autenticação

```bash
# Login
POST /api/auth/login
Body: {"email": "...", "password": "..."}
Response: {"access_token": "...", "user": {...}}

# Info usuário atual
GET /api/auth/me
Headers: Authorization: Bearer TOKEN
```

### Gerenciamento de Usuários

```bash
# Criar usuário (TENANT_ADMIN+)
POST /api/auth/users
Headers: Authorization: Bearer TOKEN
Body: {
  "tenant_id": "uuid",
  "role": "TENANT_USER",
  "name": "...",
  "username": "...",
  "email": "...",
  "password": "..."
}

# Listar usuários (filtrado por RBAC)
GET /api/auth/users?tenant_id=...&role=...
Headers: Authorization: Bearer TOKEN

# Atualizar usuário
PUT /api/auth/users/{user_id}
Headers: Authorization: Bearer TOKEN
Body: {"name": "...", "email": "..."}

# Deletar usuário (soft delete)
DELETE /api/auth/users/{user_id}
Headers: Authorization: Bearer TOKEN
```

### Admin - Tenants (MASTER Only)

```bash
# Criar tenant
POST /api/admin/tenants
Headers: Authorization: Bearer MASTER_TOKEN
Body: {"name": "...", "slug": "..."}

# Listar tenants com métricas
GET /api/admin/tenants
Headers: Authorization: Bearer MASTER_TOKEN

# Atualizar tenant
PUT /api/admin/tenants/{id}
Headers: Authorization: Bearer MASTER_TOKEN
Body: {"name": "...", "is_active": true}

# Associar inbox a tenant
POST /api/admin/tenants/{id}/inboxes
Headers: Authorization: Bearer MASTER_TOKEN
Body: {"inbox_id": "uuid"}

# Remover associação
DELETE /api/admin/tenants/{id}/inboxes/{inbox_id}
Headers: Authorization: Bearer MASTER_TOKEN
```

### Admin - Master Settings (MASTER Only)

```bash
# Obter configurações
GET /api/admin/master-settings
Headers: Authorization: Bearer MASTER_TOKEN

# Atualizar configurações
PUT /api/admin/master-settings
Headers: Authorization: Bearer MASTER_TOKEN
Body: {
  "sdr_agent_endpoint": "http://localhost:8000",
  "sdr_agent_timeout_ms": 30000,
  "server_config": {...}
}

# Health check do SDR
POST /api/admin/master-settings/health-check
Headers: Authorization: Bearer MASTER_TOKEN
```

### Admin - Métricas Globais (MASTER Only)

```bash
# Métricas de todos os tenants
GET /api/admin/metrics?from_date=2025-01-01&to_date=2025-12-31
Headers: Authorization: Bearer MASTER_TOKEN
Response: {
  "total_tenants": 5,
  "active_tenants": 4,
  "total_conversations": 1543,
  "total_tokens": 2456789,
  ...
}
```

### Chat (RLS Applied)

```bash
# Enviar mensagem
POST /api/chat
Headers: 
  Authorization: Bearer TOKEN
  X-Inbox-ID: inbox-uuid
Body: {
  "message": "...",
  "agent_type": "SDR",
  "user_phone": "+5511999998888",
  "user_name": "João"
}

# Listar conversas (apenas do tenant)
GET /api/conversations
Headers: Authorization: Bearer TOKEN

# Mensagens de conversa
GET /api/conversations/{id}/messages
Headers: Authorization: Bearer TOKEN
```

---

## ⚛️ Frontend

### Setup

```bash
cd frontend/app
npm install
npm run dev
```

### Uso do AuthContext

```jsx
import { AuthProvider, useAuth, MasterRoute } from './contexts/AuthContext';

function App() {
  return (
    <AuthProvider>
      <Router>
        <Route path="/login" element={<LoginPage />} />
        
        <Route path="/master/*" element={
          <MasterRoute>
            <MasterArea />
          </MasterRoute>
        } />
        
        <Route path="/dashboard" element={
          <ProtectedRoute>
            <Dashboard />
          </ProtectedRoute>
        } />
      </Router>
    </AuthProvider>
  );
}

function SomeComponent() {
  const { user, isMaster, authFetch } = useAuth();
  
  const loadData = async () => {
    const response = await authFetch('http://localhost:3001/api/data');
    // Token automatically included in headers
  };
  
  return (
    <div>
      {isMaster() && <AdminPanel />}
      <UserDashboard user={user} />
    </div>
  );
}
```

### Componentes Disponíveis

- ✅ `TenantManagement` - CRUD de tenants (MASTER only)
- 🚧 `MasterSettings` - Config SDR endpoint (TODO)
- 🚧 `GlobalMetrics` - Dashboard Master (TODO)
- 🚧 `InboxAssociations` - Gerenciar inbox-tenant (TODO)
- 🚧 `UserManagement` - CRUD usuários (TODO)
- 🚧 `AuditLogs` - Visualizar logs (TODO)

---

## 🔒 Segurança

### Row Level Security (RLS)

Todas as queries respeitam RLS automaticamente via session variables:

```python
# Backend aplica contexto RLS antes de queries
set_rls_context(cursor, user)  # Define app.tenant_id e app.user_role
cursor.execute("SELECT * FROM messages")  # RLS filtro aplicado
```

Policies no PostgreSQL:

```sql
CREATE POLICY message_rbac_policy ON messages
    FOR ALL
    USING (
        is_master_user() OR 
        tenant_id = current_tenant_id()
    );
```

### JWT Token

- **Algorithm:** HS256
- **Expiration:** Configurável (default: 24h)
- **Secret:** Deve ter mínimo 32 caracteres
- **Storage:** localStorage no frontend
- **Rotation:** TODO (implementar refresh tokens)

### Passwords

- **Hashing:** bcrypt com cost factor 12
- **Validation:** Mínimo 8 caracteres
- **Storage:** Nunca em plain text
- **Reset:** Via API (MASTER/TENANT_ADMIN)

### Audit Logging

Todas as ações sensíveis são logadas:

```sql
SELECT 
    created_at,
    u.email as user,
    action,
    resource_type,
    resource_id
FROM audit_logs al
LEFT JOIN users u ON u.id = al.user_id
ORDER BY created_at DESC;
```

Actions logadas:
- `CREATE_TENANT`, `UPDATE_TENANT`
- `ASSOCIATE_INBOX`, `DISSOCIATE_INBOX`
- `UPDATE_MASTER_SETTINGS`
- `CREATE_USER`, `UPDATE_USER`, `DELETE_USER`

---

## 🐛 Troubleshooting

### Erro: "Database pool not initialized"

**Causa:** PostgreSQL não está rodando ou credenciais incorretas.

**Solução:**
```bash
# Verificar se PostgreSQL está rodando
sudo systemctl status postgresql

# Testar conexão
psql -U postgres -d dom360_db -c "SELECT 1"

# Conferir .env
cat .env
```

### Erro: "Invalid authentication credentials"

**Causa:** Token JWT expirado ou inválido.

**Solução:**
```bash
# Fazer login novamente
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"master@dom360.local","password":"..."}'
```

### Erro: "Access denied to tenant {uuid}"

**Causa:** Usuário tentando acessar dados de outro tenant.

**Solução:** Verificar se o `X-Tenant-ID` header está correto ou se o usuário tem role MASTER.

### Erro: "Master settings not initialized"

**Causa:** Migração não foi aplicada.

**Solução:**
```bash
cd database
psql -U postgres -d dom360_db -f 004_master_tenant_rbac.sql
```

### Queries lentas

**Causa:** Falta de índices ou RLS overhead.

**Solução:**
```sql
-- Verificar índices
\d+ messages

-- Analisar query plan
EXPLAIN ANALYZE SELECT * FROM messages WHERE tenant_id = 'uuid';

-- Criar índices adicionais se necessário
CREATE INDEX idx_custom ON messages(tenant_id, created_at DESC);
```

---

## 📚 Documentação

| Documento | Descrição |
|-----------|-----------|
| **[ADR: Master & Tenant RBAC](docs/ADR_MASTER_TENANT_RBAC.md)** | Architecture Decision Record completo |
| **[Quick Start Guide](docs/RBAC_QUICK_START.md)** | Guia rápido em 5 passos |
| **[Implementation Summary](docs/IMPLEMENTACAO_MASTER_TENANT_SUMMARY.md)** | Sumário de tudo implementado |
| **[API Documentation](docs/API_DOCUMENTATION.md)** | Docs completos da API |

---

## 🧪 Testes

### Unit Tests (TODO)

```bash
cd backend
pytest tests/test_rbac.py -v
```

### Integration Tests (TODO)

```bash
cd backend
pytest tests/test_integration.py -v
```

### E2E Tests (TODO)

```bash
cd frontend/app
npm run test:e2e
```

---

## 🤝 Contribuindo

1. Criar branch: `git checkout -b feature/minha-feature`
2. Commit: `git commit -m 'feat: adicionar XYZ'`
3. Push: `git push origin feature/minha-feature`
4. Abrir Pull Request

---

## 📄 Licença

Proprietary - DOM360 Development Team

---

## 🎯 Status do Projeto

- ✅ **Backend:** 100% implementado
- 🚧 **Frontend:** 30% implementado
- 📋 **Testes:** Planejado
- 📋 **DevOps:** Planejado

**Pronto para desenvolvimento!** 🚀

---

## 📞 Suporte

**Email:** dev@dom360.com  
**Docs:** `/docs`  
**Issues:** GitHub Issues
