# 🚀 DEPLOY RÁPIDO - DOM360 em Produção
**Data**: 18 de outubro de 2025  
**VPS IP**: 173.249.37.232  
**Domínio**: srcjohann.com.br (exemplo)

---

## ⚡ 5 Minutos para Subir em Produção

### Opção 1: Com IPv4 Direto (SEM Domínio)

```bash
# 1. Entrar no diretório
cd /home/johann/ContaboDocs/sdk-deploy

# 2. Executar o script de setup
sudo ./setup_prod.sh

# 3. Escolher opção 1 (IPv4 Direto)

# 4. Depois, iniciar a aplicação
./start.sh

# 5. Testar
curl http://173.249.37.232
curl http://173.249.37.232/api/health
```

**Acesso em**: http://173.249.37.232

---

### Opção 2: Com Domínio (RECOMENDADO)

#### Passo 1: Configurar DNS no Registrador

1. Acesse seu registrador (UOL Host, Registro.br, GoDaddy, etc)
2. Procure por "Editar DNS" ou "Zona DNS"
3. Adicione os registros:

```dns
Nome: @ ou deixe em branco        Tipo: A    Valor: 173.249.37.232
Nome: api                         Tipo: A    Valor: 173.249.37.232
Nome: www (opcional)              Tipo: A    Valor: 173.249.37.232
```

4. Salvar e aguardar propagação (5-30 minutos)

#### Passo 2: Testar DNS

```bash
# Verificar se DNS está resolvendo
nslookup srcjohann.com.br

# Saída esperada:
# Name:   srcjohann.com.br
# Address: 173.249.37.232
```

#### Passo 3: Rodar Setup

```bash
# 1. Entrar no diretório
cd /home/johann/ContaboDocs/sdk-deploy

# 2. Executar o script de setup
sudo ./setup_prod.sh

# 3. Escolher opção 2 (Domínio com HTTPS)

# 4. Digitar o domínio quando pedido: srcjohann.com.br

# 5. Iniciar a aplicação
./start.sh

# 6. Testar
curl https://srcjohann.com.br
curl https://api.srcjohann.com.br/api/health
```

**Acesso em**: https://srcjohann.com.br

---

## 📋 Checklist Antes de Rodar

- [ ] IP da VPS é 173.249.37.232 (confirmar: `curl https://checkip.amazonaws.com`)
- [ ] Nginx está instalado (`nginx -v`)
- [ ] PostgreSQL está rodando (`sudo systemctl status postgresql`)
- [ ] Porta 80 está aberta (`sudo ufw allow 80/tcp`)
- [ ] Porta 443 está aberta (`sudo ufw allow 443/tcp`)
- [ ] Domínio está registrado (se usar domínio)
- [ ] DNS foi configurado (se usar domínio)

---

## 🔧 Configurações de Ambiente

### Padrão (Localhost - Desenvolvimento)

```bash
# O .env padrão usa localhost
# Acesso: http://localhost:5173 e http://localhost:3001

# Sem fazer nada, está pronto para dev
./start.sh
```

### IPv4 Direto (Produção Simples)

```bash
# Copiar arquivo de configuração
cp .env.prod-ip .env

# Ou usar o script
sudo ./setup_prod.sh  # Escolher opção 1
```

### Domínio com HTTPS (Produção Profissional)

```bash
# Usar o script interativo
sudo ./setup_prod.sh  # Escolher opção 2
```

---

## 📁 Arquivos de Configuração

```
/home/johann/ContaboDocs/sdk-deploy/
├── .env                    # Configuração ativa (localhost por padrão)
├── .env.prod-ip           # Template para produção com IPv4
├── .env.prod-domain       # Template para produção com domínio
├── setup_prod.sh          # Script interativo de setup
├── start.sh               # Inicia frontend + backend
├── nginx.conf             # Configuração Nginx
└── GUIA_DNS_E_DOMINIO.md  # Guia completo de DNS
```

---

## 🧪 Testes de Validação

### Teste 1: Conectividade HTTP

```bash
# Via IPv4
curl -v http://173.249.37.232

# Via Domínio
curl -v http://srcjohann.com.br

# Via HTTPS (após Certbot)
curl -v https://srcjohann.com.br
```

### Teste 2: Health Check API

