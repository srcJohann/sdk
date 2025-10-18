# Análise Técnica - DOM360 SDK
## Problemas Identificados para Deploy em VPS com IPv4 Público

**Data**: 18 de outubro de 2025  
**Ambiente**: Python FastAPI + React Vite + PostgreSQL  
**Contexto**: Falhas ao conectar da máquina local → VPS com IPv4 público

---

## 🔴 PROBLEMAS CRÍTICOS ENCONTRADOS

### 1. **Configuração de URL Hardcoded no Frontend**
**Severidade**: ALTA  
**Arquivo**: `frontend/app/src/services/dom360ApiService.js` (linha 7)

```javascript
const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001';
```

**Problema**:
- Em `.env`, está configurado: `VITE_API_URL=http://127.0.0.1:3001`
- O valor `127.0.0.1` é localhost (não resolve para o IPv4 público da VPS)
- Quando o frontend é acessado do VPS (pelo IPv4 público), o navegador tenta conectar em `127.0.0.1:3001`, que resolve localmente no cliente
- **Resultado**: Erro de conexão recusada (ERR_REFUSED ou CORS error)

**Solução Necessária**:
```bash
# No .env, use a URL pública do backend:
VITE_API_URL=http://seu-ipv4-vps:3001
# OU com domínio (melhor):
VITE_API_URL=https://api.seudominio.com
```

**Para VPS sem domínio**, você pode usar IP + porta. Mas **melhor prática é usar domínio com HTTPS**.

---

### 2. **Configuração Inconsistente entre Frontend e Nginx**
**Severidade**: ALTA  
**Arquivos**: `.env`, `nginx.conf`, `frontend/app/vite.config.js`

**Problema**:
```ini
# .env
VITE_API_URL=http://127.0.0.1:3001        ← Localhost!
PUBLIC_BACKEND_URL=http://api.srcjohann.com.br    ← Domínio para nginx
PUBLIC_BACKEND_HOST=api.srcjohann.com.br
```

- O `.env` define `PUBLIC_*` URLs (para Nginx), mas o frontend usa `VITE_API_URL` (localhost)
- O Nginx aguarda requisições para `api.srcjohann.com.br`, mas o frontend conecta em `127.0.0.1`
- **Resultado**: Nginx nunca recebe tráfego do frontend; requests vão direto para localhost que não existe no cliente remoto

**Solução**:
```bash
# No .env, sincronizar as URLs:
VITE_API_URL=http://api.srcjohann.com.br
# OU (para VPS sem domínio):
VITE_API_URL=http://SEU_IPV4_VPS:3001
```

---

### 3. **Backend Bind Host = 0.0.0.0 (Correto), mas Frontend Usa 127.0.0.1**
**Severidade**: MÉDIA  
**Arquivo**: `.env`

**Configuração Atual**:
```ini
BACKEND_BIND_HOST=0.0.0.0          ← ✓ Correto (aceita conexões remotas)
BACKEND_BIND_PORT=3001
INTERNAL_BACKEND_HOST=127.0.0.1    ← Usado para verificações locais
VITE_API_URL=http://127.0.0.1:3001 ← ✗ PROBLEMA: Cliente remoto não consegue acessar
```

**Problema**:
- Backend está corretamente vinculado a `0.0.0.0:3001` (aceita conexões de qualquer interface)
- Mas o frontend cliente aponta para `127.0.0.1:3001` (loopback)
- Quando o navegador do cliente remoto tenta conectar em `127.0.0.1`, resolve para o próprio servidor do cliente, não para a VPS

**Solução**:
```ini
# Use o IP público ou domínio no frontend:
VITE_API_URL=http://SEU_IPV4_PUBLICO:3001
# Melhor ainda, com domínio e HTTPS via Nginx:
VITE_API_URL=https://api.seudominio.com
```

---

### 4. **Frontend Build Precisa Regeneração com Variáveis Corretas**
**Severidade**: MÉDIA  
**Arquivo**: `frontend/app/vite.config.js`

**Problema**:
- O `vite.config.js` lê `process.env.FRONTEND_BIND_HOST` (para dev server)
- Mas `VITE_API_URL` é baked into the bundle no build time
- Se você fazer build com `.env` errado (127.0.0.1), essa URL fica hardcoded no bundle

