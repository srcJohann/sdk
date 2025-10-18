# Guia de Deploy VPS - DOM360 SDK

## 📋 Pré-requisitos

- VPS com Ubuntu 20.04+ ou Debian 11+
- Acesso root via SSH
- IP público configurado
- (Opcional) Domínio configurado apontando para o IP da VPS

## 🚀 Deploy Automatizado

### Opção 1: Script Completo (Recomendado)

Execute o script de deploy automatizado que aplica todas as correções:

```bash
# 1. Acesse o servidor VPS via SSH
ssh root@SEU_IP_VPS

# 2. Clone o repositório (se ainda não estiver no servidor)
git clone <seu-repositorio> /opt/dom360
cd /opt/dom360

# 3. Configure o arquivo .env com suas URLs
nano .env

# IMPORTANTE: Altere estas linhas:
# VITE_API_URL=http://api.seudominio.com  (ou http://SEU_IP_VPS:3001)
# PUBLIC_BACKEND_HOST=api.seudominio.com  (ou SEU_IP_VPS)
# PUBLIC_FRONTEND_HOST=seudominio.com     (ou SEU_IP_VPS)

# 4. Execute o script de deploy
sudo bash deploy_vps.sh
```

O script irá:
- ✅ Validar configurações do .env
- ✅ Instalar todas as dependências
- ✅ Configurar PostgreSQL
- ✅ Gerar build de produção do frontend
- ✅ Configurar Nginx com envsubst
- ✅ Configurar firewall (UFW)
- ✅ Criar serviços systemd
- ✅ (Opcional) Configurar SSL com Let's Encrypt

## 🔧 Deploy Manual (Passo a Passo)

Se preferir fazer o deploy manualmente, siga estes passos:

### Passo 1: Configurar .env

```bash
cd /opt/dom360
nano .env
```

**Alterações CRÍTICAS necessárias:**

```bash
# ❌ ERRADO (aponta para localhost)
VITE_API_URL=http://127.0.0.1:3001

# ✅ CORRETO (use domínio ou IP público)
VITE_API_URL=http://api.seudominio.com
# OU sem domínio:
VITE_API_URL=http://203.0.113.10:3001

# Adicionar hosts públicos
PUBLIC_BACKEND_HOST=api.seudominio.com
PUBLIC_FRONTEND_HOST=seudominio.com

# Adicionar JWT_SECRET (CRÍTICO para segurança!)
JWT_SECRET="$(openssl rand -base64 32)"

# Envolver senhas com quotes
DB_PASSWORD="sua_senha_aqui"
```

### Passo 2: Instalar Dependências

```bash
# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar pacotes necessários
sudo apt install -y \
    nginx \
    postgresql \
    postgresql-contrib \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    certbot \
    python3-certbot-nginx \
    gettext-base \
    ufw
```

### Passo 3: Configurar PostgreSQL

```bash
# Criar database e usuário
sudo -u postgres psql << EOF
CREATE USER dom360_user WITH PASSWORD 'sua_senha';
CREATE DATABASE dom360_db_sdk OWNER dom360_user;
\q
EOF

# Aplicar schema
sudo -u postgres psql -d dom360_db_sdk -f /opt/dom360/database/schema.sql

# Aplicar seeds (se necessário)
sudo -u postgres psql -d dom360_db_sdk -f /opt/dom360/database/seeds/001_seed_master.sql
```

### Passo 4: Instalar Dependências da Aplicação

```bash
# Backend Python
cd /opt/dom360
python3 -m venv venv
source venv/bin/activate
pip install -r backend/requirements.txt
deactivate

# Frontend Node.js
cd /opt/dom360/frontend/app
npm install
```

### Passo 5: Build Frontend para Produção

```bash
cd /opt/dom360/frontend/app

# IMPORTANTE: As variáveis VITE_* do .env serão incluídas no build
source ../../.env
npm run build

# Verificar se dist/ foi criado
ls -lah dist/
```

### Passo 6: Configurar Nginx

```bash
cd /opt/dom360

# Executar script que expande variáveis do .env
sudo bash setup_nginx.sh

# Verificar configuração
sudo nginx -t

# Reiniciar nginx
sudo systemctl restart nginx
sudo systemctl enable nginx
```

### Passo 7: Configurar Firewall

```bash
# Permitir portas necessárias
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS

# Ativar firewall
sudo ufw enable

# Verificar status
sudo ufw status
```

### Passo 8: Criar Serviço Systemd para Backend

```bash
sudo nano /etc/systemd/system/dom360-backend.service
```

Conteúdo:

```ini
[Unit]
Description=DOM360 Backend API (FastAPI)
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/dom360
Environment="PATH=/opt/dom360/venv/bin"
ExecStart=/opt/dom360/venv/bin/python /opt/dom360/backend/server_rbac.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Ativar serviço:

```bash
sudo systemctl daemon-reload
sudo systemctl enable dom360-backend.service
sudo systemctl start dom360-backend.service

# Verificar status
sudo systemctl status dom360-backend.service
```

### Passo 9: Configurar SSL (Let's Encrypt)

⚠️ **IMPORTANTE:** DNS deve estar configurado antes!

```bash
# Certificado SSL automático
sudo certbot --nginx \
    -d seudominio.com \
    -d api.seudominio.com \
    --non-interactive \
    --agree-tos \
    --email seuemail@exemplo.com
