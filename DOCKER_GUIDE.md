# 🐳 Dockerização da Aplicação DOM360

Este guia explica como usar Docker para deploy da aplicação em uma VPS.

## 📋 Índice

1. [Estrutura Docker](#estrutura-docker)
2. [Instalação Local](#instalação-local)
3. [Deploy em VPS](#deploy-em-vps)
4. [Gerenciamento de Containers](#gerenciamento-de-containers)
5. [Troubleshooting](#troubleshooting)

## 🏗️ Estrutura Docker

### Arquivos Criados

```
├── Dockerfile              # Build da aplicação
├── docker-compose.yml      # Orquestração de containers
├── docker-entrypoint.sh    # Script de inicialização
├── deploy-docker.sh        # Script de deploy para VPS
├── .env.production         # Template de variáveis de produção
└── .dockerignore          # Arquivos para ignorar no build
```

### Serviços

- **Backend (FastAPI)**: Porta 3001
- **Frontend (React)**: Integrado no backend
- **PostgreSQL**: Porta 5432
- **Nginx** (opcional): Portas 80/443
- **PgAdmin** (opcional): Porta 5050

## 🚀 Instalação Local

### Pré-requisitos

- Docker (v20.10+)
- Docker Compose (v1.29+)
- Docker Desktop (Windows/Mac) ou Docker Engine (Linux)

### Verificar Instalação

```bash
docker --version
docker-compose --version
```

### Build e Execução Local

```bash
# 1. Configurar variáveis de ambiente
cp .env.production .env.local

# 2. Editar .env.local com valores locais
nano .env.local

# 3. Build das imagens
docker-compose build

# 4. Iniciar containers
docker-compose up -d

# 5. Verificar status
docker-compose ps

# 6. Ver logs
docker-compose logs -f backend
```

### Acessar a Aplicação

- **Frontend**: http://localhost:5173 (ou http://localhost:3001 via nginx)
- **Backend**: http://localhost:3001
- **API Docs**: http://localhost:3001/docs
- **PgAdmin**: http://localhost:5050 (se iniciado)

### Parar Containers

```bash
# Parar sem remover
docker-compose stop

# Parar e remover containers
docker-compose down

# Parar, remover containers e volumes (CUIDADO!)
docker-compose down -v
```

## 🌐 Deploy em VPS

### Pré-requisitos

- VPS com Ubuntu 20.04+ ou similar
- Acesso SSH root
- Domínio configurado (opcional, mas recomendado)

### Opção 1: Usar Script Automático (Recomendado)

```bash
# 1. Na VPS, fazer download do repositório
git clone https://github.com/srcJohann/sdk.git
cd sdk

# 2. Tornar script executável
chmod +x deploy-docker.sh

# 3. Executar deployment (requer sudo)
sudo ./deploy-docker.sh
```

O script vai:
- ✅ Atualizar o sistema
- ✅ Instalar Docker
- ✅ Instalar Docker Compose
- ✅ Configurar .env para produção
- ✅ Build das imagens
- ✅ Iniciar containers
- ✅ Verificar saúde dos serviços

### Opção 2: Deploy Manual

```bash
# 1. SSH para VPS
ssh root@seu-vps-ip

# 2. Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 3. Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 4. Clonar repositório
cd /opt
sudo git clone https://github.com/srcJohann/sdk.git dom360
cd dom360

# 5. Configurar .env
sudo cp .env.production .env
sudo nano .env  # Editar com valores reais

# 6. Build e deploy
sudo docker-compose up -d

# 7. Verificar
docker-compose ps
docker-compose logs -f backend
```

## 🔧 Gerenciamento de Containers

### Ver Status

```bash
# Containers em execução
docker-compose ps

# Todos os containers
docker-compose ps -a

# Ver recursos utilizados
docker stats
```

### Logs

```bash
# Logs do backend
docker-compose logs backend

# Logs em tempo real (todos os serviços)
docker-compose logs -f

# Logs do PostgreSQL
docker-compose logs postgres

# Últimas 100 linhas
docker-compose logs --tail=100 backend
```

### Acesso aos Containers

```bash
# Shell do backend
docker-compose exec backend bash

# Shell do PostgreSQL
docker-compose exec postgres psql -U postgres -d dom360_db_sdk

# Executar comando único
docker-compose exec backend python --version
```

### Banco de Dados

```bash
# Conectar ao banco via psql
docker-compose exec postgres psql -U postgres -d dom360_db_sdk

# Fazer backup
docker-compose exec postgres pg_dump -U postgres dom360_db_sdk > backup.sql

# Restaurar backup
docker-compose exec -T postgres psql -U postgres -d dom360_db_sdk < backup.sql

# Listar databases
docker-compose exec postgres psql -U postgres -l
```

### Reiniciar Serviços

```bash
# Reiniciar tudo
docker-compose restart

# Reiniciar serviço específico
docker-compose restart backend

# Rebuild e reiniciar
docker-compose up -d --build backend

# Parar e iniciar
docker-compose stop backend
docker-compose start backend
```

## 🔐 Configuração de Produção

### Variáveis Essenciais de .env

```bash
# Banco de dados
DB_HOST=postgres                    # Nome do serviço Docker
DB_PASSWORD=sua_senha_forte         # MUDE ISSO!

# Backend
PUBLIC_BACKEND_URL=https://api.seu-dominio.com
PUBLIC_BACKEND_HOST=api.seu-dominio.com

# Frontend
PUBLIC_FRONTEND_URL=https://seu-dominio.com
PUBLIC_FRONTEND_HOST=seu-dominio.com

# Segurança
JWT_SECRET=$(openssl rand -base64 32)  # Gerar novo secret
CORS_ORIGINS=https://seu-dominio.com,https://api.seu-dominio.com

# CORS com HTTP local (desenvolvimento)
CORS_ORIGINS=http://localhost:5173,http://localhost:3001,https://seu-dominio.com

# PgAdmin (opcional)
PGADMIN_PASSWORD=sua_senha_pgadmin_forte
```

### SSL/HTTPS com Let's Encrypt

```bash
# 1. Instalar Certbot
sudo apt install certbot python3-certbot-nginx

# 2. Gerar certificado
sudo certbot certonly --standalone -d seu-dominio.com -d api.seu-dominio.com

# 3. Configurar Nginx com SSL (editar nginx.conf)
# Arquivos de certificado:
# - /etc/letsencrypt/live/seu-dominio.com/fullchain.pem
# - /etc/letsencrypt/live/seu-dominio.com/privkey.pem

# 4. Renovação automática
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
```

### Nginx com Docker

```bash
# Iniciar Nginx como reverse proxy
docker-compose --profile nginx up -d

# Verificar status
docker-compose ps nginx

# Logs do Nginx
docker-compose logs nginx
```

## 📊 Monitoramento

### Health Checks

Todos os serviços têm health checks configurados:

```bash
# Verificar saúde
docker-compose exec backend curl http://localhost:3001/api/health

# Ver resultado do health check
docker inspect --format='{{json .State.Health}}' dom360-backend | jq
```

### Backups Automáticos

```bash
# Criar script de backup diário
cat > /opt/dom360/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/dom360/backups"
mkdir -p $BACKUP_DIR
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
docker-compose exec -T postgres pg_dump -U postgres dom360_db_sdk > $BACKUP_DIR/backup_$TIMESTAMP.sql
gzip $BACKUP_DIR/backup_$TIMESTAMP.sql
find $BACKUP_DIR -mtime +7 -delete
EOF

chmod +x /opt/dom360/backup.sh

# Agendar cron (executar diariamente às 2 da manhã)
echo "0 2 * * * /opt/dom360/backup.sh" | sudo crontab -
```

## 🐛 Troubleshooting

### Backend não responde

```bash
# 1. Verificar se está rodando
docker-compose ps backend

# 2. Ver logs
docker-compose logs backend

# 3. Conectar ao container
docker-compose exec backend bash

# 4. Teste do endpoint
curl http://localhost:3001/api/health

# 5. Reiniciar
docker-compose restart backend
```

### PostgreSQL não conecta

```bash
# 1. Verificar se está rodando
docker-compose ps postgres

# 2. Ver logs
docker-compose logs postgres

# 3. Verificar volume
docker volume ls | grep dom360

# 4. Teste de conexão
docker-compose exec postgres psql -U postgres -c "SELECT 1"

# 5. Reset do banco (CUIDADO!)
docker-compose down -v
docker-compose up -d
```

### Porta já em uso

```bash
# Ver qual processo usa a porta
sudo lsof -i :3001
sudo lsof -i :5432

# Mudar porta no .env
# DB_PORT=5433
# BACKEND_PORT=3002

# Ou parar o serviço que usa a porta
sudo systemctl stop nginx
docker-compose restart backend
```

### Espaço em disco

```bash
# Ver uso de espaço
docker system df

# Limpar containers parados
docker container prune

# Limpar imagens não usadas
docker image prune

# Limpar volumes não usados
docker volume prune

# Limpeza completa (CUIDADO!)
docker system prune -a
```

## 📚 Recursos Adicionais

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [PostgreSQL Docker](https://hub.docker.com/_/postgres)
- [FastAPI Deployment](https://fastapi.tiangolo.com/deployment/)

## 🆘 Suporte

Para problemas ou dúvidas:

1. Consulte os logs: `docker-compose logs -f`
2. Verifique o arquivo `.env` está correto
3. Teste conectividade: `docker-compose exec backend curl http://localhost:3001/api/health`
4. Abra uma issue no GitHub

---

**Criado em**: 2024
**Versão**: 1.0
**Última atualização**: Outubro 2024