**Solução**:
```bash
# Antes de fazer build, corrigir .env:
nano .env
# Alterar: VITE_API_URL=http://api.seudominio.com

# Depois fazer o build:
cd frontend/app
npm run build
# Isso vai incluir a URL correta no dist/

# Servir o dist/ estático pelo Nginx (melhor para produção)
# Ao invés de usar dev server Vite
```

---

### 5. **Nginx com Placeholders não Expandidos**
**Severidade**: MÉDIA  
**Arquivo**: `nginx.conf`

**Problema**:
```nginx
upstream frontend {
    server ${INTERNAL_FRONTEND_HOST:-localhost}:${INTERNAL_FRONTEND_PORT:-5173};
}
upstream backend {
    server ${INTERNAL_BACKEND_HOST:-localhost}:${INTERNAL_BACKEND_PORT:-3001};
}
server_name ${PUBLIC_FRONTEND_HOST:-srcjohann.com.br};
server_name ${PUBLIC_BACKEND_HOST:-api.srcjohann.com.br};
```

- Esses placeholders `${VARIABLE}` são **shell syntax**, não Nginx syntax
- Nginx não vai interpretar; vai procurar por upstream com nome literal `${INTERNAL_FRONTEND_HOST:-localhost}`
- Você precisa usar `envsubst` para expandir ANTES de copiar para Nginx

**Solução**:
```bash
# Usar setup_nginx.sh (se existir) ou envsubst manualmente:
source .env
envsubst < nginx.conf | sudo tee /etc/nginx/sites-available/dom360
sudo nginx -t
sudo systemctl restart nginx
```

---

### 6. **CORS Permissivo Pode Causar Problemas com Cross-Origin**
**Severidade**: BAIXA (Segurança) / MÉDIA (Funcionalidade)  
**Arquivo**: `backend/server_rbac.py` (linha ~94-102)

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # ← Muito permissivo
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

**Problema**:
- `allow_origins=["*"]` + `allow_credentials=True` é uma combinação inválida
- Navegadores moderno REJEITAM requests com credentials quando `Access-Control-Allow-Origin: *`
- Se o frontend envia JWT no header `Authorization`, requests podem falhar com CORS error

**Solução**:
```python
# Configurar CORS corretamente:
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",
        "http://localhost:3001",
        "https://seudominio.com",
        "https://api.seudominio.com",
        # NÃO adicionar IP de teste aqui — use domínio em produção
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)
```

---

### 7. **Variáveis de Ambiente Não Parseadas Corretamente**
**Severidade**: MÉDIA  
**Arquivo**: `.env`

**Problema**:
```ini
DB_PASSWORD=admin                    ← Sem quotes, pode ter problemas se tiver special chars
VITE_TENANT_ID=00000000-0000-0000-0000-000000000001
VITE_INBOX_ID=00000000-0000-0001-000000000001
```

- Se `DB_PASSWORD` contém caracteres especiais (ex: `p@ssw0rd!`), pode quebrar o parsing
- UUIDs sem problemas, mas boas práticas: sempre usar quotes

**Solução**:
```ini
DB_PASSWORD="admin"
VITE_TENANT_ID="00000000-0000-0000-0000-000000000001"
```

---

### 8. **JWT Secret Padrão Inseguro**
**Severidade**: CRÍTICA  
**Arquivo**: `backend/auth/middleware.py` (linha ~18)

```python
JWT_SECRET = os.getenv("JWT_SECRET", "CHANGE_ME_IN_PRODUCTION_USE_STRONG_SECRET")
```

**Problema**:
- Default secret é uma string óbvia
- Se `JWT_SECRET` não está no `.env`, usa o default
- Qualquer um consegue forjar tokens JWT

**Solução**:
```bash
# Gerar um secret seguro:
openssl rand -base64 32
# Saída: Ex: VmFsdWUgZW52aXJvbm1lbnQgZm9ydGUhCg==

# Adicionar ao .env:
echo 'JWT_SECRET="VmFsdWUgZW52aXJvbm1lbnQgZm9ydGUhCg=="' >> .env
```

