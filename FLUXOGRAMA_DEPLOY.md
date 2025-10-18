# 📊 Fluxograma Visual - Deploy DOM360
**Data**: 18 de outubro de 2025

---

## 1. Arquitetura da Aplicação

```
┌─────────────────────────────────────────────────────────────┐
│                     CLIENTE (Internet)                       │
│                                                               │
│   Browser → DNS Resolver → Registrador de Domínio           │
│                                                               │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ DNS Resolve
                         │ srcjohann.com.br → 173.249.37.232
                         │
┌────────────────────────▼────────────────────────────────────┐
│                   VPS (173.249.37.232)                       │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Nginx (Reverse Proxy)                   │   │
│  │  Porta 80/443  →  recebe requisições de clientes    │   │
│  └──────────────────────────────────────────────────────┘   │
│                         │                                      │
│     ┌───────────────────┴───────────────────┐               │
│     │                                       │               │
│     ▼ (frontend/)                  ▼ (/api/)               │
│                                                               │
│  ┌─────────────────────┐        ┌──────────────────┐       │
│  │  React + Vite       │        │  FastAPI Backend │       │
│  │  http://0.0.0.0:5173│        │  http://0.0.0.0:3001   │
│  │  (Estático)         │        │  (Python RBAC)   │       │
│  └─────────────────────┘        └─────────┬────────┘       │
│                                           │                  │
│                                           ▼                  │
│                                  ┌──────────────────┐       │
│                                  │   PostgreSQL     │       │
│                                  │  Porta 5432      │       │
│                                  │  DB: dom360_db   │       │
│                                  └──────────────────┘       │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Fluxo de Acesso por Modo

### Modo 1: Localhost (Desenvolvimento)

```
┌─────────────────────────┐
│  Seu Computador         │
│  (Máquina Local)        │
└────────────┬────────────┘
             │
      ┌──────┴──────┐
      │             │
      ▼             ▼
  :5173        :3001
(Frontend)   (Backend)
  
Acesso direto (sem Nginx)
Sem DNS necessário
Sem SSL
```

**Comando**: `./start.sh`

---

### Modo 2: IPv4 Direto (Produção Simples)

```
┌──────────────────────────────────┐
│  Cliente (Qualquer lugar)        │
│  Digita: 173.249.37.232          │
└────────────┬─────────────────────┘
             │
             ▼
  ┌────────────────────────┐
  │    Nginx (porta 80)    │
  │  173.249.37.232:80/443 │
  └─────────┬──────────────┘
            │
     ┌──────┴──────┐
     ▼             ▼
 :5173(FE)    :3001(API)

Sem DNS (usa IP direto)
Sem HTTPS (HTTP puro)
Nginx faz reverse proxy
```

**Setup**: `sudo ./setup_prod.sh` → Opção 1

---

### Modo 3: Domínio com HTTPS (Profissional)

```
┌──────────────────────────────────┐
│  Cliente (Qualquer lugar)        │
│  Digita: srcjohann.com.br        │
└────────────┬─────────────────────┘
             │
             ▼
  ┌────────────────────────┐
  │   DNS Resolver         │
  │  (seu ISP ou 8.8.8.8)  │
  └─────────┬──────────────┘
            │
    "Qual é o IP de
     srcjohann.com.br?"
            │
            ▼
  ┌────────────────────────┐
  │  Registrador de Domain │
  │  (UOL, Registro.br)    │
  │  Retorna: 173.249.37.232
  └────────────┬───────────┘
               │
               ▼
  ┌────────────────────────┐
  │ Nginx (porta 443)      │
  │ SSL/TLS Certificate    │
  │ srcjohann.com.br       │
  │ api.srcjohann.com.br   │
  └─────────┬──────────────┘
            │
     ┌──────┴──────┐
     ▼             ▼
 :5173(FE)    :3001(API)

