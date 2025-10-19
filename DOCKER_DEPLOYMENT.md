# Docker Deployment Guide - SDK DOM360

## 📋 Visão Geral da Arquitetura

A aplicação foi refatorada para uma arquitetura de containers simplificada:

- **Backend**: FastAPI rodando na porta `3001`
- **Frontend**: React + Vite rodando na porta `5173`
- **PostgreSQL**: Instalado diretamente na VPS (fora do container)
- **Proxy Reverso**: Traefik na VPS (não Nginx)

Cada serviço roda em um container separado dentro do Docker Compose, permitindo escalabilidade independente e melhor isolamento.

---

## 📦 Pré-requisitos

### Na Máquina VPS:

1. **Docker & Docker Compose instalados**
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install -y docker.io docker-compose
   sudo usermod -aG docker $USER
   ```

2. **PostgreSQL 15+ instalado na VPS**
   ```bash
   sudo apt-get install -y postgresql postgresql-contrib
   
   # Verificar se está rodando
   sudo systemctl status postgresql
   ```

3. **Traefik configurado como proxy reverso** (opcional, mas recomendado)
   - Veja a documentação de Traefik para configurar reverse proxy com certificados SSL

---

## 🚀 Deployment

### 1. Clone o Repositório

```bash
git clone https://github.com/srcJohann/sdk-deploy.git
cd sdk-deploy
```

### 2. Configure as Variáveis de Ambiente

Crie um arquivo `.env` na raiz do projeto:

```bash
cp .env.example .env
nano .env
```

**Exemplo de `.env` para VPS:**

```env
# ============================================
# Database (PostgreSQL na VPS)
# ============================================
DB_HOST=localhost              # ou o IP da VPS
DB_PORT=5432
DB_NAME=dom360_db_sdk
DB_USER=postgres
DB_PASSWORD=sua_senha_postgres_aqui

# ============================================
# Backend
# ============================================
BACKEND_PORT=3001
PUBLIC_BACKEND_URL=http://backend:3001
PYTHON_ENV=production

# ============================================
# Frontend
# ============================================
PUBLIC_FRONTEND_URL=http://frontend:5173
VITE_API_URL=http://localhost:3001
NODE_ENV=production

# ============================================
# API & Security
# ============================================
AGENT_API_URL=http://localhost:8000
JWT_SECRET=seu_jwt_secret_bem_seguro

# ============================================
# CORS
# ============================================
CORS_ORIGINS=http://localhost:5173,http://localhost:3001,http://frontend:5173,http://backend:3001

# ============================================
# Traefik (se usar reverse proxy)
# ============================================
TRAEFIK_DOMAIN=seu-dominio.com
```

### 3. Prepare o PostgreSQL na VPS

```bash
# Conectar como usuário postgres
sudo -u postgres psql

# Criar database
CREATE DATABASE dom360_db_sdk WITH ENCODING='UTF8' LC_COLLATE='C' LC_CTYPE='C';

# Criar usuário (se não existir)
CREATE USER seu_usuario WITH PASSWORD 'sua_senha';

# Dar permissões
ALTER ROLE seu_usuario SET client_encoding TO 'utf8';
ALTER ROLE seu_usuario SET default_transaction_isolation TO 'read committed';
ALTER ROLE seu_usuario SET default_transaction_deferrable TO on;
ALTER ROLE seu_usuario SET default_transaction_read_only TO off;
GRANT ALL PRIVILEGES ON DATABASE dom360_db_sdk TO seu_usuario;

# Sair
\q
```

### 4. Execute o Schema e Seeds no PostgreSQL

```bash
# Aplicar schema
psql -h localhost -U seu_usuario -d dom360_db_sdk -f database/schema.sql

# Aplicar seeds
psql -h localhost -U seu_usuario -d dom360_db_sdk -f database/seeds/001_seed_master.sql
```

### 5. Build e Deploy dos Containers

```bash
# Build das imagens
docker compose build

# Iniciar os serviços
docker compose up -d

# Verificar status
docker compose ps

# Ver logs
docker compose logs -f backend   # Backend logs
docker compose logs -f frontend  # Frontend logs
```

---

## 🔧 Variáveis de Ambiente Importantes

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `DB_HOST` | Host do PostgreSQL | `localhost` |
| `DB_PORT` | Porta do PostgreSQL | `5432` |
| `DB_NAME` | Nome do database | `dom360_db_sdk` |
| `DB_USER` | Usuário postgres | `postgres` |
| `DB_PASSWORD` | Senha do postgres | (obrigatório) |
| `BACKEND_PORT` | Porta do backend | `3001` |
| `BACKEND_BIND_HOST` | Host do backend | `0.0.0.0` |
| `PUBLIC_BACKEND_URL` | URL pública do backend | `http://backend:3001` |
| `PUBLIC_FRONTEND_URL` | URL pública do frontend | `http://frontend:5173` |
| `VITE_API_URL` | URL da API para frontend | `http://localhost:3001` |
| `JWT_SECRET` | Secret do JWT | (obrigatório) |
| `CORS_ORIGINS` | Origins permitidos | `http://localhost:5173,...` |