---

### 9. **Database Connection Pool Não Responde em VPS**
**Severidade**: MÉDIA  
**Arquivo**: `backend/server_rbac.py` (linha ~51-60)

```python
DATABASE_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': int(os.getenv('DB_PORT', 5432)),
    'database': os.getenv('DB_NAME', 'dom360_db'),
    'user': os.getenv('DB_USER', 'postgres'),
    'password': os.getenv('DB_PASSWORD', ''),
}
```

**Problema**:
- Se PostgreSQL está em outro servidor VPS, `localhost` não vai funcionar
- Firewall pode estar bloqueando porta 5432 entre servidores

**Solução**:
```ini
# .env
DB_HOST=seu-db-server-ip-ou-dominio.com
DB_PORT=5432
# Habilitar na firewall PostgreSQL:
sudo ufw allow from VPS_IP_FRONTEND to any port 5432
```

---

### 10. **Frontend Vite Dev Server Binding Host Pode Ser IPv6**
**Severidade**: BAIXA  
**Arquivo**: `frontend/app/vite.config.js`

```javascript
const host = process.env.FRONTEND_BIND_HOST || '0.0.0.0'
```

**Problema**:
- Em alguns ambientes, `0.0.0.0` pode tentar vincular-se também a IPv6 `[::]`
- Firewall pode estar bloqueando conexões IPv6

**Solução**:
```bash
# Especificar IPv4 explicitamente:
FRONTEND_BIND_HOST="0.0.0.0"
# Ou usar apenas IPv4 em prod com --host flag:
vite --host 0.0.0.0 --port 5173
```

---

## 🟡 PROBLEMAS SECUNDÁRIOS / RECOMENDAÇÕES

### 11. **Falta de Health Checks Robustos**
**Arquivo**: `backend/server_rbac.py`

- `GET /api/health` é implementado?
- Frontend pode estar esperando por um endpoint que não existe

**Recomendação**: Adicionar health check simples
```python
@app.get("/api/health")
async def health():
    return {"status": "ok"}
```

---

### 12. **Logs Podem Não Ser Gerados Corretamente**
**Arquivo**: `start.sh` (linha ~202-203)

```bash
python backend/server_rbac.py > "$BASE_DIR/logs/backend.log" 2>&1 &
```

- Se `logs/` não existir, falha silenciosamente
- Diretório é criado, mas pode ter permissões erradas

**Recomendação**:
```bash
mkdir -p "$BASE_DIR/logs"
chmod 755 "$BASE_DIR/logs"
```

---

### 13. **Sem Validação de Certificados SSL**
**Arquivo**: `frontend/app/src/services/dom360ApiService.js`

- Se usar HTTPS em produção, considere ativar validação de certificado
- Por enquanto está ok para dev, mas em prod, certificados podem ser rejected

---

### 14. **Sem Dockerfile / Containerização**
**Recomendação**: Considere Docker para VPS

- Facilita deploy reproduzível
- Melhor isolamento de recursos
- CI/CD mais simples

---

## ✅ CHECKLIST DE CORREÇÃO PARA VPS

### Passo 1: Corrigir `.env`
```bash
# 1. Determinar IP público ou domínio
IPV4_VPS="203.0.113.10"  # Seu IP público
DOMINIO="seudominio.com"

# 2. Editar .env com URLs corretas
cat > .env << 'EOF'
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=dom360_db
DB_USER=dom360_user
DB_PASSWORD="senha_super_segura_aqui"

# Backend
BACKEND_BIND_HOST=0.0.0.0
BACKEND_BIND_PORT=3001
INTERNAL_BACKEND_HOST=127.0.0.1
INTERNAL_BACKEND_PORT=3001
PUBLIC_BACKEND_URL=https://api.seudominio.com
PUBLIC_BACKEND_HOST=api.seudominio.com

# Frontend
VITE_API_URL=https://api.seudominio.com
FRONTEND_BIND_HOST=0.0.0.0
FRONTEND_BIND_PORT=5173
INTERNAL_FRONTEND_HOST=127.0.0.1
INTERNAL_FRONTEND_PORT=5173
PUBLIC_FRONTEND_URL=https://seudominio.com
PUBLIC_FRONTEND_HOST=seudominio.com

# Security
JWT_SECRET="$(openssl rand -base64 32)"

# Environment
NODE_ENV=production
PYTHON_ENV=production
EOF
```

