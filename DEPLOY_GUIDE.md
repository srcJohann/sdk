# Docker Swarm Stack - Guia de Deployment

## 📋 Pré-requisitos

- Docker Engine 20.10+ com Swarm Mode ativado
- Docker CLI
- Traefik rodando em overlay network `network_public`
- Arquivo `.env` configurado

## 🚀 Quick Start

### 1. Inicializar Docker Swarm (se ainda não fez)

```bash
docker swarm init
```

### 2. Criar rede overlay (se ainda não fez)

```bash
docker network create -d overlay network_public
```

### 3. Fazer build das imagens

```bash
./deploy.sh build
```

Ou manualmente:

```bash
docker build -f Dockerfile.backend -t sdk-backend:latest .
docker build -f Dockerfile.frontend -t sdk-frontend:latest .
```

### 4. Deployar o stack

```bash
./deploy.sh deploy
```

Ou manualmente:

```bash
docker stack deploy -c docker-stack.yml sdk
```

### 5. Verificar status

```bash
./deploy.sh status
```

Ou:

```bash
docker stack services sdk
docker stack ps sdk
```

## 📊 Comandos Úteis

### Ver logs do serviço

```bash
./deploy.sh logs backend
./deploy.sh logs frontend
```

### Atualizar e redeploy

```bash
./deploy.sh update
```

### Remover stack

```bash
./deploy.sh down
```

### Inspecionar serviço específico

```bash
docker service inspect sdk_backend --pretty
docker service inspect sdk_frontend --pretty
```

### Escalar serviço

```bash
docker service scale sdk_backend=2
```

## 🔍 Troubleshooting

### Stack não aparece

```bash
docker stack ls
```

### Serviços não iniciam

```bash
docker stack ps sdk --no-trunc
```

### Verificar labels do Traefik

```bash
docker service inspect sdk_backend | grep -A 20 "Labels"
```

### Testar conectividade

```bash
# De dentro do container
docker exec sdk_backend curl http://localhost:3001/health
```

## 📝 Variáveis de Ambiente

Todas as variáveis em `.env` são injetadas automaticamente nos serviços via `env_file`.

**Principais:**

- `BACKEND_BIND_PORT=3001` - Porta interna do backend
- `FRONTEND_BIND_PORT=5173` - Porta interna do frontend
- `DB_HOST=localhost` - Host do banco (ajuste se usar container)
- `DB_PORT=5432` - Porta PostgreSQL
- `CORS_ORIGINS` - Origens permitidas

## 🔒 Segurança

### Labels Traefik Incluídas

- ✅ HTTPS automático (Let's Encrypt)
- ✅ Certificados auto-renováveis
- ✅ Roteamento por host
- ✅ Health checks configurados

### Melhorias Recomendadas

1. **Usar secrets do Docker para senhas:**

```bash
echo "admin" | docker secret create db_password -
```

Depois atualizar `docker-stack.yml`:

```yaml
secrets:
  db_password:
    external: true

services:
  backend:
    secrets:
      - db_password
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

## 🔄 Update Strategy

### Rolling update (padrão)

```yaml
update_config:
  parallelism: 1
  delay: 10s
```

Isso garante zero-downtime updates.

## 📦 Para Ambiente Local (Desenvolvimento)

Use `docker-compose.local.yml`:

```bash
docker-compose -f docker-compose.local.yml up -d
```

## 🐛 Debug

### Entrar no container

```bash
docker exec -it sdk.1.xxxxx /bin/sh
```

### Ver variáveis de ambiente

```bash
docker exec sdk_backend env | grep -i backend
```

### Testar API

```bash
curl -H "Host: api.srcjohann.com.br" http://localhost/health
```

---

**Documentação**: [Docker Stack Reference](https://docs.docker.com/engine/reference/commandline/stack/)
**Traefik**: [Traefik Docker Swarm Guide](https://doc.traefik.io/traefik/providers/docker/)
