# 🚀 Quick Start - DOM360 Integration

## Em 5 Minutos ⚡

### Pré-requisitos
- PostgreSQL 13+ instalado e rodando
- Node.js 18+ instalado
- Terminal/bash disponível

---

## Passo 1: Setup do Banco de Dados (2 min)

```bash
cd database

# Configurar credenciais (ajuste se necessário)
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=dom360_db
export DB_USER=postgres
export DB_PASSWORD=postgres

# Rodar migrações
./migrate.sh up

# Criar dados de teste
./migrate.sh seed

# Verificar
./migrate.sh status
```

**✅ Pronto!** Banco criado com:
- 1 tenant de teste
- 1 usuário de teste
- 1 inbox
- 1 conversa de exemplo
- Configuração do agent endpoint

---

## Passo 2: Setup do Backend (1 min)

```bash
cd ../backend

# Instalar dependências
npm install

# Copiar configuração
cp .env.example .env

# Rodar servidor
npm run dev
```

Você verá:
```
╔════════════════════════════════════════════╗
║  DOM360 Backend API Server                 ║
║  Server running on: http://localhost:3001  ║
╚════════════════════════════════════════════╝
```

**✅ Pronto!** Backend rodando.

---

## Passo 3: Testar Integração (1 min)

### Teste 1: Health Check

```bash
curl http://localhost:3001/api/health
```

Esperado:
```json
{
  "status": "ok",
  "database": "connected",
  "version": "1.0.0"
}
```

### Teste 2: Enviar Mensagem

```bash
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

**✅ Se retornar JSON com conversation_id, está funcionando!**

---

## Passo 4: Integrar Frontend (1 min)

```bash
cd ../frontend/app

# Criar .env
cat > .env << EOF
VITE_API_URL=http://localhost:3001
VITE_TENANT_ID=00000000-0000-0000-0000-000000000001
VITE_INBOX_ID=00000000-0000-0000-0001-000000000001
VITE_USER_PHONE=+5511999998888
VITE_USER_NAME=Usuário Teste
EOF

# Instalar (se ainda não instalou)
npm install

# Rodar
npm run dev
```

Abrir: **http://localhost:5173**

**✅ Pronto!** Frontend integrado ao backend e banco.

---

## 🎉 Sucesso!

Você agora tem:
- ✅ PostgreSQL com schema completo
- ✅ Backend API integrado
- ✅ Frontend React funcional
- ✅ Dados de teste prontos

---

## 🔍 Verificar no Banco

```bash
# Conectar ao PostgreSQL
psql -h localhost -U postgres -d dom360_db

# Ver tenants
SELECT * FROM tenants;

# Ver conversas
SET app.tenant_id = '00000000-0000-0000-0000-000000000001';
SELECT * FROM conversations;

# Ver mensagens
SELECT message_index, role, 
       COALESCE(user_message, assistant_message) as content,
       created_at
FROM messages
WHERE tenant_id = current_tenant_id()
ORDER BY created_at DESC;

# Ver consumo
SELECT * FROM consumption_inbox_daily
WHERE tenant_id = current_tenant_id();

# Sair
\q
```

---

## 📚 Próximos Passos

### Desenvolvimento
- Ler [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) para integração completa
- Ler [database/README.md](database/README.md) para entender o schema
- Ver [database/003_example_queries.sql](database/003_example_queries.sql) para queries úteis

### Segurança (antes de produção!)
- Ler [database/SECURITY_CHECKLIST.md](database/SECURITY_CHECKLIST.md)
- Trocar todas as senhas padrão
- Habilitar SSL no PostgreSQL
- Configurar backups

### Deploy
- Ver seção "Deploy em Produção" no [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)
- Configurar monitoramento
- Configurar CI/CD

---

## ❓ Problemas?

### Backend não conecta ao banco
```bash
# Verificar PostgreSQL rodando
sudo systemctl status postgresql

# Testar conexão manualmente
psql -h localhost -U postgres -d dom360_db
```

### "permission denied for table"
```sql
-- Precisa setar tenant_id
SET app.tenant_id = '00000000-0000-0000-0000-000000000001';
```

### Agent API não responde
```bash
# Verificar se Agent API está rodando
curl http://localhost:8000/healthz

# Atualizar endpoint se necessário
psql -h localhost -U postgres -d dom360_db
SET app.tenant_id = '00000000-0000-0000-0000-000000000001';
UPDATE account_vars 
SET agents_endpoint_url = 'http://localhost:8000'
WHERE tenant_id = current_tenant_id();
```

---

## 📞 Documentação Completa

- [SUMMARY.md](SUMMARY.md) - Resumo executivo
- [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) - Guia completo
- [database/README.md](database/README.md) - Documentação do banco
- [database/ERD.md](database/ERD.md) - Diagramas visuais
- [backend/README.md](backend/README.md) - API do backend

---

**Tempo Total**: ~5 minutos  
**Versão**: 1.0.0  
**Status**: ✅ Pronto para usar
