# 🎯 Teste - Gestão de Usuários Master

## ✅ O que foi implementado

Foi adicionada a funcionalidade completa de **Gestão de Usuários** no painel Master Admin:

### 1. Nova Aba "Usuários" 👥
- Localização: `/admin/master/users`
- Acesso exclusivo para usuários com role **MASTER**
- Interface completa para criar, listar, editar e desativar usuários

### 2. Formulário de Criação de Usuários
Campos disponíveis:
- ✅ **Nome Completo** (obrigatório)
- ✅ **Username** (obrigatório)
- ✅ **Email** (obrigatório)
- ✅ **Senha** (obrigatório, mínimo 8 caracteres)
- ✅ **Tenant** (dropdown - obrigatório) - **Define o tenant_id do usuário**
- ✅ **Role** (dropdown):
  - `MASTER` - Administrador Global
  - `TENANT_ADMIN` - Admin do Tenant
  - `TENANT_USER` - Usuário Comum
- ✅ **Status** (checkbox) - Usuário Ativo/Inativo

### 3. Listagem de Usuários
Funcionalidades:
- 📊 **Tabela completa** com todos os usuários
- 🔍 **Filtros**: por Tenant, Role, Status (Ativo/Inativo)
- ✏️ **Edição** inline (botão editar)
- 🗑️ **Desativar usuário** (soft delete)
- 📈 **Badge visual** para roles (cores diferentes)
- 📅 **Data de criação**

### 4. Configuração do Agente IA
Já implementado na aba **"⚙️ Configurações"** (`/admin/master/settings`):
- ✅ **Endpoint do Agente SDR** (URL completa)
- ✅ **API Key** (opcional)
- ✅ **Timeout** (em milissegundos)
- ✅ **Configurações adicionais** (JSON)
- ✅ **Botão "Testar Conexão"** - verifica health do agente

---

## 🚀 Como Testar

### 1. Iniciar o Sistema

```bash
cd /home/johann/SDK
./start.sh
```

**Ou manualmente:**

**Backend:**
```bash
cd /home/johann/SDK
source venv/bin/activate
python backend/server_rbac.py
```

**Frontend:**
```bash
cd /home/johann/SDK/frontend/app
npm run dev
```

---

### 2. Fazer Login como Master

1. Acesse: **http://localhost:5173**
2. Faça login com credenciais Master:
   ```
   Email: master@dom360.local
   Senha: ChangeMe123!
   ```

---

### 3. Acessar Painel Master

Após o login, você será redirecionado para `/admin/master/tenants`.

**Menu lateral terá 4 opções:**
- 🏢 **Tenants**
- 👥 **Usuários** ← NOVA!
- ⚙️ **Configurações**
- 📊 **Métricas**

---

### 4. Testar Gestão de Usuários

#### 4.1 Criar um Novo Usuário

1. Clique na aba **"👥 Usuários"**
2. Clique no botão **"➕ Criar Usuário"**
3. Preencha o formulário:
   ```
   Nome: João Silva
   Username: joaosilva
   Email: joao@example.com
   Senha: Senha123!
   Tenant: Selecione "Acme Corp" (ou outro tenant existente)
   Role: TENANT_USER
   [x] Usuário Ativo
   ```
4. Clique em **"Criar Usuário"**
5. ✅ Usuário deve aparecer na tabela

#### 4.2 Filtrar Usuários

Use os filtros:
- **Por Tenant**: Selecione um tenant específico
- **Por Role**: Filtre MASTER, TENANT_ADMIN, ou TENANT_USER
- **Por Status**: Apenas Ativos ou Inativos

#### 4.3 Editar Usuário (TODO - Interface)

Atualmente o botão ✏️ existe mas precisa implementar o modal de edição.

#### 4.4 Desativar Usuário

1. Clique no botão **🗑️** ao lado de um usuário ativo
2. Confirme a ação
3. ✅ Usuário será desativado (is_active = false)

---

### 5. Testar Configuração do Agente IA

1. Clique na aba **"⚙️ Configurações"**
2. Configure o endpoint do agente:
   ```
   Endpoint: http://seu-agente-ia:8080/api/v1
   API Key: (se necessário)
   Timeout: 30000 (30 segundos)
   ```
3. Clique em **"Testar Conexão"**
4. ✅ Sistema fará um health check no endpoint configurado

---

## 📋 Validações Importantes

### ✅ Permissões (Backend RBAC)

| Ação                          | MASTER | TENANT_ADMIN | TENANT_USER |
|-------------------------------|--------|--------------|-------------|
| Criar usuário Master          | ✅     | ❌           | ❌          |
| Criar usuário Tenant Admin    | ✅     | ❌           | ❌          |
| Criar usuário Tenant User     | ✅     | ✅ (só seu tenant) | ❌   |
| Ver usuários de todos tenants | ✅     | ❌           | ❌          |
| Ver usuários do seu tenant    | ✅     | ✅           | ❌ (só ele mesmo) |
| Editar qualquer usuário       | ✅     | ⚠️ (exceto Masters) | ❌  |
| Desativar usuário             | ✅     | ⚠️ (só Users) | ❌          |

### ✅ Validações do Formulário

- Senha: Mínimo 8 caracteres
- Email: Formato válido
- Tenant: Obrigatório
- Username: Único no sistema
- Email: Único no sistema

---

## 🔧 Verificar Backend

