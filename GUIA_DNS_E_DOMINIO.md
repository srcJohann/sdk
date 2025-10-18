# 🌐 Guia Completo - DNS, Domínios e Configuração para Produção
**Data**: 18 de outubro de 2025  
**Aplicação**: DOM360 (Python FastAPI + React Vite + PostgreSQL)  
**IP VPS**: `173.249.37.232`  
**Domínio**: `srcjohann.com.br` (exemplo)

---

## 📋 ÍNDICE

1. [O que é DNS e Como Funciona](#1-o-que-é-dns-e-como-funciona)
2. [Tipos de Registros DNS](#2-tipos-de-registros-dns)
3. [Passo a Passo - Configurar Domínio](#3-passo-a-passo---configurar-domínio)
4. [Cenários de Acesso](#4-cenários-de-acesso)
5. [Configuração em 3 Modos](#5-configuração-em-3-modos)
6. [Validação e Testes](#6-validação-e-testes)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. O que é DNS e Como Funciona

### Conceito Básico

DNS (Domain Name System) é como um "catálogo telefônico da internet". Ele mapeia nomes legíveis (domínios) para endereços IP numéricos.

```
┌─────────────────────┐
│  Browser do Cliente │
│  "Acessar           │
│   srcjohann.com.br" │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   Resolver DNS      │
│  (seu ISP ou        │
│   8.8.8.8)          │
└──────────┬──────────┘
           │
           ▼ "Qual é o IP?"
┌─────────────────────┐
│  Registrador de     │
│  Domínio            │
│  (GoDaddy, UOL,     │
│   Registro.br)      │
└──────────┬──────────┘
           │
           ▼ "173.249.37.232"
┌─────────────────────┐
│  Browser conecta    │
│  em 173.249.37.232  │
│  (sua VPS)          │
└─────────────────────┘
```

### Por Que Usar Domínio ao Invés de IP?

| Aspecto | IP Direto | Domínio |
|--------|-----------|---------|
| **Memorizar** | ❌ Difícil (173.249.37.232) | ✅ Fácil (srcjohann.com.br) |
| **Confiabilidade** | ⚠️ Se trocar IP, quebra | ✅ Redireciona automaticamente |
| **SSL/TLS** | ❌ Difícil (cert com IP) | ✅ Certbot funciona perfeito |
| **Profissionalismo** | ❌ Parece teste | ✅ Parece produção |
| **Email** | ❌ Não funciona | ✅ Pode ter @seudominio.com.br |

---

## 2. Tipos de Registros DNS

### 2.1 Registro A (Address)

**Propósito**: Mapear domínio para IPv4

```dns
srcjohann.com.br       A  173.249.37.232
```

**Leitura**: "srcjohann.com.br aponta para 173.249.37.232"

**Exemplo Prático**:
- Usuário digita: `http://srcjohann.com.br`
- DNS resolve para: `173.249.37.232`
- Nginx recebe a requisição em `0.0.0.0:80`
- Nginx encaminha para frontend

---

### 2.2 Registro CNAME (Canonical Name)

**Propósito**: Criar alias para outro domínio

```dns
www.srcjohann.com.br   CNAME  srcjohann.com.br
api.srcjohann.com.br   CNAME  srcjohann.com.br
```

**Leitura**: "www.srcjohann.com.br é um alias para srcjohann.com.br"

**Fluxo**:
1. Usuário acessa `http://www.srcjohann.com.br`
2. DNS resolve CNAME → `srcjohann.com.br`
3. DNS resolve A record → `173.249.37.232`
4. Conecta em `173.249.37.232`

---

### 2.3 Registro MX (Mail Exchange)

**Propósito**: Definir servidor de email para o domínio

```dns
srcjohann.com.br  MX  10  mail.srcjohann.com.br
```

**Nota**: Fora do escopo desta aplicação (opcional)

---

### 2.4 Registro AAAA (IPv6)

**Propósito**: Mapear domínio para IPv6

```dns
srcjohann.com.br  AAAA  2001:0db8:85a3::8a2e:0370:7334
```

**Nota**: VPS não tem IPv6 público neste exemplo (opcional)

---

### 2.5 Registro TXT

**Propósito**: Dados de texto arbitrários (SPF, DKIM, etc)

```dns
srcjohann.com.br  TXT  "v=spf1 include:_spf.google.com ~all"
```

**Nota**: Para email e validação (opcional)

---

## 3. Passo a Passo - Configurar Domínio

### 3.1 Onde Configurar?

Você precisa acessar o **Registrador de Domínio** onde comprou seu domínio:

#### Registradores Populares (Brasil)

| Registrador | URL | Onde Configurar |
|------------|-----|-----------------|
| **UOL Host** | https://www.uolhost.com.br | Painel → Domínios → Editar DNS |
| **Registro.br** | https://registro.br | Painel → Meus Domínios → Editar Zona de DNS |
| **GoDaddy** | https://godaddy.com | My Products → Domains → Manage DNS |
| **Hostinger** | https://hostinger.com | Meu Painel → Domínios → Gerenciar |
| **HostGator** | https://hostgator.com.br | Painel → Domínios → Editar Zona |
| **Locaweb** | https://locaweb.com.br | Painel → Domínios → Editar DNS |

---

### 3.2 Registros a Configurar

Para a aplicação DOM360 funcionar, você precisa adicionar **2 registros A**:

#### Registro 1: Domínio Principal (Frontend)
```
Nome do Registro: srcjohann.com.br  (ou deixe em branco)
Tipo: A
Valor (IPv4): 173.249.37.232
TTL: 3600 (1 hora) ou deixe padrão
```

#### Registro 2: Subdomínio API (Backend)
```
Nome do Registro: api  (o registrador preenche: api.srcjohann.com.br)
Tipo: A
Valor (IPv4): 173.249.37.232
TTL: 3600 (1 hora) ou deixe padrão
```

---

### 3.3 Exemplo - UOL Host (Passo a Passo com Screenshots Conceituais)

```
1. Acesse https://www.uolhost.com.br
2. Clique em "Painel de Controle" (ou "Minha Conta")
3. Selecione seu domínio (srcjohann.com.br)
4. Clique em "Editar DNS" ou "Zona de DNS"

Você verá uma tela assim:

┌──────────────────────────────────────────────────┐
│ Registros DNS para: srcjohann.com.br             │
├──────────────────────────────────────────────────┤
│ Nome          | Tipo | Valor              | TTL │
├──────────────────────────────────────────────────┤
│ (em branco)   | A    | 173.249.37.232     | 3600│
│ www           | A    | 173.249.37.232     | 3600│
│ api           | A    | 173.249.37.232     | 3600│
│ mail          | MX   | mail.srcjohann...  | 3600│
└──────────────────────────────────────────────────┘

5. Clique em "Adicionar Registro"
6. Preencha os dados acima
7. Clique em "Salvar"
```

---

### 3.4 Registro da Zona (Alternativa Avançada)

Alguns registradores permitem editar a zona DNS diretamente (arquivo BIND):

```dns
; Zona DNS para srcjohann.com.br
; Atualizado em: 18 de outubro de 2025

; Registros A - Frontend e Backend apontam para mesmo IP
@                3600  IN  A  173.249.37.232
www              3600  IN  A  173.249.37.232
api              3600  IN  A  173.249.37.232

; Alternativa com CNAME (opcional, menos comum)
; www              3600  IN  CNAME  @
; api              3600  IN  A  173.249.37.232
```

---

### 3.5 Quanto Tempo Leva para Ativar?

**TTL (Time To Live)** controla o cache:

```
┌─────────────────────────┐
│ Você altera DNS         │
│ no registrador          │
│ (TTL = 3600 = 1 hora)   │
└────────────┬────────────┘
             │
    ┌────────┴────────┐
    │ Resolver ISP    │
    │ (seu provedor)  │
    │ Cache por 1h    │
    └────────┬────────┘
             │
    ┌────────┴────────┐
    │ Se cache expirou│
    │ faz nova query  │
    │ ao registrador  │
    └────────────────┘
```

**Tempo de Propagação**:
- ✅ **Alguns minutos**: Próximas requisições (seu provedor)
- ⚠️ **Até 24-48h**: Propagação global completa
- 💡 **Na prática**: Funciona em poucos minutos para você

**Teste Imediato**:
```bash
# Verificar se DNS está resolvendo
nslookup srcjohann.com.br
# ou
dig srcjohann.com.br
# ou
host srcjohann.com.br

# Saída esperada:
# Name: srcjohann.com.br
# Address: 173.249.37.232
```

---

## 4. Cenários de Acesso

Após configurar DNS, você terá **3 formas de acessar** a aplicação:

### Cenário 1: Localhost (Desenvolvimento Local)

```
Máquina Local (seu computador)
    ↓
Browser: http://localhost:5173 (Frontend)
Browser: http://localhost:3001 (Backend API)

✅ Funciona: SIM (Vite dev server)
❌ Conectar de outra máquina: NÃO
```

### Cenário 2: IPv4 Direto (Qualquer Máquina na Internet)

```
Qualquer máquina na internet
    ↓
Browser: http://173.249.37.232 (Frontend via Nginx)
Browser: http://173.249.37.232/api/... (Backend via Nginx)

✅ Funciona: SIM (após Nginx configurado)
❌ SSL/TLS: NÃO (requer Certbot)
❌ Profissional: NÃO (IP é feio)
```

### Cenário 3: Domínio com DNS (Recomendado)

```
Qualquer máquina na internet
    ↓
DNS resolve srcjohann.com.br → 173.249.37.232
    ↓
Browser: https://srcjohann.com.br (Frontend)
Browser: https://api.srcjohann.com.br/api/... (Backend)

✅ Funciona: SIM (após Nginx + Certbot)
✅ SSL/TLS: SIM (certificado automático)
✅ Profissional: SIM
```

---

## 5. Configuração em 3 Modos

Agora vamos configurar a aplicação para todos os cenários:

### 5.1 Estrutura de Múltiplos .env

Vou criar 3 arquivos `.env`:

#### `.env` - Padrão (Desenvolvimento Local)
```properties
# Para desenvolvimento local na máquina
# Acesso via: http://localhost:5173 e http://localhost:3001
```

#### `.env.prod-ip` - Produção com IPv4 Direto
```properties
# Para produção com IP direto: 173.249.37.232
# Acesso via: http://173.249.37.232
```

#### `.env.prod-domain` - Produção com Domínio
```properties
# Para produção com domínio: srcjohann.com.br
# Acesso via: https://srcjohann.com.br e https://api.srcjohann.com.br
```

---

### 5.2 Atualizar .env Padrão (Localhost)

```properties
# ============================================================================
# MODO: DESENVOLVIMENTO LOCAL
# Acesso: http://localhost:5173 (Frontend) e http://localhost:3001 (API)
# ============================================================================

# PostgreSQL Database
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=dom360_db_sdk
DB_USER=postgres
DB_PASSWORD="admin"

# Backend API (FastAPI)
BACKEND_BIND_HOST=0.0.0.0
BACKEND_BIND_PORT=3001
INTERNAL_BACKEND_HOST=127.0.0.1
INTERNAL_BACKEND_PORT=3001
PUBLIC_BACKEND_URL=http://localhost:3001
PUBLIC_BACKEND_HOST=localhost

# Frontend (React + Vite)
VITE_API_URL=http://localhost:3001
VITE_TENANT_ID="00000000-0000-0000-0000-000000000001"
VITE_INBOX_ID="00000000-0000-0000-0001-000000000001"
VITE_USER_PHONE="+5511999998888"
VITE_USER_NAME="Usuário Teste"

FRONTEND_BIND_HOST=0.0.0.0
FRONTEND_BIND_PORT=5173
INTERNAL_FRONTEND_HOST=127.0.0.1
INTERNAL_FRONTEND_PORT=5173
PUBLIC_FRONTEND_URL=http://localhost:5173
PUBLIC_FRONTEND_HOST=localhost

# Security
JWT_SECRET="eSGm2XZ8lBfB++3TOt0Tp0rR8MimWnohTD9oqaq+Q84="

# Environment
NODE_ENV=development
PYTHON_ENV=development

# ============================================================================
# CORS - Local Development
# ============================================================================
CORS_ORIGINS=http://localhost:5173,http://localhost:3001,http://127.0.0.1:5173,http://127.0.0.1:3001
```

**Arquivo**: `/home/johann/ContaboDocs/sdk-deploy/.env`

---

### 5.3 Criar .env.prod-ip (IPv4 Direto)

```properties
# ============================================================================
# MODO: PRODUÇÃO COM IPv4 DIRETO
# IP VPS: 173.249.37.232
# Acesso: http://173.249.37.232 (sem domínio)
# ============================================================================

# PostgreSQL Database
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=dom360_db_sdk
DB_USER=postgres
DB_PASSWORD="admin"

# Backend API (FastAPI)
BACKEND_BIND_HOST=0.0.0.0
BACKEND_BIND_PORT=3001
INTERNAL_BACKEND_HOST=127.0.0.1
INTERNAL_BACKEND_PORT=3001
PUBLIC_BACKEND_URL=http://173.249.37.232
PUBLIC_BACKEND_HOST=173.249.37.232

# Frontend (React + Vite)
VITE_API_URL=http://173.249.37.232
VITE_TENANT_ID="00000000-0000-0000-0000-000000000001"
VITE_INBOX_ID="00000000-0000-0000-0001-000000000001"
VITE_USER_PHONE="+5511999998888"
VITE_USER_NAME="Usuário Teste"

FRONTEND_BIND_HOST=0.0.0.0
FRONTEND_BIND_PORT=5173
INTERNAL_FRONTEND_HOST=127.0.0.1
INTERNAL_FRONTEND_PORT=5173
PUBLIC_FRONTEND_URL=http://173.249.37.232
PUBLIC_FRONTEND_HOST=173.249.37.232

# Security
JWT_SECRET="eSGm2XZ8lBfB++3TOt0Tp0rR8MimWnohTD9oqaq+Q84="

# Environment
NODE_ENV=production
PYTHON_ENV=production

# ============================================================================
# CORS - Production (IP)
# ============================================================================
CORS_ORIGINS=http://173.249.37.232,http://0.0.0.0
```

**Arquivo**: `/home/johann/ContaboDocs/sdk-deploy/.env.prod-ip`

---

### 5.4 Criar .env.prod-domain (Com Domínio)

```properties
# ============================================================================
# MODO: PRODUÇÃO COM DOMÍNIO
# Domínio: srcjohann.com.br
# IP VPS: 173.249.37.232
# Acesso: https://srcjohann.com.br e https://api.srcjohann.com.br
# ============================================================================

# PostgreSQL Database
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=dom360_db_sdk
DB_USER=postgres
DB_PASSWORD="admin"

# Backend API (FastAPI)
BACKEND_BIND_HOST=0.0.0.0
BACKEND_BIND_PORT=3001
INTERNAL_BACKEND_HOST=127.0.0.1
INTERNAL_BACKEND_PORT=3001
PUBLIC_BACKEND_URL=https://api.srcjohann.com.br
PUBLIC_BACKEND_HOST=api.srcjohann.com.br

# Frontend (React + Vite)
VITE_API_URL=https://api.srcjohann.com.br
VITE_TENANT_ID="00000000-0000-0000-0000-000000000001"
VITE_INBOX_ID="00000000-0000-0000-0001-000000000001"
VITE_USER_PHONE="+5511999998888"
VITE_USER_NAME="Usuário Teste"

FRONTEND_BIND_HOST=0.0.0.0
FRONTEND_BIND_PORT=5173
INTERNAL_FRONTEND_HOST=127.0.0.1
INTERNAL_FRONTEND_PORT=5173
PUBLIC_FRONTEND_URL=https://srcjohann.com.br
PUBLIC_FRONTEND_HOST=srcjohann.com.br

# Security
JWT_SECRET="eSGm2XZ8lBfB++3TOt0Tp0rR8MimWnohTD9oqaq+Q84="

# Environment
NODE_ENV=production
PYTHON_ENV=production

# ============================================================================
# CORS - Production (Domínio com HTTPS)
# ============================================================================
CORS_ORIGINS=https://srcjohann.com.br,https://api.srcjohann.com.br,http://localhost:5173
```

**Arquivo**: `/home/johann/ContaboDocs/sdk-deploy/.env.prod-domain`

---

## 6. Validação e Testes

### 6.1 Testar DNS Resolution

```bash
# Verificar se DNS está resolvendo para o IP correto
nslookup srcjohann.com.br
# Saída esperada:
# Non-authoritative answer:
# Name:   srcjohann.com.br
# Address: 173.249.37.232

# Verificar com dig (mais verboso)
dig srcjohann.com.br
# Saída esperada:
# ;; ANSWER SECTION:
# srcjohann.com.br.       3600    IN      A       173.249.37.232

# Verificar subdomínio API
nslookup api.srcjohann.com.br
# Saída esperada:
# api.srcjohann.com.br canonical name = srcjohann.com.br
# srcjohann.com.br        address = 173.249.37.232
```

### 6.2 Testar Conectividade HTTP

```bash
# Testar via IPv4 direto
curl -v http://173.249.37.232
# Saída esperada: 200 OK (após Nginx estar rodando)

# Testar via domínio
curl -v http://srcjohann.com.br
# Saída esperada: 200 OK (após DNS propagar)

# Testar API
curl -v http://173.249.37.232/api/health
curl -v http://srcjohann.com.br/api/health
```

### 6.3 Testar SSL/TLS (Após Certbot)

```bash
# Validar certificado
openssl s_client -connect srcjohann.com.br:443
# Saída: CONNECTED, issuer=Let's Encrypt

# Testar com curl
curl -v https://srcjohann.com.br
# Saída esperada: 200 OK (com SSL válido)
```

---

## 7. Troubleshooting

### Problema 1: DNS Não Está Resolvendo

**Sintoma**: `nslookup srcjohann.com.br` retorna "server can't find"

**Soluções**:
```bash
# 1. Verificar se você está usando o registrador correto
whois srcjohann.com.br | grep "Registrar"

# 2. Limpar cache DNS local
sudo systemd-resolve --flush-caches

# 3. Usar servidor DNS diferente
nslookup srcjohann.com.br 8.8.8.8  # Google DNS

# 4. Aguardar propagação (até 48h)
watch -n 5 "nslookup srcjohann.com.br"  # Atualiza a cada 5s
```

### Problema 2: Conectar na VPS Retorna "Connection Refused"

**Sintoma**: `curl http://173.249.37.232` retorna "Connection refused"

**Soluções**:
```bash
# 1. Verificar se Nginx está rodando
sudo systemctl status nginx
sudo systemctl start nginx

# 2. Verificar se Nginx está ouvindo na porta 80
sudo ss -tlnp | grep nginx
# Saída esperada: 0.0.0.0:80 LISTEN

# 3. Verificar firewall
sudo ufw status
# Se bloqueando, liberar:
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# 4. Verificar se backend está rodando
ps aux | grep uvicorn
```

### Problema 3: CORS Error no Frontend

**Sintoma**: `Access-Control-Allow-Origin` error no console do navegador

**Soluções**:
```python
# No backend (server_rbac.py), verificar CORS_ORIGINS
# Deve incluir a URL do frontend:
# "https://srcjohann.com.br" ou
# "http://173.249.37.232"

# Testar CORS com curl
curl -i -X OPTIONS http://173.249.37.232/api/health \
  -H "Origin: http://173.249.37.232" \
  -H "Access-Control-Request-Method: POST"

# Saída esperada:
# Access-Control-Allow-Origin: http://173.249.37.232
# Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
```

### Problema 4: SSL Certificate Error

**Sintoma**: "SSL certificate problem: self signed certificate"

**Soluções**:
```bash
# 1. Verificar se Certbot foi executado
sudo ls -la /etc/letsencrypt/live/srcjohann.com.br/

# 2. Se não existe, instalar:
sudo certbot --nginx -d srcjohann.com.br -d api.srcjohann.com.br

# 3. Renovar certificado (automático, mas pode forçar)
sudo certbot renew --force-renewal

# 4. Verificar status do Certbot
sudo certbot certificates
```

---

## 📋 Checklist Final - Pronto para Produção

### Antes de Fazer Deploy

- [ ] Domínio registrado e acessível
- [ ] Registros A configurados no registrador:
  - [ ] `@` ou raiz → `173.249.37.232`
  - [ ] `api` → `173.249.37.232`
  - [ ] `www` → `173.249.37.232` (opcional)
- [ ] DNS está resolvendo (testar com `nslookup`)
- [ ] IP da VPS é `173.249.37.232`
- [ ] Arquivo `.env.prod-domain` está correto
- [ ] Frontend vai fazer rebuild com `npm run build`

### Procedimento de Deploy

```bash
# 1. Fazer rebuild do frontend com URL correta
cd /home/johann/ContaboDocs/sdk-deploy/frontend/app
cp ../../.env.prod-domain ../../.env
npm run build

# 2. Aplicar configuração Nginx
source /home/johann/ContaboDocs/sdk-deploy/.env
envsubst < /home/johann/ContaboDocs/sdk-deploy/nginx.conf | \
  sudo tee /etc/nginx/sites-available/dom360

# 3. Testar Nginx
sudo nginx -t

# 4. Ativar Nginx
sudo systemctl restart nginx

# 5. Instalar SSL
sudo certbot --nginx -d srcjohann.com.br -d api.srcjohann.com.br

# 6. Iniciar aplicação
cd /home/johann/ContaboDocs/sdk-deploy
./start.sh

# 7. Testar
curl https://srcjohann.com.br
curl https://api.srcjohann.com.br/api/health
```

---

## 📞 Suporte

**Registrador**: Consulte a documentação específica  
**DNS Issues**: `nslookup`, `dig`, `host` são seus amigos  
**SSL Issues**: `sudo certbot --dry-run` para testar sem ativar

---

**Preparado em**: 18 de outubro de 2025  
**VPS IP**: 173.249.37.232  
**Próximo Passo**: Criar registros DNS no seu registrador
