# 🚀 Quick Start - Docker Deploy

## ⚡ Início Rápido

### Desenvolvimento Local com Docker

```bash
# 1. Tornar scripts executáveis
chmod +x docker-dev.sh deploy-docker.sh

# 2. Iniciar ambiente de desenvolvimento
./docker-dev.sh up

# 3. Acessar:
# - Frontend:  http://localhost:5173
# - Backend:   http://localhost:3001
# - API Docs:  http://localhost:3001/docs
# - PgAdmin:   http://localhost:5050
```

### Deploy em VPS

```bash
# 1. Na sua máquina local, você pode enviar os arquivos:
# Ou no VPS:
git clone https://github.com/srcJohann/sdk.git
cd sdk

# 2. Tornar script executável
chmod +x deploy-docker.sh

# 3. Executar deploy (requer sudo)
sudo ./deploy-docker.sh
```

## 📁 Arquivos Docker Criados

| Arquivo | Descrição |
|---------|-----------|
| `Dockerfile` | Build da aplicação (Frontend + Backend) |
| `docker-compose.yml` | Orquestração para produção |
| `docker-compose.dev.yml` | Orquestração para desenvolvimento |
| `docker-entrypoint.sh` | Script de inicialização |
| `docker-dev.sh` | Utilitário para desenvolvimento |
| `deploy-docker.sh` | Script de deploy em VPS |
| `.env.production` | Template de variáveis para produção |
| `.dockerignore` | Arquivos ignorados no build |
| `DOCKER_GUIDE.md` | Documentação completa |

## 🎯 Comandos Úteis

### Desenvolvimento

```bash
# Iniciar tudo
./docker-dev.sh up

# Ver logs em tempo real
./docker-dev.sh logs

# Acessar shell do backend
./docker-dev.sh shell

# Acessar PostgreSQL
./docker-dev.sh db

# Fazer backup
./docker-dev.sh backup

# Limpar tudo
./docker-dev.sh clean

# Parar containers
./docker-dev.sh down
```

### Docker Compose Direto

```bash
# Build
docker-compose -f docker-compose.dev.yml build

# Iniciar
docker-compose -f docker-compose.dev.yml up -d

# Logs
docker-compose -f docker-compose.dev.yml logs -f

# Parar
docker-compose -f docker-compose.dev.yml down
```

## 🔐 Segurança em Produção

1. **Mude todas as senhas** em `.env.production`
2. **Configure SSL/HTTPS** com Let's Encrypt
3. **Use nomes seguros** para usuário/admin
4. **Configure CORS corretamente** com seu domínio
5. **Ative backups automáticos** do banco de dados

## 📊 Estrutura de Serviços

```
┌─────────────────────┐
│   Nginx (80/443)    │ ← Frontend + Reverse Proxy
├─────────────────────┤
│  FastAPI (3001)     │ ← Backend API
├─────────────────────┤
│ PostgreSQL (5432)   │ ← Banco de dados
└─────────────────────┘
```

## 🔗 Links Úteis

- [Documentação Completa](DOCKER_GUIDE.md)
- [Docker Docs](https://docs.docker.com/)
- [Docker Compose Docs](https://docs.docker.com/compose/)
- [FastAPI Deployment](https://fastapi.tiangolo.com/deployment/)

## 🆘 Problemas Comuns

### Porta em uso
```bash
sudo lsof -i :3001  # Ver qual processo usa
docker-compose down -v  # Limpar tudo
```

### Banco não inicia
```bash
docker-compose -f docker-compose.dev.yml logs postgres
# Remova volumes antigos se necessário
docker volume rm dom360_postgres_data_dev
```

### Backend não conecta ao banco
Verifique se `DB_HOST=postgres` no `.env` (nome do serviço Docker)

---

📚 Para mais detalhes, veja: [DOCKER_GUIDE.md](DOCKER_GUIDE.md)
