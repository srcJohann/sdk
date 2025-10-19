# Guia de Resolução - Problemas de Conexão e Acesso

## Problema 1: Backend não consegue conectar ao PostgreSQL

### Causa
O container Docker estava tentando conectar a `127.0.0.1:5432`, mas esse é o localhost **do container**, não da máquina host onde o PostgreSQL está rodando.

### Solução
Alterado no `.env`:
```
DB_HOST=host.docker.internal
```

Isso permite que o container acesse serviços na máquina host.

### Alternativas (se `host.docker.internal` não funcionar):
1. **Usar IP da VPS**: Se você conhece o IP interno da rede (`172.31.x.x`), use:
   ```
   DB_HOST=172.31.x.x  # Substitua pelo IP real
   ```

2. **PostgreSQL em container**: Se preferir, pode adicionar PostgreSQL como serviço no docker-compose.yml

3. **Usar --network host**: Alterar o docker-compose para usar network host (não recomendado em produção)

---

## Problema 2: Frontend não acessível por sdk.srcjohann.com.br

### Causa
Faltava:
1. Proxy reverso (Nginx) para rotear os domínios
2. Configuração de DNS apontando os domínios para a VPS
3. Certificados SSL para HTTPS

### Solução Implementada

#### 1. Adicionado Nginx como proxy reverso
- `nginx` serve na porta 80/443
- Roteia `sdk.srcjohann.com.br` → Frontend
- Roteia `api.srcjohann.com.br` → Backend

#### 2. Estrutura de serviços
```
User (navegador)
   ↓
Nginx (proxy reverso)
   ├─→ sdk.srcjohann.com.br → Frontend (port 5173)
   └─→ api.srcjohann.com.br → Backend (port 3001)
```

---

## Próximas Etapas

### 1. Configurar DNS
Adicione registros A no seu provedor de DNS (Contabo/suas configurações):
```
sdk.srcjohann.com.br     A   <seu_ip_vps>
api.srcjohann.com.br     A   <seu_ip_vps>
```

### 2. Configurar Certificados SSL

#### Opção A: Let's Encrypt com Certbot (RECOMENDADO)
```bash
# Criar diretório para certificados
mkdir -p ssl

# Instalar certbot
sudo apt-get install certbot

# Gerar certificados (rodando Nginx na porta 80)
sudo certbot certonly --webroot -w /home/johann/ContaboDocs/sdk-deploy \
  -d sdk.srcjohann.com.br \
  -d api.srcjohann.com.br

# Os certificados ficarão em:
# /etc/letsencrypt/live/sdk.srcjohann.com.br/fullchain.pem
# /etc/letsencrypt/live/sdk.srcjohann.com.br/privkey.pem

# Copiar para o diretório do projeto
sudo cp /etc/letsencrypt/live/sdk.srcjohann.com.br/fullchain.pem ./ssl/cert.pem
sudo cp /etc/letsencrypt/live/sdk.srcjohann.com.br/privkey.pem ./ssl/key.pem
sudo chown $USER ./ssl/*
```

#### Opção B: Auto-gerado (apenas desenvolvimento)
```bash
mkdir -p ssl
openssl req -x509 -newkey rsa:4096 -nodes -out ssl/cert.pem -keyout ssl/key.pem -days 365
```

### 3. Verificar o PostgreSQL

Confirme que PostgreSQL está rodando e acessível:
```bash
# Na máquina da VPS
sudo systemctl status postgresql

# Verificar porta
sudo netstat -tlnp | grep 5432

# Testar conexão
psql -U postgres -d dom_db_360 -c "SELECT 1;"
```

### 4. Reiniciar os containers

```bash
# Parar containers existentes
docker-compose down

# Rebuildar e iniciar
docker-compose up -d --build

# Ver logs
docker-compose logs -f
```

### 5. Verificar conectividade

```bash
# De dentro do container backend, testar conexão com PostgreSQL
docker exec dom360-backend pg_isready -h host.docker.internal -p 5432 -U postgres

# Verificar se Nginx está rodando
docker-compose logs nginx

# Testar endpoints
curl -i http://localhost:80/health
curl -i https://sdk.srcjohann.com.br/health (com certificado válido)
curl -i https://api.srcjohann.com.br/health (com certificado válido)
```

---

## Configuração do .env Atualizada