---

## 🌐 Configuração com Traefik

Se usar Traefik como proxy reverso, adicione labels ao `docker-compose.yml`:

```yaml
services:
  backend:
    # ... outras configurações
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.backend.rule=Host(`seu-dominio.com`) && PathPrefix(`/api`)"
      - "traefik.http.services.backend.loadbalancer.server.port=3001"
      - "traefik.http.routers.backend.entrypoints=websecure"
      - "traefik.http.routers.backend.tls.certresolver=letsencrypt"
    networks:
      - traefik-network
      - dom360-network

  frontend:
    # ... outras configurações
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.frontend.rule=Host(`seu-dominio.com`)"
      - "traefik.http.services.frontend.loadbalancer.server.port=5173"
      - "traefik.http.routers.frontend.entrypoints=websecure"
      - "traefik.http.routers.frontend.tls.certresolver=letsencrypt"
    networks:
      - traefik-network
      - dom360-network

networks:
  traefik-network:
    external: true
  dom360-network:
    driver: bridge
```

---

## 📊 Health Checks

Ambos os serviços possuem health checks automáticos:

```bash
# Verificar saúde do backend
curl http://localhost:3001/api/health

# Verificar saúde do frontend
curl http://localhost:5173/
```

---

## 🛑 Parar e Limpar

```bash
# Parar serviços
docker compose down

# Parar e remover volumes
docker compose down -v

# Remover todas as imagens
docker compose down --rmi all
```

---

## 📝 Backup do Database

```bash
# Backup
pg_dump -h localhost -U seu_usuario dom360_db_sdk > backup_$(date +%Y%m%d_%H%M%S).sql

# Restaurar
psql -h localhost -U seu_usuario dom360_db_sdk < seu_backup.sql
```

---

## ✅ Checklist de Deployment

- [ ] PostgreSQL instalado e rodando na VPS
- [ ] Database criado e configurado
- [ ] Schema e seeds aplicados
- [ ] Arquivo `.env` configurado
- [ ] Docker e Docker Compose instalados
- [ ] Imagens buildadas com sucesso
- [ ] Containers iniciados sem erros
- [ ] Backend respondendo em `http://localhost:3001/api/health`
- [ ] Frontend acessível em `http://localhost:5173`
- [ ] Traefik configurado (se usar reverse proxy)
- [ ] Certificados SSL configurados (se usar HTTPS)
- [ ] Firewall permitindo portas necessárias

---

## 🐛 Troubleshooting

### Backend não conecta ao PostgreSQL
```bash
# Verificar se PostgreSQL está rodando
sudo systemctl status postgresql

# Testar conexão
psql -h localhost -U seu_usuario -d dom360_db_sdk -c "SELECT 1;"

# Ver logs do backend
docker compose logs backend
```

### Frontend não carrega
```bash
# Verificar logs
docker compose logs frontend

# Testar acesso direto
curl http://localhost:5173/
```

### Problema com permissões
```bash
# Dar permissões ao diretório
sudo chown -R $(whoami):$(whoami) /home/johann/ContaboDocs/sdk-deploy

# Permissões Docker
sudo usermod -aG docker $USER
newgrp docker
```

### Limpar cache do Docker
```bash
docker compose build --no-cache
docker system prune -a --volumes
```

---

## 📚 Estrutura de Arquivos

```
sdk-deploy/
├── docker-compose.yml       # Orquestração dos containers
├── Dockerfile              # Backend (FastAPI)
├── backend/
│   ├── entrypoint.sh       # Script de inicialização do backend
│   ├── server.py           # Aplicação FastAPI
│   ├── requirements.txt     # Dependências Python
│   ├── auth/               # Middleware de autenticação
│   └── api/                # Rotas da API
├── frontend/
│   └── app/
│       ├── Dockerfile      # Frontend (React + Vite)
│       ├── package.json    # Dependências Node.js
│       ├── vite.config.js  # Configuração Vite
│       └── src/            # Código fonte React
├── database/
│   ├── schema.sql          # Schema do database
│   ├── migrations/         # Migrations SQL
│   └── seeds/              # Dados iniciais
├── logs/                   # Logs da aplicação
└── .env                    # Variáveis de ambiente (não versionar)
```

---

## 🔐 Segurança

1. **Nunca versione o arquivo `.env`** - use `.env.example`
2. **Use senhas fortes** para PostgreSQL
3. **Ative SSL/TLS** via Traefik com Let's Encrypt
4. **Restrinja acesso** às portas do Docker com firewall
5. **Atualize regularmente** as imagens base (node, python)
6. **Revise os logs** regularmente para atividades suspeitas

---

## 📞 Suporte

Para problemas ou dúvidas:
- Verifique os logs: `docker compose logs <serviço>`
- Consulte a documentação: `README.md`
- Abra uma issue no repositório

---

**Última atualização**: 19 de outubro de 2025
**Versão**: 2.0 (Arquitetura simplificada com Traefik)
