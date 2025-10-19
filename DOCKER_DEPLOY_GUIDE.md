# 🚀 DOM360 SDK - Guia de Deploy Revisado

**Status**: ✅ Pronto para produção com Docker

---

## 📋 O que foi revisado?

### ✅ Banco de Dados
- [x] Suporte para PostgreSQL local (host.docker.internal)
- [x] Suporte para PostgreSQL containerizado (--profile with-db)
- [x] Auto-detecção de banco existente
- [x] Migrations e seeds automáticas na inicialização
- [x] Healthchecks robustos para DB

### ✅ Backend
- [x] FastAPI rodando em container separado
- [x] Entrypoint script melhorado com retry logic
- [x] Healthcheck endpoint funcional
- [x] Logs coloridos e informativos
- [x] Non-root user para segurança
- [x] Suporte a ambos PostgreSQL (local e containerizado)

### ✅ Frontend
- [x] React + Vite rodando em container separado
- [x] Nginx otimizado para SPA
- [x] Cache de assets estáticos
- [x] Headers de segurança (CSP, X-Frame-Options, etc)
- [x] Healthcheck funcional

### ✅ Nginx Reverse Proxy
- [x] Roteia api.srcjohann.com.br → backend:3001
- [x] Roteia sdk.srcjohann.com.br → frontend:8080
- [x] Rate limiting
- [x] Compressão Gzip
- [x] Headers de segurança
- [x] Healthcheck endpoint

### ✅ Portainer
- [x] portainer-stack.yml atualizado e pronto
- [x] Instruções de deploy em Portainer
- [x] Suporte a variáveis de ambiente
- [x] Perfis corretos (with-db)

### ✅ Configuração
- [x] .env.production.example com todas as variáveis
- [x] docker-compose.prod.yml revisado e otimizado
- [x] Dockerfile backend melhorado
- [x] Dockerfile frontend otimizado
- [x] entrypoint.sh backend com output formatado

---

## 🎯 Quick Start

### Opção 1: Com PostgreSQL Local (Recomendado)

```bash
# 1. Prepare o banco de dados
createdb dom360_db_sdk
psql dom360_db_sdk < database/schema.sql
psql dom360_db_sdk < database/seeds/001_seed_master.sql

# 2. Configure variáveis
cp .env.production.example .env.production
# Edite .env.production e configure as URLs corretas

# 3. Inicie os containers
docker compose -f docker-compose.prod.yml up -d

# 4. Verifique status
docker compose ps
curl http://localhost:3001/api/health
curl http://localhost:8080
```

### Opção 2: Com PostgreSQL Containerizado

```bash
# 1. Configure variáveis
cp .env.production.example .env.production
# Edite e configure DB_HOST=postgres

# 2. Inicie com perfil with-db
docker compose --profile with-db -f docker-compose.prod.yml up -d

# 3. Aguarde migrations
docker logs -f sdk-backend

# 4. Verifique
curl http://localhost:3001/api/health
```

### Opção 3: Portainer

```bash
# 1. Acesse Portainer: http://seu-servidor:9000
# 2. Vá para Stacks → Add Stack
# 3. Cole o conteúdo de portainer-stack.yml
# 4. Configure variáveis de ambiente (veja .env.production.example)
# 5. Deploy!
```

---

## 📁 Estrutura de Arquivos Modificados

```
sdk-deploy/
├── docker-compose.prod.yml        ✨ NOVO - Suporte Postgres local/container
├── portainer-stack.yml             ✨ NOVO - Pronto para Portainer
├── .env.production.example          ✨ NOVO - Variáveis bem documentadas
├── DOCKER_PRODUCTION.md             ✨ NOVO - Guia completo de deploy
│
├── backend/
│   ├── Dockerfile                  ✅ MELHORADO - Non-root, healthcheck
│   ├── entrypoint.sh              ✅ MELHORADO - Logs coloridos, retry logic
│   └── server.py                  (sem alteração)
│
├── frontend/app/
│   ├── Dockerfile                  ✅ MELHORADO - Multi-stage, non-root
│   └── nginx.conf                  ✅ MELHORADO - SPA routing, CSP, cache
│
├── nginx/
│   ├── nginx.conf                  ✅ MELHORADO - Healthcheck endpoint
│   └── conf.d/
│       ├── api.conf               (sem alteração)
│       └── frontend.conf          (sem alteração)
│
└── database/
    ├── schema.sql                 (sem alteração)
    ├── migrations/                (sem alteração)
    └── seeds/                     (sem alteração)
```