```bash
# Via IPv4
curl http://173.249.37.232/api/health

# Via Domínio
curl https://api.srcjohann.com.br/api/health

# Resposta esperada:
# {"status":"healthy","database":"connected","rbac":"enabled","timestamp":"2025-10-18T..."}
```

### Teste 3: Verificar Logs

```bash
# Backend
tail -f /home/johann/ContaboDocs/sdk-deploy/logs/backend.log

# Frontend
tail -f /home/johann/ContaboDocs/sdk-deploy/logs/frontend.log

# Nginx
sudo tail -f /var/log/nginx/srcjohann_access.log
sudo tail -f /var/log/nginx/srcjohann_error.log
```

### Teste 4: CORS (do Frontend)

```bash
# Se o frontend tiver JavaScript, abrir DevTools (F12)
# Ir em Console e executar:
fetch('http://173.249.37.232/api/health')
  .then(r => r.json())
  .then(d => console.log(d))

# Se retornar o JSON sem erro CORS, está OK
```

---

## ⚠️ Troubleshooting Rápido

### Problema: "Connection refused"

```bash
# Verificar se Nginx está rodando
sudo systemctl status nginx

# Se não estiver:
sudo systemctl start nginx
sudo systemctl enable nginx

# Verificar se está ouvindo na porta 80/443
sudo ss -tlnp | grep nginx
```

### Problema: DNS não está resolvendo

```bash
# Verificar se DNS está configurado
nslookup srcjohann.com.br

# Se não resolver, aguardar propagação (até 48h)
# Enquanto isso, usar IP direto: http://173.249.37.232

# Testar com servidor DNS diferente
nslookup srcjohann.com.br 8.8.8.8
```

### Problema: CORS Error

```bash
# Verificar se CORS_ORIGINS está correto no .env
grep CORS_ORIGINS .env

# Deve incluir sua URL:
# http://173.249.37.232 ou
# https://srcjohann.com.br

# Se mudar, restart o backend:
pkill -f "uvicorn server"
./start.sh
```

### Problema: SSL Certificate Error

```bash
# Verificar certificado
sudo certbot certificates

# Se não existe, instalar:
sudo certbot --nginx -d srcjohann.com.br -d api.srcjohann.com.br

# Renovar (automático, mas pode forçar)
sudo certbot renew --force-renewal
```

---

## 📊 Status da Aplicação

```bash
# Verificar todos os serviços

# 1. Nginx
sudo systemctl status nginx
ps aux | grep nginx

# 2. Backend (FastAPI)
ps aux | grep uvicorn

# 3. Frontend (Node.js ou estático)
ps aux | grep vite

# 4. PostgreSQL
sudo systemctl status postgresql
```

---

## 🔒 Segurança Básica

### Firewall

```bash
# Ver status
sudo ufw status

# Liberar portas essenciais
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS

# Ativar
sudo ufw enable

# Verificar
sudo ufw status
```

### JWT Secret

```bash
# Verificar se está usando valor seguro
grep JWT_SECRET .env

# Se estiver com o padrão inseguro, gerar novo:
openssl rand -base64 32

# Atualizar no .env:
JWT_SECRET="(valor gerado acima)"
```

### Database Password

```bash
# Mudar senha do PostgreSQL (altamente recomendado)
sudo -u postgres psql
\password postgres
# Digite nova senha e confirme
```

---

## 📞 Próximos Passos

1. ✅ Configurar DNS (se usar domínio)
2. ✅ Executar `sudo ./setup_prod.sh`
3. ✅ Executar `./start.sh`
4. ✅ Testar com `curl` ou no navegador
5. ⚠️ Monitorar logs: `tail -f logs/backend.log`
6. 🔒 Mudar senhas padrão (postgres, admin)
7. 📈 Considerar PM2 ou systemd para gerenciar processos

---

## 🆘 Suporte

**Guia Completo**: `GUIA_DNS_E_DOMINIO.md`  
**Verificação de Correções**: `VERIFICACAO_CORRECOES.md`  
**Documento de Observações**: `Claude_Haiku4.5_observations.md`

---

**Pronto!** A aplicação está preparada para subir em 3 modos:
1. **localhost** (desenvolvimento local)
2. **IPv4 direto** (173.249.37.232)
3. **Domínio com HTTPS** (srcjohann.com.br)

Escolha o modo e execute `sudo ./setup_prod.sh` 🚀
