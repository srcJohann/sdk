# Docker Swarm Deployment - SDK-Deploy

Stack Docker Swarm completo para a aplicação SDK com integração automática de Traefik e HTTPS.

## 📁 Arquivos Criados

```
├── docker-stack.yml           # Stack principal (Swarm + Traefik)
├── docker-compose.local.yml   # Compose para desenvolvimento local
├── Dockerfile.backend         # Build do backend (FastAPI)
├── Dockerfile.frontend        # Build do frontend (React + Vite)
├── .dockerignore-swarm        # Arquivos ignorados no build
├── deploy.sh                  # Script de deployment com CLI
├── build-local.sh             # Script para build local das imagens
├── check-deploy.sh            # Verificador pre-deployment
└── DEPLOY_GUIDE.md            # Guia detalhado de deployment
```

## 🚀 Quick Start (5 minutos)

### 1. Verificar pré-requisitos

```bash
./check-deploy.sh
```

Este script verifica:
- ✓ Docker instalado e rodando
- ✓ Swarm Mode ativo
- ✓ Rede `network_public` existente
- ✓ Imagens Docker
- ✓ Configuração `.env`
- ✓ Stack anterior

### 2. Inicializar Swarm (primeira vez)

```bash
docker swarm init

# Criar rede overlay
docker network create -d overlay network_public
```

### 3. Build das imagens

```bash
./build-local.sh
```

Ou manualmente:

```bash
docker build -f Dockerfile.backend -t sdk-backend:latest .
docker build -f Dockerfile.frontend -t sdk-frontend:latest .
```

### 4. Deploy

```bash
./deploy.sh deploy
```

### 5. Verificar status

```bash
./deploy.sh status
```

## 🛠️ Comandos Úteis

### Manage stack

```bash
# Fazer build e deploy completo
./deploy.sh update

# Ver logs (real-time)
./deploy.sh logs backend
./deploy.sh logs frontend

# Ver status completo
./deploy.sh status

# Escalar serviço
docker service scale sdk_backend=3

# Remover stack
./deploy.sh down
```

### Debug

```bash
# Entrar no container
docker exec -it <container_id> /bin/sh

# Ver variáveis de ambiente
docker exec <container_id> env | grep BACKEND

# Teste de API
curl -H "Host: api.srcjohann.com.br" http://localhost/health

# Ver labels do Traefik
docker service inspect sdk_backend | grep -A 30 "Labels"
```

## 📋 Variáveis de Ambiente (.env)

Arquivo `docker-stack.yml` injeta automaticamente via `env_file`:

```env
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=dom360_db_sdk
DB_USER=postgres
DB_PASSWORD=admin

# Backend
BACKEND_BIND_HOST=0.0.0.0
BACKEND_BIND_PORT=3001
PUBLIC_BACKEND_URL=https://api.srcjohann.com.br

# Frontend
FRONTEND_BIND_PORT=5173
PUBLIC_FRONTEND_URL=https://sdk.srcjohann.com.br
VITE_API_URL=https://api.srcjohann.com.br

# Security
JWT_SECRET=<sua_chave>
CORS_ORIGINS=https://sdk.srcjohann.com.br,https://api.srcjohann.com.br

# Environment
NODE_ENV=production
PYTHON_ENV=production
```

## 🔒 Labels do Traefik

O stack inclui labels automáticas:

**Backend:**
```yaml
traefik.enable: "true"
traefik.http.routers.backend.rule: "Host(`api.srcjohann.com.br`)"
traefik.http.routers.backend.entrypoints: "websecure"
traefik.http.routers.backend.tls.certresolver: "lets"  # Let's Encrypt
traefik.http.services.backend.loadbalancer.server.port: "3001"
```

**Frontend:**
```yaml
traefik.enable: "true"
traefik.http.routers.frontend.rule: "Host(`sdk.srcjohann.com.br`)"
traefik.http.routers.frontend.entrypoints: "websecure"
traefik.http.routers.frontend.tls.certresolver: "lets"
traefik.http.services.frontend.loadbalancer.server.port: "5173"
```

### Recursos

- ✅ HTTPS automático com Let's Encrypt
- ✅ Certificados auto-renováveis
- ✅ Roteamento por hostname
- ✅ Health checks
- ✅ Rolling updates (zero-downtime)

## 🐳 Docker Images

### Backend

**Dockerfile.backend**
- Base: `python:3.11-slim`
- Framework: FastAPI + Uvicorn
- Dependências: `requirements.txt`
- Porta: `3001` (configurável)
- Health check: `/health`

### Frontend

**Dockerfile.frontend**
- Build: Node 20 Alpine
- Framework: React + Vite
- Servidor: `serve`
- Porta: `5173` (configurável)
- Health check: GET `/`