---

## 🔑 Variáveis de Ambiente

### Postgres Local
```bash
DB_HOST=host.docker.internal          # Para Docker Desktop/Linux 20.10+
DB_PORT=5432
DB_NAME=dom360_db_sdk
DB_USER=postgres
DB_PASSWORD=SenhaForte123!
```

### Postgres Containerizado
```bash
DB_HOST=postgres                       # Nome do serviço
DB_PORT=5432
DB_NAME=dom360_db_sdk
DB_USER=postgres
DB_PASSWORD=SenhaForte123!
```

### URLs
```bash
PUBLIC_BACKEND_URL=https://api.srcjohann.com.br
PUBLIC_FRONTEND_URL=https://sdk.srcjohann.com.br
CORS_ORIGINS=https://sdk.srcjohann.com.br,https://api.srcjohann.com.br
```

### Segurança
```bash
JWT_SECRET=GenerateNewSecretWithCommand!
AGENT_API_URL=http://seu-agent-api:8000
```

---

## ✔️ Checklist Pré-Deploy

- [ ] PostgreSQL instalado e acessível (se usar local)
- [ ] Docker e Docker Compose instalados
- [ ] Variáveis de ambiente configuradas em `.env.production`
- [ ] Domínios (api.srcjohann.com.br, sdk.srcjohann.com.br) apontam para o servidor
- [ ] Portas 80 e 443 abertas no firewall
- [ ] Certificados SSL prontos (opcional, mas recomendado)
- [ ] Espaço em disco suficiente (~5GB)
- [ ] Permissões de arquivo corretas

---

## 🔍 Testes Pós-Deploy

```bash
# Verificar se todos os containers estão saudáveis
docker compose ps

# Backend
curl http://localhost:3001/api/health
curl -X OPTIONS -H "Origin: https://sdk.srcjohann.com.br" http://localhost:3001/api/health -v

# Frontend
curl http://localhost:8080/
curl http://localhost:8080/health

# Nginx (com host header)
curl -H "Host: api.srcjohann.com.br" http://localhost/api/health
curl -H "Host: sdk.srcjohann.com.br" http://localhost/

# Banco de dados
docker exec sdk-postgres psql -U postgres -d dom360_db_sdk -c "\dt"
```

---

## 🚨 Problemas Comuns

| Problema | Solução |
|----------|---------|
| Backend não encontra banco | Verifique DB_HOST e credenciais, veja DOCKER_PRODUCTION.md |
| Frontend não conecta ao backend | Verifique CORS_ORIGINS, veja DOCKER_PRODUCTION.md |
| Nginx não roteia domínios | Verifique /etc/hosts local, veja DOCKER_PRODUCTION.md |
| Containers saem com erro | Verifique logs: `docker logs sdk-backend` |
| SSL não funciona | Copie certificados para nginx/ssl/, veja DOCKER_PRODUCTION.md |

👉 **Para mais detalhes**: Veja `DOCKER_PRODUCTION.md`

---

## 📚 Documentação

- **DOCKER_PRODUCTION.md** - Guia completo com troubleshooting
- **.env.production.example** - Template de variáveis com comentários
- **docker-compose.prod.yml** - Orquestração de containers
- **portainer-stack.yml** - Deploy em Portainer

---

## 🎬 Próximos Passos

1. Configure SSL/TLS (veja DOCKER_PRODUCTION.md)
2. Configure backup automático do banco
3. Configure monitoramento (logs, métricas)
4. Documente procedimentos de manutenção
5. Teste failover e disaster recovery

---

**Dúvidas?** Consulte `DOCKER_PRODUCTION.md` ou os logs dos containers.
