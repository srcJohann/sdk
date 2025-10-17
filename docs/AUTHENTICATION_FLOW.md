# Fluxo de Autenticação DOM360 - Chat SDR

## Visão Geral

O sistema garante que **todas as requisições ao backend** (especialmente `/api/chat`) incluam o JWT token de autenticação. Este documento descreve como funciona o fluxo e as garantias implementadas.

## Componentes do Fluxo de Autenticação

### 1. AuthContext (`frontend/app/src/contexts/AuthContext.jsx`)

**Responsabilidades:**
- Gerenciar estado de autenticação (user, token)
- Armazenar JWT em `localStorage` (remember me) ou `sessionStorage`
- Validar expiração do token ao carregar
- Fornecer função `login()` que:
  - Chama `POST /api/auth/login`
  - Armazena o `access_token` retornado
  - Decodifica o JWT e popula objeto `user`
- Fornecer função `logout()` que limpa token e estado
- Fornecer helper `getAuthHeaders()` que retorna `{ Authorization: 'Bearer <token>' }`

**Storage Strategy:**
```javascript
// Login com "remember me" = true
localStorage.setItem('dom360_auth_token', token);

// Login sem "remember me" (sessão)
sessionStorage.setItem('dom360_auth_token', token);
```

### 2. DOM360ApiService (`frontend/app/src/services/dom360ApiService.js`)

**Garantias de autenticação implementadas:**

#### Busca automática de token em TODA requisição
```javascript
// No método fetch(), SEMPRE tenta obter token
const token = localStorage.getItem(TOKEN_KEY) || sessionStorage.getItem(TOKEN_KEY);
if (token) {
    defaultHeaders['Authorization'] = `Bearer ${token}`;
}
```

#### Warning quando token não está disponível
```javascript
// Alerta no console se endpoint precisa de auth mas não tem token
if (!token && !endpoint.includes('/health') && !endpoint.includes('/login')) {
    console.warn(`No JWT token found for ${endpoint}. Request may fail with 401/403.`);
}
```

#### Tratamento específico de erros 401/403
```javascript
// Response 401: Token inválido/expirado
if (response.status === 401) {
    throw new Error('Authentication required: Please login again');
}

// Response 403: Token válido mas sem permissões
if (response.status === 403) {
    throw new Error('Access denied: Insufficient permissions');
}
```

### 3. useChatWithAgent Hook (`frontend/app/src/hooks/useChatWithAgent.js`)

**Uso do apiService:**
- Chama `apiService.sendMessage()` para enviar mensagens
- Captura erros e atualiza estado `error` para exibir ao usuário
- Remove mensagem temporária em caso de falha

**Fluxo de erro visível ao usuário:**
1. Usuário envia mensagem
2. Hook adiciona mensagem temporária na UI
3. Se falhar (401/403): remove mensagem temporária e mostra `error`
4. Componente `ChatContainer` exibe banner de erro

### 4. App.jsx - Proteção de Rotas

**Verificação antes de renderizar Chat:**
```javascript
if (!isAuthenticated) {
    return <Routes><Route path="*" element={<LoginPage onLogin={login} />} /></Routes>;
}
```

- Se `isAuthenticated = false`, redireciona para login
- Usuário **não consegue** acessar Chat SDR sem estar autenticado

## Fluxo Completo: Login → Chat → Envio de Mensagem

### 1. Usuário faz login
```
LoginPage → AuthContext.login(email, password)
  ↓
POST /api/auth/login
  ↓
Recebe: { access_token, user }
  ↓
localStorage.setItem('dom360_auth_token', access_token)
  ↓
AuthContext atualiza: isAuthenticated = true, user = { ... }
  ↓
App.jsx re-renderiza e mostra interface principal
```

### 2. Usuário acessa Chat SDR
```
App.jsx verifica: isAuthenticated === true ✓
  ↓
Renderiza ChatContainer
  ↓
useChatWithAgent inicializa apiService com tenantId, inboxId
```

### 3. Usuário envia mensagem
```
ChatContainer → useChatWithAgent.sendMessage("Olá")
  ↓
apiService.sendMessage(...)
  ↓
apiService.fetch('/api/chat', { method: 'POST', body: ... })
  ↓
Busca token: localStorage.getItem('dom360_auth_token')
  ↓
Adiciona headers:
  - Authorization: Bearer <token>
  - X-Tenant-ID: <tenant_id>
  - X-Inbox-ID: <inbox_id>
  - Content-Type: application/json
  ↓
POST http://localhost:3001/api/chat
  ↓
Backend valida JWT (Depends(get_current_user))
  ↓
Se válido: processa mensagem, chama agente, retorna resposta
Se inválido: retorna 401/403
  ↓
Frontend:
  - Sucesso: atualiza mensagens na UI
  - Erro 401/403: remove mensagem temp, exibe erro
```

## Verificações de Segurança Implementadas

