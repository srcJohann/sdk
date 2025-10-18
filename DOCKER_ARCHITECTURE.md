# 🐳 DOM360 - Dockerização Completa

## 📦 Arquivos Criados

Uma solução Docker completa foi criada para facilitar o deploy da aplicação. Aqui estão os arquivos adicionados:

### 🔧 Arquivos de Configuração

| Arquivo | Descrição |
|---------|-----------|
| **`Dockerfile`** | Build multi-estágio: frontend (Node) + backend (Python) |
| **`docker-compose.yml`** | Orquestração para produção (PostgreSQL + Backend + Nginx opcional) |
| **`docker-compose.dev.yml`** | Orquestração para desenvolvimento com hot-reload |
| **`.dockerignore`** | Arquivos ignorados no build Docker |
| **`.env.production`** | Template de variáveis para produção |

### 🚀 Scripts de Utilidade

| Script | Descrição |
|--------|-----------|
| **`docker-dev.sh`** | Gerenciador de containers para desenvolvimento |
| **`deploy-docker.sh`** | Script automático de deploy em VPS (instala Docker, deploy) |
| **`docker-entrypoint.sh`** | Script de inicialização (cria BD, aplica schema e seeds) |
| **`docker-health.sh`** | Diagnóstico e health check dos containers |
| **`db-backup.sh`** | Backup e restore do PostgreSQL |
| **`make-executable.sh`** | Torna todos os scripts executáveis |

### 📚 Documentação

| Arquivo | Descrição |
|---------|-----------|
| **`DOCKER_GUIDE.md`** | Guia completo (60+ páginas de documentação) |
| **`DOCKER_QUICKSTART.md`** | Quick start rápido (5 min para começar) |
| **`DEPLOY_CHECKLIST.md`** | Checklist de deploy passo a passo |
| **`DOCKER_ARCHITECTURE.md`** | Arquitetura de containers (este arquivo) |

## 🎯 Características Principais

✅ **Build Multi-Estágio**
- Frontend React (Node.js) → Vite build
- Backend FastAPI (Python) → Uvicorn
- Otimizado para produção (apenas runtime)

✅ **Banco de Dados Automático**
- PostgreSQL cria automaticamente
- Schema aplicado via `docker-entrypoint-initdb.d`
- Seed master user aplicado automaticamente

✅ **Gerenciamento Completo**
- Docker Compose para orquestração
- Health checks configurados
- Volumes persistentes para dados
- Network isolada

✅ **Scripts Facilitadores**
- `docker-dev.sh`: 8 comandos úteis
- `deploy-docker.sh`: Deploy totalmente automático
- `db-backup.sh`: Backup e restore fácil
- `docker-health.sh`: Diagnóstico dos containers

✅ **Pronto para Produção**
- SSL/TLS com Let's Encrypt
- Nginx reverse proxy (opcional)
- Backup automático
- Monitoramento e health checks
- CORS configurável

## ⚡ Quick Start (5 minutos)

### Local (Desenvolvimento)

```bash
# 1. Tornar scripts executáveis
chmod +x docker-dev.sh make-executable.sh
./make-executable.sh

# 2. Iniciar
./docker-dev.sh up

# 3. Acessar
# Frontend:  http://localhost:5173
# Backend:   http://localhost:3001
# API Docs:  http://localhost:3001/docs
# PgAdmin:   http://localhost:5050
```

### VPS (Produção)

```bash
# 1. Na VPS (como root ou com sudo)
chmod +x deploy-docker.sh
sudo ./deploy-docker.sh

# Script vai:
# ✓ Instalar Docker
# ✓ Instalar Docker Compose
# ✓ Configurar .env
# ✓ Build da aplicação
# ✓ Iniciar containers
# ✓ Verificar tudo

# 2. Configurar DNS e SSL (veja DEPLOY_CHECKLIST.md)
```

## 📊 Arquitetura de Containers

```
┌────────────────────────────────────────────┐
│         Docker Network: dom360-network     │
├────────────────────────────────────────────┤
│                                            │
│  ┌──────────────────┐                     │
│  │   Nginx (80/443) │◄──── Cliente        │
│  │  Reverse Proxy   │                     │
│  └────────┬─────────┘                     │
│           │                               │
│  ┌────────▼──────────┐                    │
│  │  FastAPI (3001)   │                    │
│  │  Backend API      │                    │
│  │  ├─ auth/         │                    │
│  │  ├─ api/          │                    │
│  │  └─ frontend/dist │                    │
│  └────────┬──────────┘                    │
│           │                               │
│  ┌────────▼──────────┐                    │
│  │ PostgreSQL (5432) │                    │
│  │ Database          │                    │
│  │ Volumes: pgdata   │                    │
│  └────────┬──────────┘                    │
│           │                               │
│  ┌────────▼──────────┐ (opcional)         │
│  │ PgAdmin (5050)    │                    │
│  │ Web UI para DB    │                    │
│  └───────────────────┘                    │
│                                            │
└────────────────────────────────────────────┘
```

## 🔐 Fluxo de Inicialização

