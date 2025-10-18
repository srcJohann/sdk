# Guia Completo de Deploy na VPS (IPv4) - DOM360 SDK

Este guia descreve, passo a passo, como colocar em produção o projeto DOM360 no seu servidor VPS com IPv4. Cobre desde configuração do sistema, banco de dados, execução do backend e frontend, Nginx como reverse-proxy, SSL com Let's Encrypt, e configuração de DNS para apontar seu domínio.

Aviso: execute os comandos como um usuário com privilégios (sudo) sempre que necessário.

---

## Sumário

1. Requisitos mínimos
2. Preparação do servidor
3. Clonar o repositório
4. Configurar variáveis de ambiente
5. Instalar dependências Python e Node
6. Banco de dados PostgreSQL
7. Gerar e aplicar schema (opcional)
8. Configurar e testar backend (FastAPI)
9. Configurar e testar frontend (Vite)
10. Configurar Nginx como reverse proxy
11. Configurar SSL com Let's Encrypt (Certbot)
12. Gerenciar processos com PM2 (opcional)
13. Configurar Firewall (UFW)
14. Testes e verificação
15. Configurar registros DNS (A/CNAME)

---

## 1. Requisitos mínimos

- Sistema: Ubuntu 20.04+ ou Debian
- Acesso root/sudo
- IPv4 público configurado
- 2 CPU / 2GB RAM mínimo recomendado

## 2. Preparação do servidor

Atualize e instale utilitários:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget build-essential
```

Instale Python, Node e PostgreSQL:

```bash
sudo apt install -y python3 python3-venv python3-pip nodejs npm postgresql postgresql-contrib nginx
```

Instale `envsubst` (vem com gettext):

```bash
sudo apt install -y gettext
```

Instale `pm2` (opcional para processos Node/Python em produção):

```bash
sudo npm install -g pm2
```

---

## 3. Clonar o repositório

```bash
cd /opt
sudo git clone https://github.com/srcJohann/sdk.git dom360
sudo chown -R $USER:$USER dom360
cd dom360
```

---

## 4. Configurar variáveis de ambiente

O projeto centraliza host/port/URLs no arquivo `.env` (na raiz). Abra e edite conforme seu ambiente:

```ini
# Exemplo .env (valores para produção)
DB_HOST=localhost
DB_PORT=5432
DB_NAME=dom360_db
DB_USER=dom360_user
DB_PASSWORD=strongpassword

# Backend
BACKEND_PORT=3001
BACKEND_BIND_HOST=0.0.0.0
BACKEND_BIND_PORT=3001
INTERNAL_BACKEND_HOST=localhost
INTERNAL_BACKEND_PORT=3001
PUBLIC_BACKEND_URL=http://api.seudominio.com
PUBLIC_BACKEND_HOST=api.seudominio.com

# Frontend
VITE_API_URL=http://api.seudominio.com
FRONTEND_BIND_HOST=0.0.0.0
FRONTEND_BIND_PORT=5173
INTERNAL_FRONTEND_HOST=localhost
INTERNAL_FRONTEND_PORT=5173
PUBLIC_FRONTEND_URL=http://seudominio.com
PUBLIC_FRONTEND_HOST=seudominio.com