### Frontend
- ✅ Token buscado automaticamente em todas as requisições
- ✅ Warning no console se token não disponível
- ✅ Tratamento específico de 401 (session expired) e 403 (permission denied)
- ✅ Redirecionamento para login se não autenticado
- ✅ Estado de erro exibido ao usuário em caso de falha

### Backend (`server_rbac.py`)
- ✅ Endpoint `/api/chat` exige `Depends(get_current_user)`
- ✅ JWT decodificado e validado via `HTTPBearer` scheme
- ✅ Usuário inativo retorna 403 "User account is inactive"
- ✅ Tenant mismatch retorna 403 "Access denied to tenant X"
- ✅ Token expirado retorna 401 "Token expired"
- ✅ Token inválido retorna 401 "Invalid authentication credentials"
- ✅ Headers logados para debugging (temporário)

## Casos de Erro e Tratamento

| Cenário | Resposta Backend | Comportamento Frontend |
|---------|-----------------|----------------------|
| Sem token | 403 "Not authenticated" | Erro exibido: "Authentication required" |
| Token expirado | 401 "Token expired" | Erro exibido: "Please login again" |
| Token inválido | 401 "Invalid credentials" | Erro exibido: "Authentication required" |
| Usuário inativo | 403 "User account is inactive" | Erro exibido: "Access denied" |
| Tenant mismatch | 403 "Access denied to tenant X" | Erro exibido: "Access denied" |
| Inbox ID inválido | 400 "X-Inbox-ID must be integer" | Erro exibido com detalhe do backend |

## Como Verificar que JWT Está Sendo Enviado

### 1. Abrir DevTools (F12) → Network
- Filtrar por: `/api/chat`
- Click em uma requisição
- Aba "Headers" → "Request Headers"
- Procurar: `authorization: Bearer eyJhbGc...`

### 2. Console do Browser
- Se token não estiver disponível, verá warning:
  ```
  [API Service] No JWT token found for /api/chat. Request may fail with 401/403.
  ```

### 3. Backend Logs (temporário)
- Após enviar mensagem, logs do uvicorn mostram:
  ```
  INFO: Incoming /api/chat request headers: {'authorization': 'Bearer eyJ...', ...}
  ```

## Troubleshooting

### "403 Not authenticated"
**Causa:** Token JWT não está sendo enviado ou não está no storage.

**Solução:**
1. Fazer logout e login novamente
2. Verificar no console do browser: `localStorage.getItem('dom360_auth_token')`
3. Se retornar `null`, fazer login
4. Se retornar token mas ainda 403, verificar se token não está expirado:
   ```javascript
   import { jwtDecode } from 'jwt-decode';
   const token = localStorage.getItem('dom360_auth_token');
   const decoded = jwtDecode(token);
   console.log('Expires:', new Date(decoded.exp * 1000));
   ```

### "401 Token expired"
**Causa:** Token JWT expirado (default: 24h).

**Solução:** Fazer login novamente.

### "403 Access denied to tenant X"
**Causa:** Header `X-Tenant-ID` não corresponde ao tenant do usuário no token, e usuário não é MASTER.

**Solução:** 
- Se você é MASTER, pode acessar qualquer tenant
- Se não, use o `X-Tenant-ID` do seu próprio tenant (disponível em `user.tenantId`)

### "400 X-Inbox-ID must be a valid integer"
**Causa:** Inbox ID enviado não é um número inteiro válido.

**Solução:** Após migration 005, inbox_id deve ser INTEGER (ex: 27, não UUID).

## Testes Manuais

### 1. Teste sem autenticação (deve falhar)
```bash
curl -i -X POST http://localhost:3001/api/chat \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: <tenant_uuid>" \
  -H "X-Inbox-ID: 27" \
  -d '{"message":"Test","user_phone":"+5511999999999"}'

# Esperado: 403 "Not authenticated"
```

### 2. Teste com autenticação (deve funcionar)
```bash
# Obter token
TOKEN=$(curl -s -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"master@dom360.local","password":"SuaSenha"}' | jq -r .access_token)

# Testar chat
curl -i -X POST http://localhost:3001/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Tenant-ID: <tenant_uuid>" \
  -H "X-Inbox-ID: 27" \
  -d '{"message":"Test","user_phone":"+5511999999999"}'

# Esperado: 200 OK com resposta do agente
```

## Conclusão

O sistema está configurado para **SEMPRE** enviar o JWT token nas requisições ao backend. As garantias são:

1. ✅ Token armazenado após login (localStorage ou sessionStorage)
2. ✅ Token buscado automaticamente em toda requisição do `dom360ApiService`
3. ✅ Warnings no console se token não disponível
4. ✅ Tratamento de erros 401/403 com mensagens claras
5. ✅ Backend valida JWT e retorna erros apropriados
6. ✅ Frontend exibe erros ao usuário e remove mensagens temporárias

Próximos passos (opcionais):
- Implementar refresh token para renovação automática
- Adicionar interceptor global para logout em 401
- Adicionar testes automatizados de autenticação
