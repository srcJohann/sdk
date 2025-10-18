# ✅ Correções Aplicadas - Deploy VPS DOM360

## Data: 18 de outubro de 2025

Este documento resume todas as correções aplicadas com base na análise do documento `Claude_Haiku4.5_observations.md`.

---

## 🔴 Problemas Críticos Corrigidos

### 1. ✅ URL Hardcoded no Frontend (CRÍTICO)

**Problema Original:**
```bash
# ❌ ANTES
VITE_API_URL=http://127.0.0.1:3001
```

**Correção Aplicada:**
```bash
# ✅ DEPOIS
VITE_API_URL=http://api.srcjohann.com.br
```

**Arquivo:** `.env`  
**Impacto:** Frontend agora aponta para URL pública acessível remotamente

---

### 2. ✅ Inconsistência entre Frontend e Nginx

**Problema Original:**
```bash
# Frontend apontava para localhost
VITE_API_URL=http://127.0.0.1:3001

# Nginx esperava domínio público
PUBLIC_BACKEND_URL=http://api.srcjohann.com.br
```

**Correção Aplicada:**
- Adicionado `PUBLIC_BACKEND_HOST=api.srcjohann.com.br` no .env
- Adicionado `PUBLIC_FRONTEND_HOST=srcjohann.com.br` no .env
- URLs sincronizadas entre frontend e nginx

**Arquivos:** `.env`, `nginx.conf`

---

### 3. ✅ Nginx Placeholders Não Expandidos

**Problema Original:**
```nginx
upstream backend {
    server ${INTERNAL_BACKEND_HOST:-localhost}:${INTERNAL_BACKEND_PORT:-3001};
}
```

Nginx não interpreta `${...}` - é sintaxe shell!

**Correção Aplicada:**
- Modificado `setup_nginx.sh` para usar `envsubst`
- Script agora expande variáveis corretamente antes de copiar para `/etc/nginx/sites-available/`

**Arquivo:** `setup_nginx.sh`

**Como usar:**
```bash
sudo bash setup_nginx.sh
```

---

### 4. ✅ CORS Permissivo e Inválido

**Problema Original:**
```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # ❌ INVÁLIDO com credentials!
    allow_credentials=True,
)
```

Navegadores REJEITAM `Access-Control-Allow-Origin: *` + `credentials: true`

**Correção Aplicada:**
```python
CORS_ORIGINS = os.getenv('CORS_ORIGINS', '').split(',') if os.getenv('CORS_ORIGINS') else [
    "http://localhost:5173",
    "http://srcjohann.com.br",
    "http://api.srcjohann.com.br",
    "https://srcjohann.com.br",
    "https://api.srcjohann.com.br",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,  # ✅ Domínios específicos
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)
```

**Arquivo:** `backend/server_rbac.py`

---

### 5. ✅ JWT Secret Padrão Inseguro

**Problema Original:**
```python
JWT_SECRET = os.getenv("JWT_SECRET", "CHANGE_ME_IN_PRODUCTION_USE_STRONG_SECRET")
```

Secret óbvio = qualquer um pode forjar tokens!

**Correção Aplicada:**
```bash
# .env
JWT_SECRET="eSGm2XZ8lBfB++3TOt0Tp0rR8MimWnohTD9oqaq+Q84="
```

**Gerado com:**
```bash
openssl rand -base64 32
```

**Arquivo:** `.env`

---

### 6. ✅ Variáveis sem Quotes

**Problema Original:**
```bash
DB_PASSWORD=admin
VITE_TENANT_ID=00000000-0000-0000-0000-000000000001
```

Pode causar problemas com caracteres especiais

**Correção Aplicada:**
```bash
DB_PASSWORD="admin"
VITE_TENANT_ID="00000000-0000-0000-0000-000000000001"
VITE_INBOX_ID="00000000-0000-0000-0001-000000000001"
VITE_USER_PHONE="+5511999998888"
VITE_USER_NAME="Usuário Teste"
```

**Arquivo:** `.env`

---

## 🟡 Melhorias Adicionais

### 7. ✅ Frontend Build Precisa Regeneração

**Problema:** Build antigo tinha URL localhost hardcoded

**Solução:**
```bash
cd frontend/app
npm run build
```

**Incluído no:** `deploy_vps.sh`

---

### 8. ✅ Health Check Endpoint

**Status:** ✅ Já existe no código!

```python
@app.get("/api/health")
async def health_check(request: Request):
    return {
        "status": "healthy",
        "database": "connected",
        "rbac": "enabled",
        "timestamp": datetime.utcnow().isoformat()
    }
```

