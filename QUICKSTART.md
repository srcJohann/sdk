# 🚀 Deploy Rápido - DOM360 SDK

## Configuração em 5 minutos

### 1️⃣ Configurar variáveis
```bash
./deploy.sh setup
nano .env.production
```

**Importante:** Altere pelo menos:
- `DB_PASSWORD`
- `JWT_SECRET` (gere com: `openssl rand -base64 32`)

### 2️⃣ Iniciar aplicação

**Com PostgreSQL externo (já tem na máquina):**
```bash
./deploy.sh start
```

**Com PostgreSQL interno (Docker):**
```bash
./deploy.sh start-db
```

### 3️⃣ Verificar
```bash
./deploy.sh status
curl http://api.srcjohann.com.br/api/health
```

---

## 📋 Comandos Úteis

```bash
./deploy.sh status          # Ver status
./deploy.sh logs            # Ver logs
./deploy.sh logs-backend    # Ver logs do backend
./deploy.sh restart         # Reiniciar
./deploy.sh stop            # Parar
./deploy.sh rebuild         # Rebuild completo
```

---

## 🌐 DNS Necessário

Configure no seu provedor de DNS:

```
A       server      173.249.37.232
CNAME   api         server.srcjohann.com.br
CNAME   sdk         server.srcjohann.com.br
```

---

## 📖 Documentação Completa

Veja [DEPLOY.md](./DEPLOY.md) para instruções detalhadas.

---

## 🐳 Portainer

**Método 1 - Git (Recomendado):**
1. Acesse Portainer: `http://seu-ip:9000`
2. Stacks → Add Stack
3. Nome: `sdk-dom360`
4. Build method: **Git Repository**
5. URL: `https://github.com/srcJohann/sdk.git`
6. Compose path: `docker-compose.prod.yml`
7. Adicione as variáveis de ambiente
8. Deploy

**Método 2 - Upload:**
1. Faça upload de `docker-compose.prod.yml`
2. Adicione as variáveis de ambiente
3. Deploy

---

## ⚡ Arquitetura

```
Internet
   │
   ├─── api.srcjohann.com.br  → Backend (FastAPI)
   └─── sdk.srcjohann.com.br  → Frontend (React)
           │
           └─── PostgreSQL
```

---

## 🔒 SSL/HTTPS

```bash
# Instalar Certbot
sudo apt install certbot

# Gerar certificados
sudo certbot certonly --standalone -d api.srcjohann.com.br
sudo certbot certonly --standalone -d sdk.srcjohann.com.br

# Copiar para nginx/ssl/
# Ver DEPLOY.md para instruções completas
```

---

## ✅ Checklist

- [ ] DNS configurado
- [ ] `.env.production` criado e configurado
- [ ] PostgreSQL rodando (local ou Docker)
- [ ] Aplicação iniciada: `./deploy.sh start`
- [ ] Backend health OK: `curl http://api.srcjohann.com.br/api/health`
- [ ] Frontend acessível: `http://sdk.srcjohann.com.br`
- [ ] SSL configurado (opcional)

---

**Pronto! 🎉**