### Endpoints Disponíveis

Todos em `/api/auth/users`:

```bash
# Listar usuários (com filtros)
GET /api/auth/users?tenant_id=UUID&role=MASTER&is_active=true
Authorization: Bearer <token>

# Criar usuário
POST /api/auth/users
Authorization: Bearer <token>
Body:
{
  "name": "João Silva",
  "username": "joaosilva",
  "email": "joao@example.com",
  "password": "Senha123!",
  "tenant_id": "uuid-do-tenant",
  "role": "TENANT_USER",
  "is_active": true
}

# Obter usuário
GET /api/auth/users/{user_id}
Authorization: Bearer <token>

# Atualizar usuário
PUT /api/auth/users/{user_id}
Authorization: Bearer <token>
Body:
{
  "name": "João Silva Jr.",
  "is_active": false
}

# Desativar usuário (soft delete)
DELETE /api/auth/users/{user_id}
Authorization: Bearer <token>
```

### Testar com curl

```bash
# 1. Fazer login
TOKEN=$(curl -s -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"master@dom360.local","password":"ChangeMe123!"}' \
  | jq -r '.access_token')

# 2. Listar usuários
curl -X GET http://localhost:3001/api/auth/users \
  -H "Authorization: Bearer $TOKEN"

# 3. Criar usuário
curl -X POST http://localhost:3001/api/auth/users \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Teste User",
    "username": "testeuser",
    "email": "teste@example.com",
    "password": "Senha123!",
    "tenant_id": "sua-tenant-uuid",
    "role": "TENANT_USER",
    "is_active": true
  }'
```

---

## 🎨 Arquivos Criados

### Frontend
```
frontend/app/src/components/Master/
├── UsersManagement.jsx       # Componente principal
├── UsersManagement.css       # Estilos
└── AdminMasterLayout.jsx     # Atualizado com rota /users
```

### Backend
```
backend/api/
└── auth_routes.py            # Já tinha os endpoints /users
```

### Services
```
frontend/app/src/services/
└── adminService.js           # Adicionadas funções:
                              # - getUsers()
                              # - createUser()
                              # - updateUser()
                              # - deleteUser()
```

---

## 📊 Fluxo de Acesso aos Inboxes

**Importante:** Os usuários não têm associação direta com inboxes individuais.

O acesso funciona assim:
1. Usuário pertence a um **Tenant** (via `tenant_id`)
2. Tenant tem **Inboxes associados** (via tabela `tenant_inboxes`)
3. ✅ **Usuário acessa todos os inboxes do seu tenant**

Para restringir acesso a inboxes específicos, seria necessário criar uma tabela `user_inboxes` no banco de dados.

---

## 🐛 Troubleshooting

### Erro: "User with this email already exists"
- Verifique se o email já está cadastrado
- Use um email único

### Erro: "TENANT_ADMIN cannot assign MASTER role"
- Apenas MASTER pode criar outros MASTERs
- Logue com usuário Master

### Erro: "Cannot find tenant"
- Primeiro crie um tenant na aba "🏢 Tenants"
- Depois associe usuários a esse tenant

### Frontend não mostra aba "Usuários"
- Verifique se está logado como **MASTER**
- Limpe o cache do navegador (Ctrl+Shift+R)
- Verifique o console do navegador (F12)

### Backend retorna 401 Unauthorized
- Token expirado - faça login novamente
- Verifique se o header `Authorization: Bearer <token>` está correto

---

## ✨ Próximos Passos (Opcional)

1. **Modal de Edição de Usuário** - Implementar interface para editar usuários existentes
2. **Tabela `user_inboxes`** - Se precisar associar usuários a inboxes específicos
3. **Busca por nome/email** - Campo de busca na listagem
4. **Paginação real** - Atualmente carrega todos os usuários
5. **Reset de senha** - Funcionalidade para Master resetar senha de usuários
6. **Auditoria** - Registrar quem criou/editou cada usuário

---

## 📚 Documentação Relacionada

- **Backend RBAC**: `/home/johann/SDK/README_RBAC.md`
- **Arquitetura**: `/home/johann/SDK/docs/ARCHITECTURE.md`
- **API**: http://localhost:3001/docs (quando backend estiver rodando)
- **Quick Start**: `/home/johann/SDK/docs/QUICK_START.md`

---

## ✅ Checklist de Teste

- [ ] Login como Master funcionando
- [ ] Navegação para `/admin/master/users` OK
- [ ] Botão "Criar Usuário" abre formulário
- [ ] Criar usuário TENANT_USER com sucesso
- [ ] Criar usuário TENANT_ADMIN com sucesso
- [ ] Filtros funcionando (Tenant, Role, Status)
- [ ] Desativar usuário funciona
- [ ] Mensagens de erro claras
- [ ] Badge de role com cores corretas
- [ ] Configuração do agente IA em `/admin/master/settings`
- [ ] Health check do agente funciona

---

**🎉 Sistema de Gestão de Usuários Master implementado com sucesso!**

Os usuários Master agora podem:
1. ✅ Criar novos usuários
2. ✅ Definir tenant_id (associação ao tenant)
3. ✅ Definir role (MASTER, TENANT_ADMIN, TENANT_USER)
4. ✅ Configurar endpoint do agente IA
5. ✅ Gerenciar tenants e inboxes
6. ✅ Visualizar métricas globais
