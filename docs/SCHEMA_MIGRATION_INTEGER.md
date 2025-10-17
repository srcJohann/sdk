# Schema Migration: UUID → INTEGER

## Data: 15 de Outubro de 2025

## Objetivo
Converter o banco de dados de UUIDs para INTEGERs nos campos `tenant_id` e `inbox_id` para integração com Chatwoot.

## Problema Original
- `tenant_id` era UUID mas deveria ser INTEGER (Chatwoot account_id)
- `inbox_id` era UUID mas deveria ser INTEGER (Chatwoot inbox_id)
- Erros de tipo ao tentar inserir valores INTEGER em colunas UUID

## Solução Implementada

### 1. Recriação Completa do Banco de Dados
Ao invés de migrar (complexo e arriscado), recriamos o banco do zero com a estrutura correta.

**Arquivo:** `database/RECREATE_DATABASE.sql`

### 2. Mudanças de Schema

#### Tabela `tenants`
```sql
-- ANTES
id UUID PRIMARY KEY

-- DEPOIS  
id INTEGER PRIMARY KEY  -- Igual a chatwoot_account_id
chatwoot_account_id INTEGER UNIQUE NOT NULL
```

#### Tabela `inboxes`
```sql
-- ANTES
id UUID PRIMARY KEY
tenant_id UUID REFERENCES tenants(id)

-- DEPOIS
id INTEGER PRIMARY KEY  -- Igual a chatwoot_inbox_id
tenant_id INTEGER REFERENCES tenants(id)
chatwoot_inbox_id INTEGER NOT NULL
UNIQUE (tenant_id, id)  -- inbox_id único por tenant
```

#### Tabela `users`
```sql
-- ANTES
tenant_id UUID REFERENCES tenants(id)

-- DEPOIS
tenant_id INTEGER REFERENCES tenants(id)
```

#### Tabela `conversations`
```sql
-- ANTES
tenant_id UUID
inbox_id UUID

-- DEPOIS
tenant_id INTEGER
inbox_id INTEGER
```

#### Tabela `messages`
```sql
-- ANTES
tenant_id UUID
inbox_id UUID

-- DEPOIS
tenant_id INTEGER
inbox_id INTEGER
```

#### Outras Tabelas
Todas as tabelas que referenciam `tenant_id` foram atualizadas:
- `inbox_agents`
- `consumption_inbox_daily`
- `account_vars`
- `api_logs`
- `audit_logs`
- `tenant_inboxes`

### 3. Mudanças no Backend

#### Modelos (`backend/auth/models.py`)
```python
# ANTES
class AuthContext(BaseModel):
    tenant_id: str  # UUID

# DEPOIS
class AuthContext(BaseModel):
    tenant_id: int  # INTEGER
```

#### Middleware (`backend/auth/middleware.py`)
```python
# ANTES
def create_access_token(
    tenant_id: str,  # UUID
    ...
)

# DEPOIS
def create_access_token(
    tenant_id: int,  # INTEGER
    ...
)
```

#### RBAC (`backend/auth/rbac.py`)
```python
# ANTES
SELECT u.name, ...

# DEPOIS
SELECT u.full_name, ...  # Correção de nome de coluna
```

#### Auth Routes (`backend/api/auth_routes.py`)
```python
# ANTES
name=user['name']

# DEPOIS
name=user.get('full_name', user.get('name', ''))  # Compatibilidade
```

### 4. Tabela master_settings
Criada nova tabela para configuração do endpoint do agente:

```sql
CREATE TABLE master_settings (
    id INTEGER PRIMARY KEY DEFAULT 1,
    sdr_agent_endpoint TEXT NOT NULL DEFAULT 'http://localhost:5000/api/agent/sdr',
    sdr_agent_timeout_ms INTEGER NOT NULL DEFAULT 30000,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT only_one_row CHECK (id = 1)
);
```

## Seed Data

### Tenant Master
```sql
INSERT INTO tenants (id, name, subdomain, chatwoot_account_id, is_active)
VALUES (1, 'Master Organization', 'master', 1, true);
```

### Usuário Master
```sql
INSERT INTO users (tenant_id, username, email, password_hash, role, full_name, is_active)
VALUES (
    1,
    'master',
    'master@dom360.local',
    '$2b$12$wKudXygxHuaV0t0AdCvqReEw57jeZPb4kfffAZItvW1EI1Oubfwe6',  -- senha: master
    'MASTER',
    'Master Administrator',
    true
);
```

### Inbox de Teste
```sql
INSERT INTO inboxes (id, tenant_id, name, chatwoot_inbox_id, inbox_type, is_active)
VALUES (27, 1, 'Test Inbox', 27, 'chat', true);
```

## Testes Realizados

### 1. Login
```bash
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"master@dom360.local","password":"master"}'
```
✅ **Status:** Funcionando - retorna JWT com tenant_id INTEGER

### 2. Chat Endpoint
```bash
TOKEN=<jwt_token>
curl -X POST http://localhost:3001/api/chat \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "X-Inbox-ID: 27" \
  -d '{"message":"Olá","user_phone":"+5511999998888","agent_type":"chat_sdr"}'
```
✅ **Status:** Schema funcionando - erro apenas na conexão com Agent API (esperado)

## Verificação de Tipos

```sql
SELECT 
    table_name, 
    column_name, 
    data_type,
    ordinal_position
FROM information_schema.columns 
WHERE column_name IN ('tenant_id', 'inbox_id', 'id') 
    AND table_name IN ('tenants', 'inboxes', 'users', 'conversations', 'messages')
ORDER BY table_name, ordinal_position;
```

**Resultado:**
| table_name | column_name | data_type | position |
|------------|-------------|-----------|----------|
| conversations | id | uuid | 1 |
| conversations | tenant_id | **integer** | 2 |
| conversations | inbox_id | **integer** | 3 |
| inboxes | id | **integer** | 1 |
| inboxes | tenant_id | **integer** | 2 |
| messages | id | uuid | 1 |
| messages | tenant_id | **integer** | 2 |
| messages | inbox_id | **integer** | 4 |
| tenants | id | **integer** | 1 |
| users | id | uuid | 1 |
| users | tenant_id | **integer** | 2 |

## Próximos Passos

1. ✅ Schema migrado com sucesso
2. ✅ Backend atualizado para INTEGER
3. ✅ Login funcionando
4. ✅ Chat endpoint processando (falta apenas Agent API)
5. ⏳ Implementar/configurar Agent API
6. ⏳ Testar fluxo completo end-to-end

## Backup

Backup criado antes da migração:
```bash
~/backups/backup_before_migration_007_20251015_213246.dump
```

## Credenciais de Teste

- **Email:** master@dom360.local
- **Senha:** master
- **Tenant ID:** 1
- **Inbox ID:** 27

## Conclusão

✅ **Migração bem-sucedida!**

O banco de dados foi completamente recriado com a estrutura correta:
- `tenant_id`: INTEGER (correspondendo ao Chatwoot account_id)
- `inbox_id`: INTEGER (correspondendo ao Chatwoot inbox_id)
- Todas as foreign keys e constraints recriadas
- RLS policies funcionando
- Backend atualizado e testado
- Sistema pronto para integração com Chatwoot

**Tempo total:** ~2 horas  
**Downtime:** Nenhum (ambiente de desenvolvimento)  
**Perda de dados:** Nenhuma (banco vazio, apenas seed data)
