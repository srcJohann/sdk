# API Documentation - DOM360 SDR Agent v1.0

## 🚀 Visão Geral

O DOM360 SDR Agent é um sistema de agentes de IA que funciona de forma **completamente independente** via API REST. Ele pode ser integrado a qualquer frontend ou sistema externo através de chamadas HTTP padronizadas.

### ✨ Características Principais

- **🤖 Agente SDR:** Qualificação de leads, busca RAG e integração CRM
- **🔧 Agente COPILOT:** Operações administrativas e gestão de dados
- **📚 Base de Conhecimento:** Sistema RAG com embeddings vetoriais
- **📞 Integração CRM:** Vtiger CRM para gestão de leads
- **🔄 Multi-tenant:** Suporte a múltiplos clientes/organizações
- **📊 Monitoramento:** Logs detalhados e métricas de performance

---

## 🏁 Quick Start

### 1. Iniciar o Servidor
```bash
python main.py api
```

### 2. Verificar Saúde
```bash
curl http://localhost:8000/healthz
```

### 3. Primeira Conversa
```bash
curl -X POST http://localhost:8000/sdr \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "req_001",
    "tenant": {
      "tenant_id": 1,
      "chatwoot_account_id": 1,
      "chatwoot_account_name": "Demo",
      "chatwoot_host": "app.chatwoot.com"
    },
    "routing": {
      "inbox_id": 27,
      "agent_type": "SDR"
    },
    "message": {
      "content": "Olá! Gostaria de saber sobre os produtos."
    },
    "sender": {
      "phone_e164": "+5511999998888"
    },
    "conversation": {
      "id": 123
    }
  }'
```

---

## 🌐 Endpoints da API

### Base URL
```
http://localhost:8000
```

### 📋 Endpoints Disponíveis

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| `GET` | `/healthz` | Status de saúde do serviço |
| `GET` | `/.well-known/agent-config` | Configurações públicas |
| `POST` | `/sdr` | Agente SDR (conversacional) |
| `POST` | `/copilot` | Agente COPILOT (administrativo) |

---

## 🤖 Endpoint SDR - `/sdr`

**Responsabilidades:**
- Qualificação de leads via conversação
- Busca RAG na base de conhecimento
- Registro de comentários no CRM
- Agendamento de diagnósticos

### Request Example
```json
{
  "request_id": "req_12345",
  "tenant": {
    "tenant_id": 1,
    "chatwoot_account_id": 1,
    "chatwoot_account_name": "Empresa Demo",
    "chatwoot_host": "app.chatwoot.com"
  },
  "routing": {
    "inbox_id": 27,
    "agent_type": "SDR"
  },
  "message": {
    "content": "Preciso de um diagnóstico para minha empresa",
    "content_type": "text",
    "created_at": "2025-01-15T10:30:00Z"
  },
  "sender": {
    "name": "João Silva",
    "phone_e164": "+5511999998888",
    "contact_id": 456
  },
  "conversation": {
    "id": 789,
    "status": "open"
  },
  "rag_options": {
    "enabled": true,
    "top_k": 5,
    "return_chunks": true,
    "match_threshold": 0.7
  },
  "calendar_booking": {
    "enabled": true,
    "booking_url": "https://calendly.com/empresa"
  }
}
```

### Response Example
```json
{
  "trace_id": "tr_abc123def456",
  "request_id": "req_12345",
  "agent_output": {
    "text": "Olá João! Fico feliz em ajudá-lo com o diagnóstico. Para começar, preciso entender melhor sua empresa. Poderia me contar sobre o setor de atuação e principais desafios?",
    "tool_calls": [
      "search_lead_by_phone",
      "search_knowledge_base"
    ],
    "rag_context": [
      {
        "doc_id": "doc_001",
        "score": 0.85,
        "snippet": "Diagnóstico empresarial é um processo sistemático...",
        "source": "knowledge_base"
      }
    ],
    "structured": {}
  },
  "usage": {
    "input_tokens": 150,
    "output_tokens": 75,
    "cached_tokens": 0,
    "total_tokens": 225,
    "model": "amazon.nova-lite-v1:0"
  },
  "latency_ms": 850,
  "session": "cw:789",
  "next_action": {
    "reply_to_user": true,
    "reply_type": "text"
  }
}
```

---

## 🔧 Endpoint COPILOT - `/copilot`

**Responsabilidades:**
- Operações administrativas no CRM
- Listagem e descrição de entidades
- Criação e atualização de registros

### Request Example
```json
{
  "request_id": "req_67890",
  "tenant": {
    "tenant_id": 1,
    "chatwoot_account_id": 1,
    "chatwoot_account_name": "Empresa Demo",
    "chatwoot_host": "app.chatwoot.com"
  },
  "routing": {
    "inbox_id": 27,
    "agent_type": "COPILOT"
  },
  "message": {
    "content": "Liste todos os leads da última semana"
  },
  "sender": {
    "phone_e164": "+5511999998888"
  },
  "conversation": {
    "id": 789
  }
}
```