```
┌─────────────────────────────────┐
│  docker-compose up -d            │
└──────────────┬──────────────────┘
               │
       ┌───────▼────────┐
       │  PostgreSQL    │
       │  inicia        │
       └───────┬────────┘
               │
       ┌───────▼──────────────────────┐
       │ docker-entrypoint-initdb.d/  │
       │ ├─ 01-schema.sql             │
       │ └─ 02-seed.sql               │
       └───────┬──────────────────────┘
               │
       ┌───────▼────────────────────────┐
       │ docker-entrypoint.sh            │
       │ Aguarda DB ficar pronto         │
       │ Valida schema e seeds           │
       └───────┬──────────────────────────┘
               │
       ┌───────▼────────┐
       │  Backend       │
       │  FastAPI       │
       │  inicia        │
       └───────┬────────┘
               │
       ┌───────▼────────┐
       │  Pronto!       │
       │  (health: OK)  │
       └────────────────┘
```

## 🛠️ Comandos Principais

### Desenvolvimento

```bash
# Iniciar tudo
./docker-dev.sh up

# Ver logs em tempo real
./docker-dev.sh logs backend

# Acessar shell do backend
./docker-dev.sh shell

# Acessar PostgreSQL
./docker-dev.sh db

# Fazer backup
./docker-dev.sh backup

# Parar tudo
./docker-dev.sh down

# Limpar completamente (remove volumes!)
./docker-dev.sh clean
```

### Docker Compose Direto

```bash
# Build
docker-compose -f docker-compose.dev.yml build

# Iniciar
docker-compose -f docker-compose.dev.yml up -d

# Logs
docker-compose -f docker-compose.dev.yml logs -f

# Status
docker-compose -f docker-compose.dev.yml ps

# Parar
docker-compose -f docker-compose.dev.yml down
```

### Banco de Dados

```bash
# Criar backup
./db-backup.sh create

# Listar backups
./db-backup.sh list

# Restaurar backup
./db-backup.sh restore ./backups/backup_*.sql.gz

# Exportar schema
./db-backup.sh schema

# Agendar backup automático (cron)
./db-backup.sh schedule
```

### Diagnóstico

```bash
# Health check completo
./docker-health.sh

# Ver containers rodando
docker-compose ps

# Ver uso de recursos
docker stats

# Ver logs
docker-compose logs -f

# Conectar ao backend
docker-compose exec backend bash

# Conectar ao PostgreSQL
docker-compose exec postgres psql -U postgres -d dom360_db_sdk
```

## 📋 Variáveis de Ambiente Importantes

### Banco de Dados
```env
DB_HOST=postgres              # Nome do serviço Docker
DB_PORT=5432
DB_NAME=dom360_db_sdk
DB_USER=postgres
DB_PASSWORD=sua_senha_forte   # MUDE ISSO!
```

### Backend
```env
BACKEND_PORT=3001
PUBLIC_BACKEND_URL=http://api.seu-dominio.com
BACKEND_BIND_HOST=0.0.0.0
JWT_SECRET=seu_secret_aqui    # Gere com: openssl rand -base64 32
```

### Frontend
```env
PUBLIC_FRONTEND_URL=http://seu-dominio.com
VITE_API_URL=http://api.seu-dominio.com
```

### CORS
```env
CORS_ORIGINS=http://seu-dominio.com,http://api.seu-dominio.com,https://seu-dominio.com
```

## ✅ Checklist de Deploy

- [ ] Clonar repositório
- [ ] `chmod +x *.sh` (tornar scripts executáveis)
- [ ] Editar `.env` com valores de produção
- [ ] Testar localmente: `./docker-dev.sh up`
- [ ] Verificar banco: `./docker-dev.sh db`
- [ ] Gerar novo JWT_SECRET: `openssl rand -base64 32`
- [ ] Configurar domínio no `.env`
- [ ] Fazer deploy: `sudo ./deploy-docker.sh` OU `docker-compose up -d`
- [ ] Configurar DNS
- [ ] Configurar SSL/HTTPS com Let's Encrypt
- [ ] Verificar endpoints: `curl https://api.seu-dominio.com/api/health`
- [ ] Agendar backups: `./db-backup.sh schedule`

## 🐛 Troubleshooting

| Problema | Solução |
|----------|---------|
| `docker: command not found` | Instalar Docker: `sudo ./deploy-docker.sh` ou manualmente |
| Porta em uso | `sudo lsof -i :PORTA` e mudar porta no `.env` |
| PostgreSQL não conecta | Verificar `DB_HOST=postgres` (nome do serviço) |
| Sem espaço em disco | `docker system prune -a` (remove containers inutilizados) |
| Backend não responde | `./docker-health.sh` para diagnóstico |
| Banco não foi criado | Verificar `docker-compose logs postgres` |

## 📚 Referências

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [FastAPI Deployment](https://fastapi.tiangolo.com/deployment/)
- [PostgreSQL Docker Image](https://hub.docker.com/_/postgres)

## 📞 Próximos Passos

1. **Leia**: [DOCKER_QUICKSTART.md](DOCKER_QUICKSTART.md) (5 min)
2. **Teste localmente**: `./docker-dev.sh up`
3. **Estude**: [DOCKER_GUIDE.md](DOCKER_GUIDE.md) (completo)
4. **Deploy**: Siga [DEPLOY_CHECKLIST.md](DEPLOY_CHECKLIST.md)

---

**Criado em**: Outubro 2024
**Versão**: 1.0
**Mantido por**: João Johann
