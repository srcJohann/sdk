# 🐍 DOM360 Backend - FastAPI

Backend API em Python com FastAPI para integração entre PostgreSQL e Agent API.

## 🚀 Quick Start

### Instalação

```bash
# Criar ambiente virtual
python3 -m venv .venv

# Ativar ambiente
source .venv/bin/activate  # Linux/Mac

# Instalar dependências
pip install -r requirements.txt
```

### Configuração

Configure o arquivo `.env` na raiz do projeto (`../.env`):

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=dom360_db
DB_USER=postgres
DB_PASSWORD=sua_senha

BACKEND_PORT=3001
AGENT_API_URL=http://localhost:8000
```

### Executar

```bash
# Modo simples
python server.py

# Modo development (com reload)
uvicorn server:app --reload --port 3001
```

## 📡 API Endpoints

Acesse a documentação interativa Swagger:

**http://localhost:3001/docs**

### Principais Endpoints

- `GET /api/health` - Health check
- `POST /api/chat` - Enviar mensagem para agente
- `GET /api/conversations` - Listar conversas
- `GET /api/conversations/{id}/messages` - Mensagens
- `GET /api/dashboard/consumption` - Dashboard

**Headers obrigatórios:**
- `X-Tenant-ID`: UUID do tenant
- `X-Inbox-ID`: UUID do inbox

## 🧪 Testar

```bash
# Health check
curl http://localhost:3001/api/health

# Enviar mensagem
curl -X POST http://localhost:3001/api/chat \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: 00000000-0000-0000-0000-000000000001" \
  -H "X-Inbox-ID: 00000000-0000-0000-0001-000000000001" \
  -d '{
    "message": "Olá!",
    "agent_type": "SDR",
    "user_phone": "+5511999999999"
  }'
```

## 📚 Dependencies

- **FastAPI** - Framework web assíncrono
- **Uvicorn** - Servidor ASGI
- **psycopg2** - Driver PostgreSQL
- **httpx** - Cliente HTTP assíncrono
- **Pydantic** - Validação de dados

## 📖 Mais Informações

Consulte [QUICK_START.md](../QUICK_START.md) para guia completo.