**Teste:**
```bash
curl http://api.srcjohann.com.br/api/health
```

---

## 📦 Novos Arquivos Criados

### 1. `deploy_vps.sh`
Script completo de deploy automatizado que:
- Valida .env
- Instala dependências
- Configura PostgreSQL
- Gera build de produção
- Configura Nginx
- Configura firewall
- Cria serviços systemd
- (Opcional) Configura SSL

**Uso:**
```bash
sudo bash deploy_vps.sh
```

---

### 2. `docs/DEPLOY_VPS_GUIDE.md`
Guia completo passo-a-passo:
- Deploy automatizado
- Deploy manual
- Troubleshooting
- Problemas comuns e soluções
- Checklist pós-deploy

---

### 3. `.env.production.example`
Template de .env para produção com:
- Todos os valores necessários
- Comentários explicativos
- Marcações de valores CRÍTICOS
- Instruções de deploy
- Checklist pré-deploy

---

## 🚀 Como Aplicar as Correções

### Opção 1: Deploy Automatizado (Recomendado)

```bash
# 1. Editar .env com suas URLs
nano .env
# Alterar:
#   VITE_API_URL=http://api.seudominio.com
#   PUBLIC_BACKEND_HOST=api.seudominio.com
#   PUBLIC_FRONTEND_HOST=seudominio.com

# 2. Executar deploy
sudo bash deploy_vps.sh
```

### Opção 2: Deploy Manual

Siga o guia completo em `docs/DEPLOY_VPS_GUIDE.md`

---

## 📋 Checklist de Correções

- [x] VITE_API_URL aponta para URL pública
- [x] PUBLIC_BACKEND_HOST definido
- [x] PUBLIC_FRONTEND_HOST definido
- [x] JWT_SECRET gerado com openssl
- [x] DB_PASSWORD com quotes
- [x] CORS configurado com domínios específicos
- [x] Nginx usa envsubst para expandir variáveis
- [x] setup_nginx.sh corrigido
- [x] Health check endpoint existe
- [x] Script de deploy completo criado
- [x] Documentação de deploy criada
- [x] Template .env.production criado

---

## 🔍 Validação Pós-Deploy

Execute estes testes para validar o deploy:

```bash
# 1. Backend health check
curl http://api.seudominio.com/api/health

# 2. Frontend carrega
curl http://seudominio.com

# 3. CORS está correto (deve retornar headers Access-Control-*)
curl -I -X OPTIONS http://api.seudominio.com/api/health \
    -H "Origin: http://seudominio.com"

# 4. Nginx está servindo corretamente
sudo nginx -t

# 5. Backend está rodando
sudo systemctl status dom360-backend.service

# 6. Verificar logs
sudo journalctl -u dom360-backend.service -n 50
```

---

## 📊 Comparação Antes/Depois

| Componente | ❌ Antes | ✅ Depois |
|-----------|----------|-----------|
| VITE_API_URL | `http://127.0.0.1:3001` | `http://api.srcjohann.com.br` |
| JWT_SECRET | Default inseguro | Gerado com openssl |
| CORS | `allow_origins=["*"]` | Lista específica de domínios |
| Nginx placeholders | `${VAR}` sem expansão | `envsubst` expande corretamente |
| DB_PASSWORD | Sem quotes | Com quotes |
| Frontend build | URL localhost | URL pública |
| Documentação | Básica | Completa com troubleshooting |

---

## 🎯 Próximos Passos

1. **Configurar DNS** (se usar domínio)
   ```bash
   seudominio.com     A    203.0.113.10
   api.seudominio.com A    203.0.113.10
   ```

2. **Configurar SSL**
   ```bash
   sudo certbot --nginx -d seudominio.com -d api.seudominio.com
   ```

3. **Configurar Backup Automático**
   ```bash
   # Adicionar ao crontab
   0 2 * * * pg_dump -U dom360_user dom360_db_sdk > /backup/db_$(date +\%Y\%m\%d).sql
   ```

4. **Monitoramento**
   - Configurar logs rotation
   - Configurar alertas de erro
   - Monitorar uso de recursos

---

## 📚 Referências

- **Análise Original:** `Claude_Haiku4.5_observations.md`
- **Guia de Deploy:** `docs/DEPLOY_VPS_GUIDE.md`
- **Template Produção:** `.env.production.example`
- **Script de Deploy:** `deploy_vps.sh`
- **Script Nginx:** `setup_nginx.sh`

---

**Status:** ✅ Todas as correções críticas aplicadas  
**Data:** 18 de outubro de 2025  
**Versão:** 2.0.0