```properties
# ============================================================================
# DOM360 - Configuração Unificada
# MODO: PRODUÇÃO VPS
# Acesso: https://sdk.srcjohann.com.br (Frontend) e https://api.srcjohann.com.br (Backend)
# ============================================================================

# ============================================================================
# PostgreSQL Database
# ============================================================================
DB_HOST=host.docker.internal
DB_PORT=5432
DB_NAME=dom_db_360
DB_USER=postgres
DB_PASSWORD="admin"

# ============================================================================
# Backend API (FastAPI)
# ============================================================================
BACKEND_PORT=3001
AGENT_API_URL=http://localhost:8000

# Back-end binding and public URL
BACKEND_BIND_HOST=0.0.0.0
BACKEND_BIND_PORT=3001
INTERNAL_BACKEND_HOST=127.0.0.1
INTERNAL_BACKEND_PORT=3001
PUBLIC_BACKEND_URL=https://api.srcjohann.com.br
PUBLIC_BACKEND_HOST=api.srcjohann.com.br

# ============================================================================
# Frontend (React + Vite)
# ============================================================================
VITE_API_URL=https://api.srcjohann.com.br
VITE_TENANT_ID="00000000-0000-0000-0000-000000000001"
VITE_INBOX_ID="00000000-0000-0000-0001-000000000001"
VITE_USER_PHONE="+5511999998888"
VITE_USER_NAME="Usuário Teste"

# Front-end binding and public URL
FRONTEND_BIND_HOST=0.0.0.0
FRONTEND_BIND_PORT=5173
INTERNAL_FRONTEND_HOST=127.0.0.1
INTERNAL_FRONTEND_PORT=5173
PUBLIC_FRONTEND_URL=https://sdk.srcjohann.com.br
PUBLIC_FRONTEND_HOST=sdk.srcjohann.com.br

# ============================================================================
# Security
# ============================================================================
JWT_SECRET="eSGm2XZ8lBfB++3TOt0Tp0rR8MimWnohTD9oqaq+Q84="

# ============================================================================
# CORS - Configuração de Origens Permitidas
# ============================================================================
CORS_ORIGINS=https://sdk.srcjohann.com.br,https://api.srcjohann.com.br

# ============================================================================
# Environment
# ============================================================================
NODE_ENV=production
PYTHON_ENV=production
```

---

## Troubleshooting

### Backend não consegue acessar PostgreSQL
```bash
# Verificar se host.docker.internal funciona no seu sistema
docker-compose exec backend ping host.docker.internal

# Se não funcionar, obter IP da máquina host
hostname -I

# E usar esse IP no .env
DB_HOST=<ip_do_host>
```

### Nginx não consegue conectar aos serviços
```bash
# Verificar conectividade entre containers
docker network inspect dom360-network

# Testar conexão
docker-compose exec nginx ping backend
docker-compose exec nginx ping frontend
```

### Certificado SSL inválido
```bash
# Se usar certificado auto-assinado, o navegador vai reclamar
# Para aceitar, vá em "Advanced" no navegador e prossiga

# Para produção com Let's Encrypt, configure-o corretamente (veja acima)
```

---

## Estrutura Final do Projeto

```
sdk-deploy/
├── .env                    # Variáveis de ambiente
├── docker-compose.yml      # Serviços (nginx, backend, frontend)
├── nginx.conf             # Configuração proxy reverso
├── Dockerfile             # Build do backend
├── backend/
│   ├── entrypoint.sh      # Aguarda PostgreSQL antes de iniciar
│   ├── server.py          # Aplicação FastAPI
│   └── ...
├── frontend/
│   ├── app/
│   │   ├── Dockerfile     # Build do frontend
│   │   ├── vite.config.js # Configuração Vite
│   │   └── ...
│   └── ...
├── ssl/
│   ├── cert.pem          # Certificado SSL
│   └── key.pem           # Chave privada SSL
└── ...
```

---

## Comandos Úteis

```bash
# Iniciar tudo
docker-compose up -d --build

# Ver logs
docker-compose logs -f

# Logs de um serviço específico
docker-compose logs -f backend
docker-compose logs -f frontend
docker-compose logs -f nginx

# Parar tudo
docker-compose down

# Remover volumes (cuidado!)
docker-compose down -v

# Executar comando dentro do container
docker-compose exec backend bash
docker-compose exec frontend bash

# Verificar health dos serviços
docker-compose ps
```