## 🔄 Estratégia de Update

Por padrão, o stack usa **rolling updates**:

```yaml
update_config:
  parallelism: 1      # Uma réplica por vez
  delay: 10s          # Espera 10s entre updates
```

Garantia: **Zero downtime** durante updates.

## 📊 Monitoramento

### Ver serviços

```bash
docker stack services sdk

# Output:
# ID                  NAME           MODE        REPLICAS  IMAGE
# abc123def456        sdk_backend    replicated  1/1       sdk-backend:latest
# xyz789uvw012        sdk_frontend   replicated  1/1       sdk-frontend:latest
```

### Ver tasks/containers

```bash
docker stack ps sdk

# Output:
# ID           NAME              IMAGE                DESIRED  CURRENT  STATE
# task1        sdk_backend.1     sdk-backend:latest   Running  Running  Running
# task2        sdk_frontend.1    sdk-frontend:latest  Running  Running  Running
```

### Logs em tempo real

```bash
# Docker 20.10+
docker service logs sdk_backend -f
docker service logs sdk_frontend -f

# Via script
./deploy.sh logs backend
./deploy.sh logs frontend
```

## 🔧 Troubleshooting

### Stack não inicia

```bash
# Verificar tasks
docker stack ps sdk --no-trunc

# Ver logs do serviço
docker service logs sdk_backend
```

### Imagens não encontradas

```bash
# Verificar se imagens existem
docker images | grep sdk

# Refazer build
./build-local.sh
```

### Traefik não roteia

```bash
# Verificar labels
docker service inspect sdk_backend --pretty | grep -A 50 Labels

# Testar conectividade interna
docker exec <backend_container> curl http://localhost:3001/health
```

### Conexão com banco recusada

```bash
# Verificar se DB_HOST está correto em .env
# Se o banco está em outro host/container:
#   - DB_HOST=<ip_do_host_db>
#   - DB_PORT=5432

# Testar conectividade
docker exec <backend_container> \
  psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT 1"
```

## 📚 Estrutura do docker-stack.yml

```yaml
version: '3.9'

services:
  backend:
    image: sdk-backend:latest
    env_file: .env                    # Injeta variáveis
    deploy:
      mode: replicated
      replicas: 1
      labels: [traefik configs]       # Roteamento automático
      restart_policy: on-failure
    networks:
      - network_public                # Rede overlay

  frontend:
    image: sdk-frontend:latest
    env_file: .env
    deploy:
      mode: replicated
      replicas: 1
      labels: [traefik configs]
      restart_policy: on-failure
    networks:
      - network_public

networks:
  network_public:
    external: true                    # Rede pré-existente
```

## 🚀 Deployment em Produção

### Checklist

- [ ] `.env` configurado corretamente
- [ ] `./check-deploy.sh` passou em todas as verificações
- [ ] Imagens buildadas: `./build-local.sh`
- [ ] Rede `network_public` criada
- [ ] Docker Swarm ativo
- [ ] Traefik rodando

### Passos

```bash
# 1. Verificar
./check-deploy.sh

# 2. Build (se primeira vez)
./build-local.sh

# 3. Deploy
./deploy.sh deploy

# 4. Verificar status
./deploy.sh status

# 5. Testar
curl https://api.srcjohann.com.br/health
curl https://sdk.srcjohann.com.br
```

## 🔐 Segurança

### Melhorias recomendadas

1. **Usar Docker Secrets para senhas:**

```bash
echo "sua_senha_db" | docker secret create db_password -
```

Depois adicionar em `docker-stack.yml`:

```yaml
secrets:
  db_password:
    external: true

services:
  backend:
    secrets:
      - db_password
    environment:
      DB_PASSWORD_FILE: /run/secrets/db_password
```

2. **Limitar recursos:**

```yaml
deploy:
  resources:
    limits:
      cpus: '1'
      memory: 512M
    reservations:
      cpus: '0.5'
      memory: 256M
```

3. **Network policies:**
   - Backend e Frontend em rede overlay
   - Isolamento de tráfego
   - Apenas Traefik faz roteamento externo

## 📖 Documentação

- [Docker Stack Docs](https://docs.docker.com/engine/reference/commandline/stack/)
- [Docker Swarm Guide](https://docs.docker.com/engine/swarm/)
- [Traefik Docker Provider](https://doc.traefik.io/traefik/providers/docker/)
- [FastAPI Deployment](https://fastapi.tiangolo.com/deployment/)
- [Vite Deploy](https://vitejs.dev/guide/build.html)

---

**Criado em:** 20 de outubro de 2025  
**Ambiente:** Docker Swarm + Traefik + HTTPS
