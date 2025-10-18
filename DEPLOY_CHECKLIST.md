# 🐳 Checklist de Deploy Docker em VPS

## ✅ Pré-Deploy (Local)

- [ ] Testar build local: `docker-compose build`
- [ ] Testar containers locais: `docker-compose up -d`
- [ ] Verificar banco de dados foi criado e seed aplicado
- [ ] Testar endpoints: `curl http://localhost:3001/api/health`
- [ ] Atualizar `.env.production` com valores corretos
- [ ] Gerar novo JWT_SECRET: `openssl rand -base64 32`
- [ ] Testar CORS_ORIGINS está correto
- [ ] Revisar `docker-compose.yml` para produção
- [ ] Fazer commit de todas as mudanças

## 🚀 Deploy em VPS

### 1. Preparação da VPS

- [ ] SSH para VPS: `ssh root@seu-vps-ip`
- [ ] Atualizar sistema: `apt update && apt upgrade -y`
- [ ] Criar usuário não-root (opcional): `useradd -m -s /bin/bash deploy`
- [ ] Configurar sudoers se necessário

### 2. Instalar Docker

- [ ] Executar: `sudo ./deploy-docker.sh`
  - ✅ Docker instalado
  - ✅ Docker Compose instalado
  - ✅ Sistema preparado
  
OU fazer manualmente:

