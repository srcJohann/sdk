# 🚀 Guia Completo de Integração - DOM360

## 📋 Índice

1. [Visão Geral](#visão-geral)
2. [Pré-requisitos](#pré-requisitos)
3. [Setup do Banco de Dados](#setup-do-banco-de-dados)
4. [Setup do Backend](#setup-do-backend)
5. [Setup do Frontend](#setup-do-frontend)
6. [Testes de Integração](#testes-de-integração)
7. [Deploy em Produção](#deploy-em-produção)
8. [Troubleshooting](#troubleshooting)

---

## 🎯 Visão Geral

Este guia demonstra como integrar completamente:

1. **PostgreSQL** - Banco de dados multi-tenant com RLS
2. **Backend API** - Node.js/Express integrando DB + Agent API
3. **Frontend React** - Interface de chat com agentes SDR/COPILOT

### Arquitetura

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   React     │─────▶│   Backend   │─────▶│  PostgreSQL │      │   Agent     │
│  Frontend   │      │   API       │      │   Database  │      │   API       │
│  (Port 5173)│◀─────│ (Port 3001) │◀─────│ (Port 5432) │      │(Port 8000)  │
└─────────────┘      └─────────────┘      └─────────────┘      └─────────────┘
                            │                                           ▲
                            └───────────────────────────────────────────┘
```

---

## 📦 Pré-requisitos

### Software Necessário

- **Node.js** 18+ ([Download](https://nodejs.org/))
- **PostgreSQL** 13+ ([Download](https://www.postgresql.org/download/))
- **Git** ([Download](https://git-scm.com/))

### Verificar Instalação

```bash
node --version    # v18.0.0+
npm --version     # 9.0.0+
psql --version    # PostgreSQL 13+
```

---

## 🗄️ Setup do Banco de Dados

### 1. Instalar PostgreSQL

```bash
# Ubuntu/Debian
sudo apt-get install postgresql-13 postgresql-contrib

# macOS
brew install postgresql@13

# Ou via Docker
docker run -d \
  --name dom360-postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  -v dom360_data:/var/lib/postgresql/data \
  postgres:13
```

### 2. Executar Migrações

```bash
cd database

# Configurar variáveis de ambiente
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=dom360_db
export DB_USER=postgres
export DB_PASSWORD=your_password

# Dar permissão ao script
chmod +x migrate.sh

# Aplicar migrações
./migrate.sh up

# Criar dados de teste
./migrate.sh seed

# Verificar status
./migrate.sh status
```

### 3. Verificar Instalação

```bash
psql -h localhost -U postgres -d dom360_db

-- No psql:
\dt                              -- Listar tabelas
SELECT COUNT(*) FROM tenants;    -- Deve retornar 1 (teste)
\q                              -- Sair
```

### 4. Criar Primeiro Tenant (Produção)

```sql
-- Conectar ao banco
psql -h localhost -U postgres -d dom360_db

-- Criar tenant
INSERT INTO tenants (name, slug, chatwoot_account_id)
VALUES ('Minha Empresa', 'minha-empresa', 1)
RETURNING id;

-- Copiar o UUID retornado (ex: 12345678-1234-1234-1234-123456789abc)

-- Configurar variáveis do tenant
INSERT INTO account_vars (
    tenant_id,
    agents_endpoint_url,
    agents_timeout_ms,
    default_agent_type
) VALUES (
    '12345678-1234-1234-1234-123456789abc',  -- Seu UUID
    'http://localhost:8000',                 -- URL do Agent API
    30000,
    'SDR'
);

-- Criar inbox
INSERT INTO inboxes (tenant_id, name, channel_type)
VALUES (
    '12345678-1234-1234-1234-123456789abc',
    'WhatsApp Principal',
    'whatsapp'
)
RETURNING id;

-- Copiar o inbox_id também
```

**Salvar estes IDs:**
- `tenant_id`: `12345678-1234-1234-1234-123456789abc`
- `inbox_id`: `87654321-4321-4321-4321-cba987654321`

---

## 🖥️ Setup do Backend

### 1. Instalar Dependências

```bash
cd backend
npm install
```

### 2. Configurar Variáveis de Ambiente

```bash
cp .env.example .env
```

Editar `.env`:

```bash
# Server Configuration
PORT=3001
NODE_ENV=development

# PostgreSQL Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=dom360_db
DB_USER=dom360_app
DB_PASSWORD=change_me_in_production  # MUDAR EM PRODUÇÃO!

# Security
ENCRYPTION_KEY=gere-uma-chave-forte-de-32-caracteres-minimo
```

### 3. Iniciar Servidor

```bash
# Development (com hot-reload)
npm run dev

# Ou production
npm start
```

Você verá:

```
╔════════════════════════════════════════════════════════════╗
║  DOM360 Backend API Server                                 ║
║  Version: 1.0.0                                            ║
║  Server running on: http://localhost:3001                  ║
╚════════════════════════════════════════════════════════════╝
```

### 4. Testar Backend

```bash
# Health check
curl http://localhost:3001/api/health

# Enviar mensagem de teste
curl -X POST http://localhost:3001/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "00000000-0000-0000-0000-000000000001",
    "inbox_id": "00000000-0000-0000-0001-000000000001",
    "agent_type": "SDR",
    "message": "Olá, quero saber sobre produtos",
    "sender_phone": "+5511999998888",
    "sender_name": "João Teste"
  }'
```

---

## 🎨 Setup do Frontend

### 1. Configurar Variáveis de Ambiente

```bash
cd frontend/app
```

Criar `.env`:

```bash
# API Backend URL
VITE_API_URL=http://localhost:3001

# Tenant Configuration (usar seus IDs reais)
VITE_TENANT_ID=12345678-1234-1234-1234-123456789abc
VITE_INBOX_ID=87654321-4321-4321-4321-cba987654321

# User Configuration (para teste)
VITE_USER_PHONE=+5511999998888
VITE_USER_NAME=Usuário Teste
```

### 2. Integrar no Componente de Chat

Editar `frontend/app/src/App.jsx`:

```jsx
import React, { useEffect, useState } from 'react';
import ChatContainer from './components/ChatContainer';
import { useChatWithAgent } from './hooks/useChatWithAgent';
import apiService from './services/dom360ApiService';

function App() {
  const [isHealthy, setIsHealthy] = useState(false);
  
  // Get config from environment
  const tenantId = import.meta.env.VITE_TENANT_ID;
  const inboxId = import.meta.env.VITE_INBOX_ID;
  const userPhone = import.meta.env.VITE_USER_PHONE;
  const userName = import.meta.env.VITE_USER_NAME;

  // Use custom hook
  const {
    messages,
    conversationId,
    isLoading,
    error,
    agentType,
    sendMessage,
    switchAgent,
  } = useChatWithAgent(tenantId, inboxId, userPhone);

  // Health check on mount
  useEffect(() => {
    const checkHealth = async () => {
      try {
        const health = await apiService.healthCheck();
        setIsHealthy(health.status === 'ok');
      } catch (err) {
        console.error('Backend unavailable:', err);
        setIsHealthy(false);
      }
    };
    checkHealth();
  }, []);

  const handleSendMessage = async (messageText) => {
    await sendMessage(messageText, userName);
  };

  if (!isHealthy) {
    return (
      <div style={{ padding: '20px', textAlign: 'center' }}>
        <h2>⚠️ Backend Unavailable</h2>
        <p>Make sure the backend server is running on port 3001</p>
        <button onClick={() => window.location.reload()}>Retry</button>
      </div>
    );
  }

  return (
    <div className="App">
      <div style={{ padding: '10px', background: '#f0f0f0', borderBottom: '1px solid #ccc' }}>
        <strong>Agent Type:</strong>{' '}
        <select value={agentType} onChange={(e) => switchAgent(e.target.value)}>
          <option value="SDR">SDR (Vendas)</option>
          <option value="COPILOT">COPILOT (Suporte)</option>
        </select>
        {conversationId && (
          <span style={{ marginLeft: '20px', fontSize: '12px', color: '#666' }}>
            Conversation ID: {conversationId.substring(0, 8)}...
          </span>
        )}
      </div>

      <ChatContainer
        messages={messages}
        onSendMessage={handleSendMessage}
        isLoading={isLoading}
        error={error}
      />
    </div>
  );
}

export default App;
```

### 3. Rodar Frontend

```bash
cd frontend/app
npm install
npm run dev
```

Abrir: `http://localhost:5173`

---

## ✅ Testes de Integração

### 1. Teste End-to-End Manual

#### Passo 1: Verificar Serviços

```bash
# Backend (Terminal 1)
cd backend && npm run dev

# Frontend (Terminal 2)
cd frontend/app && npm run dev

# Agent API (Terminal 3 - se tiver)
# python main.py api
```

#### Passo 2: Testar no Browser

1. Abrir `http://localhost:5173`
2. Digitar: "Olá, quero saber sobre produtos"
3. Verificar resposta do agente
4. Verificar que mensagens são salvas (refresh não perde histórico)

#### Passo 3: Verificar no Banco

```sql
-- No psql
SET app.tenant_id = '00000000-0000-0000-0000-000000000001';

-- Ver conversas
SELECT * FROM conversations 
WHERE tenant_id = current_tenant_id()
ORDER BY created_at DESC;

-- Ver mensagens
SELECT 
    message_index,
    role,
    COALESCE(user_message, assistant_message) as content,
    total_tokens,
    created_at
FROM messages
WHERE tenant_id = current_tenant_id()
ORDER BY created_at DESC
LIMIT 10;

-- Ver consumo de tokens
SELECT * FROM consumption_inbox_daily
WHERE tenant_id = current_tenant_id()
ORDER BY window DESC;
```

### 2. Teste de Performance

```bash
# Instalar hey (load testing tool)
go install github.com/rakyll/hey@latest

# Testar backend (100 requests)
hey -n 100 -c 10 \
  -m POST \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "00000000-0000-0000-0000-000000000001",
    "inbox_id": "00000000-0000-0000-0001-000000000001",
    "message": "Test message",
    "sender_phone": "+5511999998888"
  }' \
  http://localhost:3001/api/chat
```

### 3. Teste de Isolamento Multi-Tenant

```bash
# Criar segundo tenant
psql -h localhost -U postgres -d dom360_db << EOF
INSERT INTO tenants (id, name, slug)
VALUES ('11111111-1111-1111-1111-111111111111', 'Tenant 2', 'tenant-2');
EOF

# Testar que tenant 1 não vê dados do tenant 2
psql -h localhost -U postgres -d dom360_db << EOF
SET app.tenant_id = '00000000-0000-0000-0000-000000000001';
SELECT COUNT(*) FROM conversations;  -- Deve mostrar apenas conversas do tenant 1

SET app.tenant_id = '11111111-1111-1111-1111-111111111111';
SELECT COUNT(*) FROM conversations;  -- Deve ser 0 (novo tenant)
EOF
```

---

## 🚀 Deploy em Produção

### 1. Preparação

#### Checklist de Segurança

- [ ] Trocar senha do `dom360_app` role
- [ ] Gerar chave de criptografia forte (32+ chars)
- [ ] Habilitar SSL no PostgreSQL
- [ ] Configurar firewall (apenas IPs permitidos)
- [ ] Configurar backups automáticos
- [ ] Habilitar logs de auditoria
- [ ] Revisar [SECURITY_CHECKLIST.md](database/SECURITY_CHECKLIST.md)

#### Trocar Senhas

```sql
-- PostgreSQL
ALTER ROLE dom360_app WITH PASSWORD 'SenhaForteProd123!@#';

-- Gerar chave de criptografia
openssl rand -base64 32
```

### 2. Deploy PostgreSQL

#### Opção A: AWS RDS

```bash
# Criar RDS PostgreSQL 13+
# - Engine: PostgreSQL 13.x
# - Instance class: db.t3.small (ou maior)
# - Storage: 50GB SSD
# - Multi-AZ: Yes (produção)
# - Backup retention: 7 days

# Obter endpoint
export DB_HOST=your-rds-instance.amazonaws.com
export DB_PORT=5432

# Rodar migrações
cd database
./migrate.sh up
```

#### Opção B: Heroku Postgres

```bash
# Criar app
heroku create dom360-db

# Adicionar addon
heroku addons:create heroku-postgresql:standard-0

# Obter credenciais
heroku config:get DATABASE_URL

# Rodar migrações
heroku pg:psql < database/001_schema_up.sql
```

### 3. Deploy Backend

#### Opção A: Heroku

```bash
cd backend

# Criar app
heroku create dom360-backend

# Configurar env vars
heroku config:set \
  NODE_ENV=production \
  DB_HOST=your-db-host \
  DB_PORT=5432 \
  DB_NAME=dom360_db \
  DB_USER=dom360_app \
  DB_PASSWORD=your-password \
  ENCRYPTION_KEY=your-encryption-key

# Deploy
git push heroku main

# Verificar logs
heroku logs --tail
```

#### Opção B: Docker + AWS ECS

```bash
cd backend

# Build
docker build -t dom360-backend .

# Tag
docker tag dom360-backend:latest 123456789.dkr.ecr.us-east-1.amazonaws.com/dom360-backend:latest

# Push to ECR
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/dom360-backend:latest

# Deploy to ECS (via console ou terraform)
```

### 4. Deploy Frontend

#### Opção A: Vercel

```bash
cd frontend/app

# Install Vercel CLI
npm i -g vercel

# Deploy
vercel

# Configurar env vars no dashboard:
# - VITE_API_URL=https://your-backend.herokuapp.com
# - VITE_TENANT_ID=...
# - VITE_INBOX_ID=...
```

#### Opção B: Netlify

```bash
cd frontend/app

# Build
npm run build

# Deploy via Netlify CLI
netlify deploy --prod --dir=dist

# Ou conectar repo no dashboard Netlify
```

### 5. Configurar Monitoramento

#### Backend Monitoring (Datadog/New Relic)

```javascript
// server.js
import DatadogTracer from 'dd-trace';
DatadogTracer.init();

// Add to each endpoint
app.post('/api/chat', async (req, res) => {
    const span = DatadogTracer.startSpan('api.chat');
    // ... código ...
    span.finish();
});
```

#### Database Monitoring

```sql
-- Criar view de métricas
CREATE VIEW v_db_health AS
SELECT
    (SELECT COUNT(*) FROM pg_stat_activity) as active_connections,
    (SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active') as active_queries,
    (SELECT SUM(total_tokens) FROM consumption_inbox_daily WHERE window = CURRENT_DATE) as today_tokens,
    NOW() as checked_at;

-- Consultar periodicamente
SELECT * FROM v_db_health;
```

---

## 🐛 Troubleshooting

### Problema: "permission denied for table"

**Causa**: Não foi setado `app.tenant_id`

**Solução**:
```javascript
// Backend sempre deve setar
await client.query('SET app.tenant_id = $1', [tenantId]);
```

### Problema: "cannot connect to database"

**Verificar**:
```bash
# PostgreSQL rodando?
sudo systemctl status postgresql

# Backend pode conectar?
telnet localhost 5432

# Credenciais corretas?
psql -h localhost -U dom360_app -d dom360_db
```

### Problema: "Agent API não responde"

**Verificar**:
```bash
# Agent API rodando?
curl http://localhost:8000/healthz

# URL configurada corretamente?
SELECT agents_endpoint_url FROM account_vars 
WHERE tenant_id = current_tenant_id();
```

### Problema: "Partição não existe"

**Solução**:
```sql
SELECT create_monthly_partitions('messages', 3);
SELECT create_monthly_partitions('api_logs', 3);
```

### Problema: "Consumo incorreto"

**Solução**:
```sql
SELECT recalculate_consumption_range(
    current_tenant_id(),
    '<inbox-id>',
    '2025-01-01',
    CURRENT_DATE
);
```

---

## 📚 Próximos Passos

### Recursos Adicionais

1. **Autenticação**: Implementar JWT/OAuth2
2. **Rate Limiting**: Adicionar rate limiting por usuário
3. **Webhooks**: Notificações de eventos
4. **Analytics**: Dashboard avançado com Grafana
5. **Multi-Language**: i18n no frontend
6. **Mobile**: React Native app

### Documentação Adicional

- [Database Schema](database/README.md)
- [ERD Diagram](database/ERD.md)
- [Security Checklist](database/SECURITY_CHECKLIST.md)
- [Example Queries](database/003_example_queries.sql)
- [API Documentation](API_DOCUMENTATION.md)
- [Agent Protocol](PROTOCOLO_API_AGENTE_DOM360.md)

---

## 🤝 Suporte

**Problemas?** Abra uma issue ou consulte a documentação.

**Version**: 1.0.0  
**Last Updated**: 2025-01-15  
**License**: Proprietary - DOM360