---

## 💊 Health Check - `/healthz`

### Response Example
```json
{
  "status": "ok",
  "model": "amazon.nova-lite-v1:0",
  "version": "1.0.0",
  "timestamp": "2025-01-15T10:30:00.123Z",
  "details": {
    "knowledge_base": "ok",
    "agent": "initialized"
  }
}
```

### Status Values
- `ok` - Sistema funcionando normalmente
- `degraded` - Funcional, mas com problemas
- `error` - Sistema com falhas críticas

---

## ⚙️ Configuração - `/.well-known/agent-config`

### Response Example
```json
{
  "api_version": "1.0.0",
  "agent_types": ["SDR", "COPILOT"],
  "capabilities": {
    "SDR": [
      "search_knowledge_base",
      "search_lead_by_phone",
      "create_lead",
      "get_lead_comments",
      "add_comment_to_lead",
      "process_conversation_turn"
    ],
    "COPILOT": [
      "list_crm_entities",
      "describe_crm_entity",
      "search_lead_by_phone",
      "create_lead"
    ]
  },
  "rate_limits": {
    "requests_per_minute": 60,
    "requests_per_hour": 1000
  },
  "supported_languages": ["pt-BR"]
}
```

---

## 🔐 Autenticação e Segurança

### Headers Opcionais
```http
X-Agent-API-Version: 1
X-Request-ID: uuid-opcional
```

### Rate Limiting
- **60 requests/minuto** por IP
- **1000 requests/hora** por IP
- Headers de resposta informam limites:
  - `X-RateLimit-Remaining`
  - `X-RateLimit-Reset`

### Trace ID
Toda resposta inclui `X-Trace-ID` para rastreamento de logs.

---

## 📊 Monitoramento e Logs

### Estrutura de Log
```json
{
  "timestamp": "2025-01-15T10:30:00.123Z",
  "trace_id": "tr_abc123def456",
  "request_id": "req_12345",
  "level": "INFO",
  "message": "SDR Request processed",
  "details": {
    "phone": "+5511999998888",
    "agent_type": "SDR",
    "latency_ms": 850,
    "tokens_used": 225
  }
}
```

### Métricas Disponíveis
- Latência por requisição
- Uso de tokens por modelo
- Tool calls executadas
- Taxa de erro por endpoint
- Throughput por minuto

---

## 🚨 Tratamento de Erros

### Códigos de Erro HTTP
- `200` - Sucesso
- `400` - Requisição inválida
- `429` - Rate limit excedido
- `500` - Erro interno do servidor
- `503` - Serviço indisponível

### Formato de Erro
```json
{
  "trace_id": "tr_abc123def456",
  "request_id": "req_12345",
  "agent_output": null,
  "usage": null,
  "latency_ms": 50,
  "session": null,
  "next_action": {
    "reply_to_user": false
  },
  "error": {
    "code": "INVALID_PHONE_FORMAT",
    "message": "Telefone deve estar em formato E.164",
    "details": {
      "received": "11999998888",
      "expected_format": "+5511999998888"
    }
  }
}
```

### Códigos de Erro Customizados
- `INVALID_PHONE_FORMAT` - Formato de telefone inválido
- `AGENT_TYPE_MISMATCH` - Tipo de agente não corresponde ao endpoint
- `KNOWLEDGE_BASE_UNAVAILABLE` - Base de conhecimento inacessível
- `CRM_CONNECTION_FAILED` - Falha na conexão com CRM
- `INTERNAL_ERROR` - Erro interno não especificado

---

## 🔄 Fluxos de Integração

### 1. Conversa Simples
```
Frontend → POST /sdr → Agente → Resposta → Frontend
```

### 2. Conversa com RAG
```
Frontend → POST /sdr → Agente → Search KB → CRM Tools → Resposta → Frontend
```

### 3. Operação Administrativa
```
Frontend → POST /copilot → Agente → CRM Operations → Resposta → Frontend
```

---

## 📱 Exemplos de Integração

### React/JavaScript
```javascript
const chatWithAgent = async (message, phone) => {
  const response = await fetch('http://localhost:8000/sdr', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      request_id: generateUUID(),
      tenant: {
        tenant_id: 1,
        chatwoot_account_id: 1,
        chatwoot_account_name: "Demo",
        chatwoot_host: "app.chatwoot.com"
      },
      routing: {
        inbox_id: 27,
        agent_type: "SDR"
      },
      message: {
        content: message
      },
      sender: {
        phone_e164: phone
      },
      conversation: {
        id: Date.now()
      }
    })
  });
  
  return await response.json();
};
```

### Python
```python
import requests

def chat_with_agent(message: str, phone: str):
    response = requests.post('http://localhost:8000/sdr', json={
        'request_id': str(uuid4()),
        'tenant': {
            'tenant_id': 1,
            'chatwoot_account_id': 1,
            'chatwoot_account_name': 'Demo',
            'chatwoot_host': 'app.chatwoot.com'
        },
        'routing': {
            'inbox_id': 27,
            'agent_type': 'SDR'
        },
        'message': {'content': message},
        'sender': {'phone_e164': phone},
        'conversation': {'id': 123}
    })
    return response.json()
```