- [ ] Remover Docker antigo: `sudo apt remove docker* containerd runc`
- [ ] Instalar Docker: [docs.docker.com/install](https://docs.docker.com/install/)
- [ ] Instalar Docker Compose: [github.com/docker/compose/releases](https://github.com/docker/compose/releases)

### 3. Clonar Repositório

```bash
cd /opt
sudo git clone https://github.com/srcJohann/sdk.git dom360
cd dom360
sudo chmod +x deploy-docker.sh docker-dev.sh docker-health.sh
```

### 4. Configurar Ambiente

```bash
# Copiar e editar .env
sudo cp .env.production .env
sudo nano .env

# Valores importantes a alterar:
# - DB_PASSWORD (senha do PostgreSQL)
# - JWT_SECRET (executar: openssl rand -base64 32)
# - PUBLIC_BACKEND_URL (seu domínio)
# - PUBLIC_FRONTEND_URL (seu domínio)
# - CORS_ORIGINS (seus domínios)
# - PGADMIN_PASSWORD (se usar PgAdmin)
```

### 5. Build e Deploy

```bash
# Fazer build
sudo docker-compose build

# Verificar build
sudo docker-compose images

# Iniciar containers
sudo docker-compose up -d

# Verificar status
sudo docker-compose ps
sudo docker-compose logs -f backend
```

### 6. Configurar DNS e Domínio

- [ ] Atualizar DNS em seu registrador:
  - `seu-dominio.com` → `IP-DA-VPS`
  - `api.seu-dominio.com` → `IP-DA-VPS`
- [ ] Aguardar propagação DNS (até 48h)
- [ ] Testar: `nslookup seu-dominio.com`

### 7. Configurar SSL/HTTPS

```bash
# Instalar Certbot
sudo apt install certbot

# Gerar certificados
sudo certbot certonly --standalone \
  -d seu-dominio.com \
  -d api.seu-dominio.com \
  -d www.seu-dominio.com

# Configurados em:
# - /etc/letsencrypt/live/seu-dominio.com/fullchain.pem
# - /etc/letsencrypt/live/seu-dominio.com/privkey.pem
```

### 8. Configurar Nginx (opcional mas recomendado)

```bash
# Copiar e editar nginx.conf
sudo cp nginx.conf /etc/nginx/sites-available/dom360
sudo nano /etc/nginx/sites-available/dom360

# Atualizar certificados SSL no nginx.conf:
# - ssl_certificate /etc/letsencrypt/live/seu-dominio.com/fullchain.pem
# - ssl_certificate_key /etc/letsencrypt/live/seu-dominio.com/privkey.pem

# Habilitar site
sudo ln -s /etc/nginx/sites-available/dom360 /etc/nginx/sites-enabled/

# Remover default se necessário
sudo rm /etc/nginx/sites-enabled/default

# Testar configuração
sudo nginx -t

# Reiniciar Nginx
sudo systemctl restart nginx
```

Alternativamente com Docker:
```bash
# Iniciar Nginx container
sudo docker-compose --profile nginx up -d nginx
```

### 9. Renew automático de SSL

```bash
# Criar script de renovação
sudo cat > /opt/dom360/renew-ssl.sh << 'EOF'
#!/bin/bash
certbot renew --quiet
docker-compose restart nginx || true
EOF

sudo chmod +x /opt/dom360/renew-ssl.sh

# Agendar com cron (verificar certificados todo dia às 3 da manhã)
sudo crontab -e
# Adicionar linha:
# 0 3 * * * /opt/dom360/renew-ssl.sh
```

## ✅ Pós-Deploy (Verificações)

- [ ] Frontend está acessível: `https://seu-dominio.com`
- [ ] Backend está acessível: `https://api.seu-dominio.com`
- [ ] API Health OK: `https://api.seu-dominio.com/api/health`
- [ ] Swagger UI acessível: `https://api.seu-dominio.com/docs`
- [ ] Login funciona
- [ ] Banco de dados criado e seed aplicado
- [ ] SSL/HTTPS funcionando em ambos domínios
- [ ] Redirect HTTP → HTTPS funcionando

## 🔒 Segurança

- [ ] Alterar todas as senhas padrão
- [ ] Remover acesso SSH da porta 22 se possível
- [ ] Configurar firewall: `sudo ufw enable`
- [ ] Liberar apenas portas necessárias:
  - [ ] `22/tcp` (SSH)
  - [ ] `80/tcp` (HTTP)
  - [ ] [ ] `443/tcp` (HTTPS)
- [ ] Fazer backup automático do banco
- [ ] Monitorar logs: `tail -f /var/log/syslog`
- [ ] Configurar alertas de CPU/Memória

## 📊 Monitoramento

```bash
# Status dos containers
docker-compose ps

# Recursos utilizados
docker stats

# Logs em tempo real
docker-compose logs -f

# Health check
docker-compose exec backend curl http://localhost:3001/api/health

# Backup do banco
docker-compose exec postgres pg_dump -U postgres dom360_db_sdk > backup.sql
```

## 🔧 Manutenção Contínua

### Diariamente
- [ ] Verificar status dos containers: `docker-compose ps`
- [ ] Monitorar logs: `tail -f logs/*.log`

### Semanalmente
- [ ] Atualizar sistema: `sudo apt update && sudo apt upgrade`
- [ ] Fazer backup do banco de dados

### Mensalmente
- [ ] Revisar logs de segurança
- [ ] Atualizar dependências
- [ ] Testar restore de backup

### Anualmente
- [ ] Planejar atualizações
- [ ] Revisar configurações de segurança
- [ ] Atualizar certificados SSL se manualmente gerenciados

## 🚨 Troubleshooting Rápido

| Problema | Solução |
|----------|---------|
| Container não inicia | `docker-compose logs SERVICE` |
| Porta já em uso | `sudo lsof -i :PORTA` |
| Banco não conecta | Verificar `DB_HOST=postgres` no `.env` |
| Sem espaço em disco | `docker system prune -a` |
| Memória alta | `docker stats` e aumentar recursos |
| SSL não funciona | Verificar caminho dos certificados em nginx.conf |

## 📞 Contatos Úteis

- Docker Docs: https://docs.docker.com/
- Let's Encrypt: https://letsencrypt.org/
- FastAPI: https://fastapi.tiangolo.com/
- PostgreSQL: https://www.postgresql.org/

---

**Criado em**: Outubro 2024
**Versão**: 1.0
