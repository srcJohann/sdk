# 🚀 DOM360 - Quick Start Guide

Sistema completo de chat com agentes AI (SDR/COPILOT) integrado com PostgreSQL.

## ⚡ Início Rápido

### 1️⃣ Configurar Ambiente

Edite o arquivo `.env` na raiz do projeto:

```bash
nano .env
```

**Configuração mínima necessária:**

```env
# PostgreSQL (Configure a senha!)
DB_PASSWORD=sua_senha_aqui

# O resto já está configurado com valores padrão
```

### 2️⃣ Iniciar Sistema

Execute **um único comando**:

```bash
./start.sh
```

O script irá:
- ✅ Verificar Python, Node.js e PostgreSQL
- ✅ Verificar/criar banco de dados
- ✅ Criar ambiente virtual Python e instalar dependências
- ✅ Instalar dependências do frontend
- ✅ Iniciar backend FastAPI (porta 3001)
- ✅ Iniciar frontend React (porta 5173)

### 3️⃣ Acessar

- **Frontend**: http://localhost:5173
- **Backend API**: http://localhost:3001
- **API Docs**: http://localhost:3001/docs (Swagger interativo)
- **Health Check**: http://localhost:3001/api/health

---

## 📁 Estrutura do Projeto

```
SDK/
├── .env                      # ⚙️ Configuração centralizada
├── start.sh                  # 🚀 Script de inicialização
├── configure_postgres.sh     # 🔧 Configuração PostgreSQL
│
├── database/                 # 🗄️ PostgreSQL Schema
│   ├── migrate.sh           # Script de migração
│   ├── 001_schema_up.sql    # Schema principal
│   ├── 002_triggers_functions.sql
│   └── 003_example_queries.sql
│
├── backend/                  # 🐍 FastAPI Backend
│   ├── server.py            # Servidor principal
│   ├── requirements.txt     # Dependências Python
│   └── .venv/              # Ambiente virtual (auto-criado)
│
└── frontend/app/            # ⚛️ React Frontend
    ├── src/
    │   ├── services/
    │   │   └── dom360ApiService.js  # Cliente API
    │   └── hooks/
    │       └── useChatWithAgent.js  # Hook React
    └── package.json
```

---

## 🔧 Configuração Avançada

### Arquivo `.env` Completo

```env
# ============================================================================
# PostgreSQL Database
# ============================================================================
DB_HOST=localhost
DB_PORT=5432
DB_NAME=dom360_db
DB_USER=postgres
DB_PASSWORD=                    # ⚠️ CONFIGURE AQUI!

# ============================================================================
# Backend API (FastAPI)
# ============================================================================
BACKEND_PORT=3001
AGENT_API_URL=http://localhost:8000  # URL da sua API de agentes

# ============================================================================
# Frontend (React + Vite)
# ============================================================================
VITE_API_URL=http://localhost:3001
VITE_TENANT_ID=00000000-0000-0000-0000-000000000001
VITE_INBOX_ID=00000000-0000-0000-0001-000000000001
VITE_USER_PHONE=+5511999998888
VITE_USER_NAME=Usuário Teste

# ============================================================================
# Environment
# ============================================================================
NODE_ENV=development
PYTHON_ENV=development
```

### Configurar PostgreSQL sem Senha

Se não tiver senha configurada:

```bash
./configure_postgres.sh
```

Escolha a opção 1 (usar `~/.pgpass`) - mais seguro e prático!

---

## 🛠️ Comandos Úteis

### Backend (FastAPI)

```bash
# Ativar ambiente virtual
cd backend
source .venv/bin/activate

# Instalar dependências
pip install -r requirements.txt

# Iniciar manualmente
python server.py

# Ou com reload automático
uvicorn server:app --reload --port 3001
```

### Frontend (React)

```bash
cd frontend/app

# Instalar dependências
npm install

# Iniciar desenvolvimento
npm run dev

# Build para produção
npm run build
```

### Database

```bash
cd database

# Criar banco
./migrate.sh up

# Popular com dados de teste
./migrate.sh seed

# Ver status
./migrate.sh status

# Rollback
./migrate.sh down
```

---

## 📡 API Endpoints

