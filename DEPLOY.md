# 🚀 DOM360 SDK - Deploy em Produção com Portainer

Guia completo para fazer deploy da aplicação DOM360 SDK (Frontend + Backend) usando Docker e Portainer.

## 📋 Índice

- [Arquitetura](#arquitetura)
- [Pré-requisitos](#pré-requisitos)
- [Configuração DNS](#configuração-dns)
- [Configuração de Variáveis](#configuração-de-variáveis)
- [Deploy no Portainer](#deploy-no-portainer)
- [Configuração SSL](#configuração-ssl)
- [Verificação](#verificação)
- [Troubleshooting](#troubleshooting)

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────┐
│                  Internet                            │
└────────────┬────────────────────────┬───────────────┘
             │                        │
             │                        │
    ┌────────▼─────────┐    ┌────────▼──────────┐
    │ sdk.srcjohann    │    │ api.srcjohann     │
    │   .com.br        │    │   .com.br         │
    │  (Frontend)      │    │   (Backend API)   │
    └────────┬─────────┘    └────────┬──────────┘
             │                        │
             │                        │
    ┌────────▼────────────────────────▼───────────┐
    │           Nginx Reverse Proxy               │
    │              (Port 80/443)                  │
    └────────┬────────────────────────┬───────────┘
             │                        │
    ┌────────▼─────────┐    ┌────────▼──────────┐
    │   Frontend       │    │    Backend        │
    │ React + Nginx    │    │   FastAPI         │
    │   (Port 8080)    │    │  (Port 3001)      │
    └──────────────────┘    └────────┬──────────┘
                                     │
                            ┌────────▼──────────┐
                            │   PostgreSQL      │
                            │  (Port 5432)      │
                            └───────────────────┘
```

## ✅ Pré-requisitos

### 1. Servidor/VPS
- Linux (Ubuntu 20.04+ recomendado)
- Mínimo 2GB RAM, 2 vCPU
- 20GB de espaço em disco
- Acesso root ou sudo

### 2. Software Instalado
```bash
# Docker
docker --version  # >= 20.10

# Docker Compose
docker compose version  # >= 2.0

# Portainer (opcional, mas recomendado)
# Acesse: http://seu-ip:9000
```

### 3. Portas Abertas no Firewall
```bash
# Portas necessárias
80    # HTTP
443   # HTTPS
9000  # Portainer (opcional)
```

---

## 🌐 Configuração DNS

Configure os seguintes registros DNS no seu provedor (conforme imagem fornecida):

```
Tipo      Nome          Conteúdo                   TTL
──────────────────────────────────────────────────────
A         server        173.249.37.232             Auto
CNAME     agent         server.srcjohann.com.br    Auto
CNAME     api           server.srcjohann.com.br    Auto
CNAME     portainer     server.srcjohann.com.br    Auto
CNAME     sdk           server.srcjohann.com.br    Auto
```

### Verificação DNS
```bash
# Verificar se os domínios estão apontando corretamente
nslookup api.srcjohann.com.br
nslookup sdk.srcjohann.com.br
```

---

## ⚙️ Configuração de Variáveis

### 1. Criar arquivo de variáveis de ambiente

```bash
cd /home/johann/ContaboDocs/sdk-deploy
cp .env.example .env.production
nano .env.production
```

### 2. Configurar variáveis essenciais

#### Opção A: Usar PostgreSQL EXTERNO (já instalado na máquina)

```bash
# .env.production
DB_HOST=host.docker.internal  # ou 172.17.0.1
DB_PORT=5432
DB_NAME=dom360_db_sdk
DB_USER=postgres
DB_PASSWORD=seu_password_aqui
```

#### Opção B: Usar PostgreSQL INTERNO (container Docker)

```bash
# .env.production
DB_HOST=postgres
DB_PORT=5432
DB_NAME=dom360_db_sdk
DB_USER=postgres
DB_PASSWORD=seu_password_aqui
```

### 3. Configurar URLs públicas

```bash
# URLs públicas (após DNS configurado)
PUBLIC_BACKEND_URL=https://api.srcjohann.com.br
PUBLIC_FRONTEND_URL=https://sdk.srcjohann.com.br

# Security
JWT_SECRET=$(openssl rand -base64 32)  # Gere um secret único

# CORS
CORS_ORIGINS=https://sdk.srcjohann.com.br,https://api.srcjohann.com.br
```

---

## 🐳 Deploy no Portainer

### Método 1: Via Interface Web do Portainer (Recomendado)

#### 1. Acessar Portainer
```
http://seu-ip:9000
```

#### 2. Criar Stack
1. Navegue para: **Stacks** → **Add Stack**
2. Nome: `sdk-dom360`
3. Build method: **Git Repository**

#### 3. Configurar Repositório Git
```
Repository URL: https://github.com/srcJohann/sdk.git
Repository reference: refs/heads/main
Compose path: docker-compose.prod.yml
```

#### 4. Configurar Variáveis de Ambiente
Clique em **Environment variables** e adicione:

```
DB_HOST=host.docker.internal
DB_PORT=5432
DB_NAME=dom360_db_sdk
DB_USER=postgres
DB_PASSWORD=seu_password_seguro
PUBLIC_BACKEND_URL=https://api.srcjohann.com.br
PUBLIC_FRONTEND_URL=https://sdk.srcjohann.com.br
JWT_SECRET=seu_secret_gerado
CORS_ORIGINS=https://sdk.srcjohann.com.br,https://api.srcjohann.com.br
AGENT_API_URL=http://seu-agent:8000
```

#### 5. Deploy
- Se usar PostgreSQL EXTERNO: Clique em **Deploy the stack**
- Se usar PostgreSQL INTERNO: 
  - Na seção **Advanced mode**, adicione no campo de texto:
  ```
  --profile with-db
  ```
  - Clique em **Deploy the stack**

### Método 2: Via Terminal

#### Para PostgreSQL EXTERNO:
```bash
cd /home/johann/ContaboDocs/sdk-deploy
docker compose -f docker-compose.prod.yml --env-file .env.production up -d
```

#### Para PostgreSQL INTERNO:
```bash
cd /home/johann/ContaboDocs/sdk-deploy
docker compose -f docker-compose.prod.yml --env-file .env.production --profile with-db up -d
```

---

## 🔒 Configuração SSL (HTTPS)

### Opção 1: Let's Encrypt com Certbot (Recomendado)

```bash
# Instalar Certbot
sudo apt update
sudo apt install certbot

# Parar nginx temporariamente
docker compose -f docker-compose.prod.yml stop nginx

# Gerar certificados
sudo certbot certonly --standalone -d api.srcjohann.com.br
sudo certbot certonly --standalone -d sdk.srcjohann.com.br

# Copiar certificados para o projeto
sudo cp /etc/letsencrypt/live/api.srcjohann.com.br/fullchain.pem \
   /home/johann/ContaboDocs/sdk-deploy/nginx/ssl/api.srcjohann.com.br.crt
sudo cp /etc/letsencrypt/live/api.srcjohann.com.br/privkey.pem \
   /home/johann/ContaboDocs/sdk-deploy/nginx/ssl/api.srcjohann.com.br.key

sudo cp /etc/letsencrypt/live/sdk.srcjohann.com.br/fullchain.pem \
   /home/johann/ContaboDocs/sdk-deploy/nginx/ssl/sdk.srcjohann.com.br.crt
sudo cp /etc/letsencrypt/live/sdk.srcjohann.com.br/privkey.pem \
   /home/johann/ContaboDocs/sdk-deploy/nginx/ssl/sdk.srcjohann.com.br.key

# Ajustar permissões
sudo chmod 644 /home/johann/ContaboDocs/sdk-deploy/nginx/ssl/*.crt
sudo chmod 600 /home/johann/ContaboDocs/sdk-deploy/nginx/ssl/*.key

# Editar configurações Nginx para habilitar SSL
nano nginx/conf.d/api.conf
nano nginx/conf.d/frontend.conf
# Descomente as seções "# HTTPS" em ambos os arquivos

# Reiniciar nginx
docker compose -f docker-compose.prod.yml restart nginx
```

### Renovação Automática
```bash
# Adicionar ao crontab
sudo crontab -e

# Adicione esta linha:
0 0 1 * * certbot renew --quiet && docker compose -f /home/johann/ContaboDocs/sdk-deploy/docker-compose.prod.yml restart nginx
```

---

## ✅ Verificação

### 1. Verificar se os containers estão rodando

```bash
docker compose -f docker-compose.prod.yml ps
```

Saída esperada:
```
NAME            STATUS          PORTS
sdk-backend     Up (healthy)    0.0.0.0:3001->3001/tcp
sdk-frontend    Up (healthy)    0.0.0.0:8080->8080/tcp
sdk-nginx       Up              0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
sdk-postgres    Up (healthy)    0.0.0.0:5432->5432/tcp (se interno)
```

### 2. Testar endpoints

```bash
# Backend health
curl http://api.srcjohann.com.br/api/health
# Resposta esperada: {"status":"healthy","database":"connected","timestamp":"..."}

# Frontend
curl http://sdk.srcjohann.com.br/health
# Resposta esperada: healthy
```

### 3. Verificar logs

```bash
# Logs do backend
docker compose -f docker-compose.prod.yml logs -f backend

# Logs do frontend
docker compose -f docker-compose.prod.yml logs -f frontend

# Logs do nginx
docker compose -f docker-compose.prod.yml logs -f nginx
```

### 4. Testar no navegador

```
http://sdk.srcjohann.com.br       # Frontend
http://api.srcjohann.com.br       # Backend API
```

---

## 🔧 Troubleshooting

### Problema: Backend não conecta no PostgreSQL

**Sintoma:**
```
✗ ERRO: PostgreSQL não respondeu após 30 tentativas
```

**Solução para PostgreSQL EXTERNO:**
```bash
# 1. Verificar se PostgreSQL está rodando
sudo systemctl status postgresql

# 2. Configurar PostgreSQL para aceitar conexões do Docker
sudo nano /etc/postgresql/14/main/postgresql.conf
# Adicione: listen_addresses = '*'

sudo nano /etc/postgresql/14/main/pg_hba.conf
# Adicione: host all all 172.17.0.0/16 md5

# 3. Reiniciar PostgreSQL
sudo systemctl restart postgresql

# 4. Reiniciar backend
docker compose -f docker-compose.prod.yml restart backend
```

### Problema: Erro de permissão no entrypoint.sh

**Sintoma:**
```
permission denied: ./entrypoint.sh
```

**Solução:**
```bash
chmod +x backend/entrypoint.sh
docker compose -f docker-compose.prod.yml up -d --build backend
```

### Problema: Frontend mostra "Failed to fetch"

**Sintoma:**
Frontend não consegue se comunicar com o backend.

**Solução:**
```bash
# 1. Verificar CORS no backend
docker compose -f docker-compose.prod.yml logs backend | grep CORS

# 2. Verificar variável de ambiente do frontend
docker compose -f docker-compose.prod.yml exec frontend env | grep VITE_API_URL

# 3. Rebuild frontend com a variável correta
docker compose -f docker-compose.prod.yml up -d --build frontend
```

### Problema: DNS não resolve

**Sintoma:**
```
curl: (6) Could not resolve host: api.srcjohann.com.br
```

**Solução:**
```bash
# 1. Verificar DNS
nslookup api.srcjohann.com.br

# 2. Aguardar propagação DNS (pode levar até 48h)

# 3. Teste local editando /etc/hosts temporariamente
sudo nano /etc/hosts
# Adicione:
# 173.249.37.232  api.srcjohann.com.br
# 173.249.37.232  sdk.srcjohann.com.br
```

### Problema: Migrations não executam

**Sintoma:**
Tabelas não existem no banco.

**Solução:**
```bash
# 1. Executar migrations manualmente
docker compose -f docker-compose.prod.yml exec backend bash

# Dentro do container:
export PGPASSWORD=$DB_PASSWORD
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f ./database/schema.sql
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f ./database/migrations/001_schema_apply.sql
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f ./database/seeds/001_seed_master.sql
exit

# 2. Reiniciar backend
docker compose -f docker-compose.prod.yml restart backend
```

---

## 📊 Monitoramento

### Via Portainer
1. Acesse Portainer: `http://seu-ip:9000`
2. Navegue para: **Stacks** → **sdk-dom360**
3. Visualize:
   - Status dos containers
   - Logs em tempo real
   - Métricas de CPU/RAM
   - Recreate/Restart containers

### Via Terminal
```bash
# Status
docker compose -f docker-compose.prod.yml ps

# Logs em tempo real
docker compose -f docker-compose.prod.yml logs -f

# Métricas
docker stats

# Restart de um serviço específico
docker compose -f docker-compose.prod.yml restart backend
```

---

## 🔄 Atualização da Aplicação

### Via Portainer
1. **Stacks** → **sdk-dom360**
2. Clique em **Pull and redeploy**
3. Aguarde o rebuild e redeploy automático

### Via Terminal
```bash
cd /home/johann/ContaboDocs/sdk-deploy

# Pull das últimas mudanças
git pull

# Rebuild e redeploy
docker compose -f docker-compose.prod.yml up -d --build
```

---

## 🛑 Parar/Remover Aplicação

```bash
# Parar todos os serviços
docker compose -f docker-compose.prod.yml stop

# Parar e remover containers
docker compose -f docker-compose.prod.yml down

# Remover containers + volumes (CUIDADO: apaga dados do DB)
docker compose -f docker-compose.prod.yml down -v
```

---

## 📞 Suporte

Para problemas ou dúvidas:
- Verifique os logs: `docker compose logs -f [serviço]`
- Verifique o status: `docker compose ps`
- Consulte este README

---

## 📝 Checklist de Deploy

- [ ] DNS configurado (A e CNAME)
- [ ] Variáveis de ambiente configuradas (`.env.production`)
- [ ] PostgreSQL configurado (externo ou interno)
- [ ] Stack criada no Portainer
- [ ] Containers rodando (status: Up e healthy)
- [ ] Backend health check: `http://api.srcjohann.com.br/api/health`
- [ ] Frontend acessível: `http://sdk.srcjohann.com.br`
- [ ] SSL configurado (Let's Encrypt)
- [ ] Logs sem erros críticos
- [ ] Teste de funcionalidade completo

---

**Sucesso! 🎉** Sua aplicação DOM360 SDK está rodando em produção!