### cURL
```bash
curl -X POST http://localhost:8000/sdr \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "req_001",
    "tenant": {"tenant_id": 1, "chatwoot_account_id": 1, "chatwoot_account_name": "Demo", "chatwoot_host": "app.chatwoot.com"},
    "routing": {"inbox_id": 27, "agent_type": "SDR"},
    "message": {"content": "Olá!"},
    "sender": {"phone_e164": "+5511999998888"},
    "conversation": {"id": 123}
  }'
```

---

## 🏗️ Arquitetura do Sistema

### Componentes Principais

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Frontend  │───▶│  FastAPI    │───▶│   Agente    │
│   (Externo) │    │   Server    │    │   (Agno)    │
└─────────────┘    └─────────────┘    └─────────────┘
                           │                   │
                           ▼                   ▼
                   ┌─────────────┐    ┌─────────────┐
                   │  Supabase   │    │   Vtiger    │
                   │    (KB)     │    │   (CRM)     │
                   └─────────────┘    └─────────────┘
```

### Tecnologias Utilizadas
- **FastAPI** - Framework web assíncrono
- **Agno** - Framework de agentes IA
- **AWS Bedrock** - Modelos de linguagem (Nova Lite v1.0)
- **Supabase** - Base de conhecimento vetorial
- **Vtiger CRM** - Sistema de gestão de leads
- **SQLite** - Cache de conversações

---

## 🔧 Configuração e Deploy

### Variáveis de Ambiente
```bash
# AWS Bedrock
AWS_ACCESS_KEY_ID=sua_chave_aws
AWS_SECRET_ACCESS_KEY=sua_chave_secreta_aws
AWS_REGION=us-east-1

# Supabase (Base de Conhecimento)
SUPABASE_URL=https://sua-instancia.supabase.co
SUPABASE_ANON_KEY=sua_chave_anonima
VECTOR_TABLE_NAME=rag_documents

# Vtiger CRM (Opcional)
VTIGER_URL=https://seu-vtiger.com
VTIGER_USERNAME=admin
VTIGER_ACCESS_KEY=sua_chave_vtiger
```

### Docker (Recomendado)
```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

EXPOSE 8000
CMD ["python", "main.py", "api"]
```

### Kubernetes
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dom360-sdr
spec:
  replicas: 3
  selector:
    matchLabels:
      app: dom360-sdr
  template:
    spec:
      containers:
      - name: agent
        image: dom360/sdr:latest
        ports:
        - containerPort: 8000
        env:
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: access-key-id
```

---

## 🧪 Testes e Desenvolvimento

### Testes Unitários
```bash
python -m pytest test/ -v
```

### Debug Local
```bash
# Terminal 1 - API Server
python main.py api

# Terminal 2 - Debug SDK
python sdk_debug.py

# Terminal 3 - Testes
curl http://localhost:8000/healthz
```

### Logs de Debug
```bash
# Ativar logs detalhados
export LOG_LEVEL=DEBUG
python main.py api
```

---

## 📈 Performance e Otimização

### Benchmarks Típicos
- **Latência média:** 500-1500ms por requisição
- **Throughput:** 50+ requests/segundo
- **Tokens/min:** 10,000-50,000 dependendo do modelo

### Otimizações Recomendadas
1. **Cache de embeddings** para consultas frequentes
2. **Pool de conexões** para CRM/Database
3. **Rate limiting** por usuário/tenant
4. **Compressão** de responses HTTP
5. **Load balancer** para múltiplas instâncias

---

## 🚀 Roadmap

### v1.1 (Próxima)
- [ ] Streaming de respostas (Server-Sent Events)
- [ ] Webhook para notificações
- [ ] Métricas Prometheus/Grafana
- [ ] Cache Redis para sessions

### v1.2 (Futuro)
- [ ] Múltiplos modelos de linguagem
- [ ] Integração com WhatsApp Business
- [ ] Dashboard administrativo
- [ ] A/B Testing de prompts

---

## 📞 Suporte

### Documentação
- **API Protocol:** `API_PROTOCOL.md`
- **Debug Guide:** `SDK_DEBUG_GUIDE.md`
- **CRM Setup:** `docs/VTIGER_SETUP.md`

### Logs e Monitoramento
Todos os logs incluem `trace_id` para facilitar o debugging:

```bash
# Buscar logs por trace_id
grep "tr_abc123def456" /var/log/dom360-sdr.log

# Monitorar em tempo real
tail -f /var/log/dom360-sdr.log | grep "ERROR"
```

### Contato
- **Issues:** GitHub Issues
- **Documentação:** Este arquivo
- **Arquitetura:** `docs/ARCHITECTURE.md`

---

**Versão da API:** 1.0.0  
**Última Atualização:** 14 de outubro de 2025  
**Status:** ✅ Produção Ready