### FastAPI Backend

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/api/health` | Health check |
| POST | `/api/chat` | Enviar mensagem para agente |
| GET | `/api/conversations` | Listar conversas |
| GET | `/api/conversations/{id}/messages` | Mensagens de uma conversa |
| GET | `/api/dashboard/consumption` | Dashboard de consumo |

**Headers obrigatórios:**
- `X-Tenant-ID`: ID do tenant
- `X-Inbox-ID`: ID do inbox

### Exemplo de Request

```bash
curl -X POST http://localhost:3001/api/chat \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: 00000000-0000-0000-0000-000000000001" \
  -H "X-Inbox-ID: 00000000-0000-0000-0001-000000000001" \
  -d '{
    "message": "Olá, preciso de ajuda",
    "agent_type": "SDR",
    "user_phone": "+5511999999999",
    "user_name": "João"
  }'
```

---

## 🔍 Verificação de Problemas

### Backend não inicia

```bash
# Ver logs
tail -f logs/backend.log

# Verificar se porta está em uso
lsof -i :3001

# Testar conexão PostgreSQL
psql -U postgres -h localhost -c "SELECT version();"
```

### Frontend não inicia

```bash
# Ver logs
tail -f logs/frontend.log

# Verificar se porta está em uso
lsof -i :5173

# Limpar cache e reinstalar
cd frontend/app
rm -rf node_modules package-lock.json
npm install
```

### PostgreSQL não conecta

```bash
# Configurar autenticação
./configure_postgres.sh

# Ou adicionar senha ao .env
nano .env
# DB_PASSWORD=sua_senha
```

---

## 🎯 Integração com Frontend Existente

### 1. Inicializar o serviço

```javascript
import { apiService } from './services/dom360ApiService';

// Na inicialização da app
apiService.initialize(
    import.meta.env.VITE_TENANT_ID,
    import.meta.env.VITE_INBOX_ID
);
```

### 2. Usar o hook customizado

```javascript
import useChatWithAgent from './hooks/useChatWithAgent';

function ChatComponent() {
    const {
        messages,
        isLoading,
        error,
        sendMessage,
        conversationId,
        switchAgent,
    } = useChatWithAgent();

    const handleSend = async (text) => {
        await sendMessage(text);
    };

    return (
        <div>
            {messages.map(msg => (
                <div key={msg.message_id}>
                    <strong>{msg.role}:</strong> {msg.content}
                </div>
            ))}
            {isLoading && <p>Enviando...</p>}
            {error && <p>Erro: {error}</p>}
        </div>
    );
}
```

---

## 📊 Features Implementadas

### Backend (FastAPI)

✅ Pool de conexões PostgreSQL  
✅ Row Level Security (RLS) por tenant  
✅ Integração com Agent API (SDR/COPILOT)  
✅ Logging estruturado  
✅ CORS configurado  
✅ Documentação Swagger automática  
✅ Health checks  

### Database

✅ Multi-tenancy com RLS  
✅ Particionamento mensal (messages, api_logs)  
✅ Triggers automáticos (message_index, consumo)  
✅ Funções de criptografia  
✅ Score de leads (BANT)  
✅ Dashboard de consumo em tempo real  

### Frontend

✅ Service layer com tratamento de erros  
✅ Custom hooks React  
✅ Headers automáticos (tenant/inbox)  
✅ Gerenciamento de estado de chat  
✅ Integração com .env  

---

## 📚 Documentação Adicional

- **[RESUMO_IMPLEMENTACAO.md](./RESUMO_IMPLEMENTACAO.md)** - Visão geral completa
- **[database/README.md](./database/README.md)** - Documentação do banco
- **[database/ERD.md](./database/ERD.md)** - Diagramas e relacionamentos
- **[database/SECURITY_CHECKLIST.md](./database/SECURITY_CHECKLIST.md)** - Segurança

---

## 🆘 Suporte

### Logs

Todos os logs ficam em `/logs/`:
- `backend.log` - Logs do FastAPI
- `frontend.log` - Logs do Vite

### Health Check

Verifique se tudo está funcionando:

```bash
# Backend
curl http://localhost:3001/api/health

# Esperado: {"status":"healthy","database":"connected",...}
```

### Parar Sistema

Pressione `Ctrl+C` no terminal onde executou `./start.sh`

Ou manualmente:

```bash
pkill -f "uvicorn server:app"
pkill -f "vite"
```

---

## 🎉 Pronto para Usar!

Execute e comece a conversar com seus agentes:

```bash
./start.sh
```

Abra http://localhost:5173 e teste! 🚀