### Passo 2: Regenerar Nginx Config
```bash
source .env
envsubst < nginx.conf | sudo tee /etc/nginx/sites-available/dom360
sudo nginx -t
sudo systemctl restart nginx
```

### Passo 3: Rebuild Frontend
```bash
cd frontend/app
npm run build
# Agora usa VITE_API_URL correto no bundle
```

### Passo 4: Configurar Firewall
```bash
sudo ufw allow 22/tcp       # SSH
sudo ufw allow 80/tcp       # HTTP (Nginx)
sudo ufw allow 443/tcp      # HTTPS (Nginx)
sudo ufw allow 5432/tcp     # PostgreSQL (se remoto)
sudo ufw enable
```

### Passo 5: Obter SSL com Let's Encrypt
```bash
sudo certbot --nginx -d seudominio.com -d api.seudominio.com
# Certbot atualiza Nginx automaticamente
```

### Passo 6: Configurar DNS
- Criar registro A: `seudominio.com` → `203.0.113.10`
- Criar registro A: `api.seudominio.com` → `203.0.113.10`

### Passo 7: Testar
```bash
# Local
curl http://203.0.113.10/api/health
curl http://203.0.113.10:5173

# Via domínio (após DNS)
curl https://api.seudominio.com/api/health
curl https://seudominio.com
```

---

## 🚨 RESUMO DOS PROBLEMAS

| Problema | Severidade | Impacto | Solução |
|----------|-----------|--------|---------|
| Frontend aponta para 127.0.0.1 | 🔴 CRÍTICA | Conexão recusada | Usar IP/domínio público |
| URLs inconsistentes (.env vs nginx.conf) | 🔴 CRÍTICA | Nginx não recebe tráfego | Sincronizar .env |
| CORS mal configurado | 🟠 ALTA | Requisições bloqueadas | Configurar allow_origins |
| JWT Secret padrão | 🔴 CRÍTICA | Segurança comprometida | Gerar secret aleatório |
| Nginx placeholders não expandidos | 🟠 ALTA | Config inválida | Usar envsubst |
| Database host hardcoded | 🟠 MÉDIA | Falha conexão BD | Usar .env dinamicamente |
| Frontend não faz rebuild | 🟠 MÉDIA | URL antiga persistida | npm run build |
| Sem SSL | 🟠 ALTA | Dados em texto plano | Instalar Certbot |

---

## 📋 PRÓXIMOS PASSOS RECOMENDADOS

1. ✅ **URGENTE**: Corrigir `VITE_API_URL` no `.env`
2. ✅ **URGENTE**: Regenerar Nginx config com `envsubst`
3. ✅ **URGENTE**: Rebuild frontend com `npm run build`
4. ✅ **IMPORTANTE**: Gerar JWT_SECRET seguro
5. ✅ **IMPORTANTE**: Configurar DNS
6. ✅ **IMPORTANTE**: Instalar SSL com Certbot
7. ⚠️ **RECOMENDADO**: Usar PM2 ou systemd para manter processos vivos
8. ⚠️ **RECOMENDADO**: Considerar Docker para melhor isolamento

---

## 📞 TESTES FINAIS

Após aplicar as correções, executar:

```bash
# 1. Testar health check
curl -v https://api.seudominio.com/api/health

# 2. Testar frontend acessível
curl -v https://seudominio.com

# 3. Verificar logs
tail -f logs/backend.log
tail -f logs/frontend.log

# 4. Testar login (se implementado)
curl -X POST https://api.seudominio.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@dom360.com","password":"senha"}'

# 5. Verificar certificado SSL
echo | openssl s_client -servername seudominio.com -connect seudominio.com:443
```

---

**Documento preparado por**: Claude Haiku 4.5  
**Conclusão**: Aplicação está bem estruturada, mas as URLs hardcoded para localhost previnem qualquer conexão remota. Após corrigir o `.env` e o build do frontend, o deploy será bem-sucedido.