```

### Passo 10: Testar Deploy

```bash
# Testar backend
curl http://localhost:3001/api/health

# Testar via nginx
curl http://api.seudominio.com/api/health

# Testar frontend
curl http://seudominio.com
```

## 🔍 Verificação e Troubleshooting

### Verificar Logs

```bash
# Backend logs
sudo journalctl -u dom360-backend.service -f

# Nginx logs
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/api_srcjohann_access.log

# PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-*.log
```

### Verificar Portas

```bash
# Verificar quais portas estão escutando
sudo netstat -tlnp | grep -E ':(80|443|3001|5432)'
```

### Verificar Processos

```bash
# Backend
ps aux | grep python

# Nginx
ps aux | grep nginx

# PostgreSQL
ps aux | grep postgres
```

### Reiniciar Serviços

```bash
# Backend
sudo systemctl restart dom360-backend.service

# Nginx
sudo systemctl restart nginx

# PostgreSQL
sudo systemctl restart postgresql
```

## 🐛 Problemas Comuns e Soluções

### Problema 1: Frontend não conecta ao backend

**Sintoma:** ERR_CONNECTION_REFUSED no navegador

**Causa:** VITE_API_URL ainda aponta para localhost/127.0.0.1

**Solução:**
```bash
# 1. Editar .env
nano /opt/dom360/.env
# Alterar: VITE_API_URL=http://api.seudominio.com

# 2. Rebuild frontend
cd /opt/dom360/frontend/app
source ../../.env
npm run build

# 3. Reiniciar nginx
sudo systemctl restart nginx
```

### Problema 2: CORS error

**Sintoma:** Erro CORS no console do navegador

**Causa:** Backend não está aceitando requisições do domínio frontend

**Solução:**
```bash
# Adicionar domínio ao CORS no .env
echo 'CORS_ORIGINS=http://seudominio.com,https://seudominio.com' >> /opt/dom360/.env

# Reiniciar backend
sudo systemctl restart dom360-backend.service
```

### Problema 3: Nginx mostra 502 Bad Gateway

**Sintoma:** Nginx retorna 502 ao acessar

**Causa:** Backend não está rodando

**Solução:**
```bash
# Verificar status do backend
sudo systemctl status dom360-backend.service

# Ver logs
sudo journalctl -u dom360-backend.service -n 50

# Reiniciar
sudo systemctl restart dom360-backend.service
```

### Problema 4: SSL não funciona

**Sintoma:** Certificado inválido ou erro SSL

**Causa:** DNS não está configurado ou Let's Encrypt falhou

**Solução:**
```bash
# Verificar DNS
nslookup seudominio.com
nslookup api.seudominio.com

# Renovar certificado
sudo certbot renew --dry-run

# Forçar novo certificado
sudo certbot --nginx -d seudominio.com -d api.seudominio.com --force-renewal
```

### Problema 5: JWT_SECRET padrão

**Sintoma:** Tokens não funcionam ou erro de autenticação

**Causa:** JWT_SECRET não foi definido no .env

**Solução:**
```bash
# Gerar novo secret
JWT_SECRET=$(openssl rand -base64 32)

# Adicionar ao .env
echo "JWT_SECRET=\"$JWT_SECRET\"" >> /opt/dom360/.env

# Reiniciar backend
sudo systemctl restart dom360-backend.service
```

## 📊 Checklist Pós-Deploy

- [ ] Backend responde em `http://api.seudominio.com/api/health`
- [ ] Frontend carrega em `http://seudominio.com`
- [ ] Login funciona (JWT válido)
- [ ] Chat envia mensagens e recebe respostas
- [ ] CORS não gera erros no console
- [ ] SSL está configurado (HTTPS)
- [ ] Firewall está ativo e configurado
- [ ] Logs estão sendo gerados corretamente
- [ ] Serviço backend inicia automaticamente no boot
- [ ] Nginx inicia automaticamente no boot

## 🔐 Segurança Pós-Deploy

```bash
# 1. Alterar senha do PostgreSQL
sudo -u postgres psql
ALTER USER dom360_user WITH PASSWORD 'nova_senha_forte';
\q

# 2. Configurar fail2ban (proteção contra brute force)
sudo apt install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# 3. Desabilitar login root via SSH (após configurar outro usuário)
sudo nano /etc/ssh/sshd_config
# Alterar: PermitRootLogin no
sudo systemctl restart sshd

# 4. Configurar backup automático do banco
# (adicionar script de backup no crontab)
```

## 📚 Recursos Adicionais

- [Documentação PostgreSQL](https://www.postgresql.org/docs/)
- [Documentação Nginx](https://nginx.org/en/docs/)
- [Let's Encrypt - Certbot](https://certbot.eff.org/)
- [FastAPI Deployment](https://fastapi.tiangolo.com/deployment/)
- [Vite Build Production](https://vitejs.dev/guide/build.html)

## 🆘 Suporte

Se encontrar problemas não listados aqui:

1. Verifique os logs (backend, nginx, postgresql)
2. Consulte o documento `Claude_Haiku4.5_observations.md`
3. Revise as configurações do `.env`
4. Teste endpoints individualmente com `curl`

---

**Última atualização:** 18 de outubro de 2025  
**Versão:** 2.0.0