Com DNS (domínio resolve)
Com HTTPS (certificado Let's Encrypt)
Nginx faz reverse proxy + SSL
```

**Setup**: `sudo ./setup_prod.sh` → Opção 2

---

## 3. Fluxo de Deploy Passo-a-Passo

```
START
  │
  ▼
┌──────────────────────────────────────┐
│ 1. PREPARAÇÃO                         │
│  ✓ SSH na VPS                        │
│  ✓ Abrir firewall (80, 443)          │
│  ✓ Instalar dependências             │
│  ✓ Clonar/baixar código              │
└─────────────┬────────────────────────┘
              │
              ▼
    ┌──────────────────────┐
    │ 2. ESCOLHER MODO     │
    └────────┬─────────────┘
             │
    ┌────────┼────────┐
    │        │        │
   IPv4   Domínio   Local
    │        │        │
    ▼        ▼        ▼
   [A]      [B]      [C]
    
[A] MODO IPv4 (Direto)
│
├─ cp .env.prod-ip .env
├─ npm run build (frontend)
├─ envsubst nginx.conf
├─ nginx restart
├─ ./start.sh
└─ PRONTO! (http://173.249.37.232)

[B] MODO DOMÍNIO (Profissional) ⭐
│
├─ Configurar DNS no registrador
│  ├─ @ → 173.249.37.232
│  └─ api → 173.249.37.232
├─ Aguardar DNS propagar (5-30 min)
├─ cp .env.prod-domain .env
├─ npm run build (frontend)
├─ envsubst nginx.conf
├─ certbot --nginx -d srcjohann.com.br
├─ nginx restart
├─ ./start.sh
└─ PRONTO! (https://srcjohann.com.br)

[C] MODO LOCAL (Dev)
│
├─ .env padrão já está configurado
├─ npm install (frontend)
├─ npm run build (opcional)
├─ ./start.sh
└─ PRONTO! (http://localhost:5173)
```

---

## 4. Mapa de Arquivos Importantes

```
/home/johann/ContaboDocs/sdk-deploy/
│
├── 📄 .env                          ← ATIVO (atualmente localhost)
├── 📄 .env.prod-ip                  ← TEMPLATE (IPv4 direto)
├── 📄 .env.prod-domain              ← TEMPLATE (domínio HTTPS)
│
├── 🔧 setup_prod.sh                 ← SCRIPT INTERATIVO (use este!)
├── 🔧 start.sh                      ← INICIA APLICAÇÃO
├── 🔧 nginx.conf                    ← CONFIG NGINX (com placeholders)
│
├── 📖 GUIA_DNS_E_DOMINIO.md         ← LEIA ISSO (DNS completo)
├── 📖 DEPLOY_RAPIDO.md              ← LEIA ISSO (5 minutos)
├── 📖 RESUMO_PRODUCAO.md            ← LEIA ISSO (checklist)
├── 📖 VERIFICACAO_CORRECOES.md      ← LEIA ISSO (o que foi corrigido)
│
├── backend/
│  ├── server_rbac.py                ← FastAPI app
│  ├── auth/middleware.py            ← JWT, CORS
│  └── api/
│
├── frontend/app/
│  ├── src/services/dom360ApiService.js    ← VITE_API_URL lido daqui
│  ├── vite.config.js                ← Binding host
│  └── package.json
│
├── database/
│  ├── schema.sql
│  └── migrations/
│
└── logs/
   ├── backend.log
   └── frontend.log
```

---

## 5. Fluxo de Decisão - Qual Modo Usar?

```
┌─────────────────────────────────────┐
│ Onde a aplicação vai rodar?         │
└─────────────────────────────────────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
    ▼            ▼            ▼
 Meu PC       VPS sem      VPS com
Próximo    Domínio      Domínio
 de mim
    │            │            │
    │            │            │
    ▼            ▼            ▼
  LOCAL      IPv4 DIRETO   DOMÍNIO
    │            │            │
    │            │            │
  [L]          [I]           [D]

[L] MODO LOCAL
├─ .env padrão
├─ Acesso: http://localhost:5173
├─ Comando: ./start.sh
└─ Ideal para: Desenvolvimento

[I] MODO IPv4
├─ .env.prod-ip
├─ Acesso: http://173.249.37.232
├─ Comando: sudo ./setup_prod.sh (1)
└─ Ideal para: Testes rápidos, sem domínio

[D] MODO DOMÍNIO ⭐ RECOMENDADO
├─ .env.prod-domain
├─ Acesso: https://srcjohann.com.br
├─ Comando: sudo ./setup_prod.sh (2)
├─ Requer: DNS configurado
└─ Ideal para: Produção profissional

VOCÊ ESTÁ AQUI → [I] Testando com IPv4
PRÓXIMO PASSO → [D] Configurar domínio
```

---

## 6. Cronograma de Deploy

```
Tempo        Atividade                    Duração
─────────────────────────────────────────────────

00:00    SSH na VPS                       1 min
00:01    Instalar dependências            2 min
00:03    Clonar/copiar código             1 min
00:04    Configurar DNS (se usar)         2 min*
00:06    Executar setup_prod.sh           3 min
00:09    Rebuild frontend                 5 min
00:14    Certbot SSL (se usar)            2 min**
00:16    ./start.sh                       1 min
00:17    Testar conectividade             1 min
00:18    ✅ PRONTO!

* Apenas se usar domínio; propagação até 48h
** Apenas se usar HTTPS

TEMPO TOTAL:
- IPv4 direto: ~9 minutos
- Com domínio: ~18 minutos (+ propagação DNS)
```

---

## 7. Verificação Visual - Antes vs Depois

### ANTES (Problemas)
```
Frontend tenta conectar em 127.0.0.1:3001
                    │
                    ▼
Cliente remoto não consegue acessar (localhost é do cliente)
                    │
                    ▼
"Connection Refused" ❌

CORS error porque allow_origins=["*"] + allow_credentials=True
                    │
                    ▼
Navegador rejeita requisição ❌

JWT_SECRET = "CHANGE_ME_IN_PRODUCTION..."
                    │
                    ▼
Tokens JWT inseguros, facilmente forjáveis ❌

Nginx com ${VARIABLE} não expandidos
                    │
                    ▼
Nginx tenta resolver upstreams com nomes inválidos ❌
```

### DEPOIS (Corrigido)
```
Frontend conecta em domínio público ou IP
                    │
                    ▼
Cliente remoto consegue acessar (DNS resolve) ✅

CORS com lista específica de domínios
                    │
                    ▼
Navegador aceita requisição com credentials ✅

JWT_SECRET = "eSGm2XZ8lBfB++3TOt0Tp0rR8MimWnohTD9oqaq+Q84="
                    │
                    ▼
Tokens JWT seguros com 256 bits ✅

Nginx com ${VARIABLE} expandidos via envsubst
                    │
                    ▼
Nginx encontra upstreams corretos ✅

3 modos funcionando: localhost, IPv4, domínio ✅
```

---

## 8. Checklist Visual de Deploy

```
┌────────────────────────────────────────────────────┐
│ PRÉ-REQUISITOS                                     │
├────────────────────────────────────────────────────┤
│ ☐ SSH acessível                                    │
│ ☐ Firewall: portas 80, 443, 22 abertas            │
│ ☐ PostgreSQL rodando                              │
│ ☐ Nginx instalado                                 │
│ ☐ Node.js/npm instalado                           │
│ ☐ Python 3/pip instalado                          │
└────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────┐
│ ESCOLHA DO MODO                                    │
├────────────────────────────────────────────────────┤
│ IPv4 DIRETO                                        │
│ ☐ Copiar .env.prod-ip → .env                      │
│ ☐ Rebuild frontend                                │
│ ☐ Rodar setup_prod.sh (opção 1)                   │
│ ☐ Testar: curl http://173.249.37.232              │
│                                                    │
│ DOMÍNIO COM HTTPS ⭐                               │
│ ☐ Registrador: criar registros A                  │
│ ☐ DNS: testar resolução (nslookup)                │
│ ☐ Copiar .env.prod-domain → .env                  │
│ ☐ Rebuild frontend                                │
│ ☐ Rodar setup_prod.sh (opção 2)                   │
│ ☐ Testar: curl https://srcjohann.com.br           │
└────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────┐
│ PÓS-DEPLOY                                         │
├────────────────────────────────────────────────────┤
│ ☐ Health check funciona                           │
│ ☐ Frontend carrega                                │
│ ☐ Sem CORS errors                                 │
│ ☐ SSL válido (se HTTPS)                           │
│ ☐ Logs sem erros                                  │
│ ☐ Database conectado                              │
└────────────────────────────────────────────────────┘
```

---

## 9. Referência Rápida de Comandos

```bash
# ============ SETUP ============

# Executar setup interativo
sudo ./setup_prod.sh

# Iniciar aplicação
./start.sh

# ============ VALIDAÇÃO ============

# Testar DNS
nslookup srcjohann.com.br

# Testar Nginx
sudo nginx -t

# Testar conectividade HTTP
curl -v http://173.249.37.232
curl -v https://srcjohann.com.br

# Testar health API
curl http://173.249.37.232/api/health

# ============ MONITORAMENTO ============

# Ver status Nginx
sudo systemctl status nginx

# Ver logs Nginx
sudo tail -f /var/log/nginx/srcjohann_access.log

# Ver logs backend
tail -f /home/johann/ContaboDocs/sdk-deploy/logs/backend.log

# Ver certificados SSL
sudo certbot certificates

# ============ TROUBLESHOOTING ============

# Reiniciar Nginx
sudo systemctl restart nginx

# Ver conectando portas
sudo ss -tlnp

# Limpar cache DNS
sudo systemd-resolve --flush-caches

# Renovar certificado SSL
sudo certbot renew --force-renewal
```

---

**Versão**: 1.0  
**Data**: 18 de outubro de 2025  
**Status**: ✅ Pronto para Deploy