# Environment
NODE_ENV=production
PYTHON_ENV=production
```

Salve o arquivo e (opcional) crie `frontend/app/.env` com `VITE_API_URL` apontando para `PUBLIC_BACKEND_URL` para garantir que o bundle cliente use a URL correta.

---

## 5. Instalar dependências Python e Node

Crie e ative um virtualenv e instale dependências do backend:

```bash
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install -r backend/requirements.txt || true
```

Instale dependências do frontend:

```bash
cd frontend/app
npm install --production
cd ../..
```

> Nota: Para desenvolvimento, remova `--production` para instalar devDependencies.

---

## 6. Banco de dados PostgreSQL

Crie usuário e banco:

```bash
sudo -u postgres psql -c "CREATE USER dom360_user WITH PASSWORD 'strongpassword';"
sudo -u postgres psql -c "CREATE DATABASE dom360_db OWNER dom360_user;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE dom360_db TO dom360_user;"
```

Configure `.env` com as credenciais.

---

## 7. Gerar e aplicar schema (opcional)

Se você já tem o arquivo `database/schema.sql` no repo, aplique-o:

```bash
PGPASSWORD=strongpassword psql -U dom360_user -h localhost -d dom360_db -f database/schema.sql
```

Se precisar extrair o schema do banco existente, use `export_schema.py`:

```bash
source venv/bin/activate
python export_schema.py
# Isso gerará database/schema.sql
```

---

## 8. Configurar e testar backend (FastAPI)

Para rodar em background (dev):

```bash
source venv/bin/activate
python backend/server_rbac.py &> logs/backend.log &
```

Ou com uvicorn diretamente (production estilo):

```bash
source venv/bin/activate
uvicorn backend.server:app --host 0.0.0.0 --port 3001 --workers 1 --log-level info
```

No projeto o `backend/server.py` já lê `BACKEND_BIND_HOST` e `BACKEND_BIND_PORT`.

Teste saúde:

```bash
curl -v http://localhost:3001/api/health
```

---

## 9. Configurar e testar frontend (Vite)

Para desenvolvimento (hot-reload):

```bash
cd frontend/app
npm run dev
# ou
npm run dev -- --host 0.0.0.0 --port 5173
```

Para produção, build e servir os arquivos estáticos via Nginx:

```bash
cd frontend/app
npm run build
# saída em frontend/app/dist
```

A configuração atual do Nginx espera uma aplicação de dev server em 5173 (se quiser servir build estático, altere nginx.conf para usar root /path/to/dist and try_files).

---

## 10. Configurar Nginx como reverse proxy

O repositório contém `nginx.conf` (modelo) e `setup_nginx.sh` para gerar a configuração com as variáveis do `.env`.

Execute (como root):

```bash
sudo ./setup_nginx.sh
```

Isto irá:
- Substituir placeholders no template `nginx.conf` com variáveis do `.env`
- Copiar para `/etc/nginx/sites-available/dom360`
- Habilitar o site e reiniciar nginx
- Adicionar entradas no `/etc/hosts` (apenas localmente)

Verifique se Nginx está funcionando:

```bash
sudo nginx -t
sudo systemctl status nginx
curl -v http://localhost
```

---

## 11. Configurar SSL com Let's Encrypt (Certbot)

Instale o Certbot e o plugin Nginx:

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d seudominio.com -d api.seudominio.com
```

Siga as instruções para obter e instalar os certificados. Certbot atualizará a configuração do Nginx e cuidará de renovação automática.

---

## 12. Gerenciar processos com PM2 (opcional)

Você pode usar PM2 para manter processos Python e Node ativos. Para rodar o script `start.sh` com PM2:

```bash
pm2 start ./start.sh --name dom360
pm2 save
pm2 startup
```

Ou iniciar o backend com um wrapper Python:

```bash
pm2 start --interpreter python3 backend/server.py --name dom360-backend
```

---

## 13. Configurar Firewall (UFW)

Abra portas necessárias:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
# Se precisar acessar diretamente (não recomendado):
sudo ufw allow 3001/tcp
sudo ufw allow 5173/tcp
sudo ufw enable
sudo ufw status
```

---

## 14. Testes e verificação

- Acesse o frontend: `http://seudominio.com` ou `http://SEU_IPV4:5173`
- Verifique a API: `http://api.seudominio.com/api/health` ou `http://SEU_IPV4:3001/api/health`
- Ver logs:
  - `tail -f logs/backend.log`
  - `tail -f /var/log/nginx/seudominio_access.log`

---

## 15. Configurar registros DNS (A/CNAME)

No painel do seu provedor de DNS, você precisará criar os seguintes registros:

1. Registro A para o domínio principal (ex.: `seudominio.com`):
   - Tipo: A
   - Host: @
   - Valor: seu IPv4 (ex.: 203.0.113.10)
   - TTL: 300 (ou automático)

2. Registro A para o subdomínio da API (ex.: `api.seudominio.com`):
   - Tipo: A
   - Host: api
   - Valor: seu IPv4
   - TTL: 300

3. Se você usa `www`:
   - Tipo: CNAME
   - Host: www
   - Valor: seudominio.com

Aguarde a propagação (pode levar de alguns minutos a 24 horas). Para verificar:

```bash
# verificar apontamento
dig +short seudominio.com
dig +short api.seudominio.com
# checar HTTPS
curl -v https://seudominio.com
```

### Observações sobre DNS e SSL
- Para o Certbot emitir um certificado válido, os registros DNS devem apontar para o IPv4 do seu VPS.
- Caso utilize um serviço de proxy (Cloudflare) ative o modo 'Full' ou 'Full (strict)' após configurar SSL no servidor.

---

## Anexos úteis
- Arquivos relevantes no repo:
  - `start.sh` - script de inicialização
  - `setup_nginx.sh` - gera config do nginx e reinicia
  - `nginx.conf` - modelo do Nginx com placeholders
  - `export_schema.py` - gera `database/schema.sql` a partir de um banco existente

---

Se quiser, eu escrevo um pequeno script Ansible ou um `Makefile` para automatizar todo esse processo. Quer que eu gere isso agora?
