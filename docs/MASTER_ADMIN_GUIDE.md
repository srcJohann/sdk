# 🔐 Guia do Administrador Master - DOM360

## 📋 Sumário

1. [Visão Geral](#visão-geral)
2. [Habilitando Usuário MASTER](#habilitando-usuário-master)
3. [Acessando a Interface Admin Master](#acessando-a-interface-admin-master)
4. [Gerenciando Tenants](#gerenciando-tenants)
5. [Configurando SDR Agent](#configurando-sdr-agent)
6. [Visualizando Métricas Globais](#visualizando-métricas-globais)
7. [Boas Práticas e Segurança](#boas-práticas-e-segurança)

---

## 🎯 Visão Geral

O **Admin Master** é uma interface exclusiva para usuários com role `MASTER`, permitindo:

- ✅ Criar e gerenciar **tenants** (organizações)
- ✅ Associar **múltiplas inboxes** a cada tenant
- ✅ Configurar o **endpoint da API do Agente SDR**
- ✅ Testar conectividade do SDR Agent
- ✅ Visualizar **métricas globais** de todos os tenants
- ✅ Auditoria completa de ações administrativas

---

## 🚀 Habilitando Usuário MASTER

### 1. Via Migration (Automático)

O usuário MASTER padrão é criado automaticamente pela migration `004_master_tenant_rbac.sql`:

```
Email: master@dom360.local
Senha: ChangeMe123!
```

**⚠️ IMPORTANTE:** Altere esta senha imediatamente em produção!

### 2. Via SQL Manual

Para promover um usuário existente a MASTER:

```sql
-- Atualizar role de um usuário
UPDATE users 
SET role = 'MASTER' 
WHERE email = 'seu-email@example.com';
```

### 3. Verificar Usuário MASTER

```sql
SELECT id, name, email, role, tenant_id, is_active
FROM users
WHERE role = 'MASTER';
```

---

## 🔑 Acessando a Interface Admin Master

### 1. Login

1. Acesse a aplicação frontend: `http://localhost:5173`
2. Faça login com as credenciais MASTER
3. Após login bem-sucedido, você será redirecionado para a área principal

### 2. Navegação

- A interface Master está disponível em: **`/admin/master`**
- O menu lateral aparece **somente para usuários MASTER**
- Usuários não-MASTER recebem **403 Forbidden** ao tentar acessar

### 3. Estrutura de Rotas

```
/admin/master/
├── tenants     → Gerenciar Tenants
├── settings    → Configurações Master (SDR Endpoint)
└── metrics     → Métricas Globais
```

---

## 🏢 Gerenciando Tenants

### Criar Novo Tenant

1. Acesse **Admin Master → Tenants**
2. Clique em **"+ Criar Tenant"**
3. Preencha o formulário:

   **Campos Obrigatórios:**
   - **Nome**: Nome da organização (ex: "Empresa ABC")
   - **Slug**: Identificador único em URL (ex: "empresa-abc")
     - Apenas letras minúsculas, números e hífens
     - Gerado automaticamente a partir do nome

   **Campos Opcionais (Integração Chatwoot):**
   - **ID da Conta Chatwoot**: Número da conta no Chatwoot
   - **Nome da Conta Chatwoot**: Nome descritivo
   - **Host Chatwoot**: URL completa (ex: `https://chatwoot.example.com`)

4. Clique em **"Criar Tenant"**

### Listar e Filtrar Tenants

- **Busca**: Digite nome ou slug na barra de pesquisa
- **Filtro de Status**:
  - Todos
  - Ativos
  - Inativos

### Associar Inboxes a um Tenant

1. Na lista de tenants, clique no ícone **📥** (Gerenciar Inboxes)
2. Modal exibe todos os inboxes disponíveis no sistema
3. **Selecionar inboxes**:
   - Marque/desmarque checkboxes individuais
   - Use "Selecionar todos" / "Desmarcar todos"
   - Campo de busca para filtrar inboxes
4. Clique em **"Salvar Associações"**

**Comportamento:**
- Associações antigas são substituídas pelas novas seleções
- Apenas inboxes ativos são exibidos
- A ação é auditada no banco de dados

### Ativar/Desativar Tenant

- Clique no ícone de status (🔴 ou 🟢) na linha do tenant
- **Desativar tenant**: Usuários não conseguem mais acessar
- **Reativar tenant**: Restaura o acesso

---

## ⚙️ Configurando SDR Agent

### 1. Acessar Configurações

**Admin Master → Configurações**

### 2. Configurar Endpoint

**SDR Agent Endpoint:**
```
http://localhost:8000
```
- URL base da API do Agente SDR
- Validação automática de formato (http:// ou https://)

### 3. Testar Conexão

1. Preencha o endpoint
2. Clique em **"🔍 Testar Conexão"**
3. O sistema chama `GET {endpoint}/health`
4. Resultados:
   - ✅ **Saudável**: Exibe latência em ms
   - ❌ **Falha**: Exibe mensagem de erro

### 4. Configurar Timeout

**Timeout (ms):** Tempo máximo de espera para chamadas ao SDR Agent
- Padrão: `30000` (30 segundos)
- Mínimo: `1000` (1 segundo)
- Máximo: `120000` (2 minutos)

### 5. Server Config (Avançado)

Configuração em JSON para limites de tokens, retry policy, rate limits, etc.

**Exemplo:**
```json
{
  "token_limits": {
    "max_input_tokens": 100000,
    "max_output_tokens": 4096,
    "default_temperature": 0.7
  },
  "retry_policy": {
    "max_retries": 3,
    "backoff_multiplier": 2,
    "initial_delay_ms": 1000
  },
  "providers": {
    "primary": "anthropic",
    "fallback": "openai"
  },
  "rate_limits": {
    "requests_per_minute": 60,
    "tokens_per_minute": 100000
  }
}
```

**Validação:**
- Editor valida JSON em tempo real
- Erros de sintaxe impedem salvamento

### 6. Salvar Configurações

1. Clique em **"Salvar Configurações"**
2. Feedback de sucesso/erro é exibido
3. Configurações são aplicadas imediatamente

---

## 📊 Visualizando Métricas Globais

### 1. Acessar Dashboard

**Admin Master → Métricas**

### 2. Aplicar Filtros

- **Tenant**: Selecione um tenant específico ou "Todos os tenants"
- **Data Início**: YYYY-MM-DD
- **Data Fim**: YYYY-MM-DD
- **Limpar**: Remove todos os filtros

### 3. Métricas Disponíveis

**Cards exibidos:**

| Métrica | Descrição |
|---------|-----------|
| **Total Tenants** | Número total de tenants (ativos/inativos) |
| **Total Inboxes** | Número de inboxes no sistema |
| **Conversas** | Total de conversas em todos os tenants |
| **Mensagens** | Total de mensagens enviadas |
| **Tokens Consumidos** | Soma de input + output + cached tokens |
| **Latência Média** | Tempo médio de resposta do agente (ms) |

### 4. Interpretação

- **Valores formatados** em pt-BR (ex: 1.234.567)
- **Período**: Exibido no rodapé do dashboard
- **Atualização**: Automática ao alterar filtros

---

## 🛡️ Boas Práticas e Segurança

### Gestão de Acesso

✅ **Altere a senha padrão do usuário MASTER imediatamente**
```sql
-- Gerar novo hash de senha (Python bcrypt)
import bcrypt
password = "SuaSenhaSegura123!"
hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
print(hash.decode('utf-8'))

-- Atualizar no banco
UPDATE users 
SET password_hash = '$2b$12$novo_hash_aqui'
WHERE email = 'master@dom360.local';
```

✅ **Limite o número de usuários MASTER**
- Apenas 1-2 usuários devem ter esta role
- Use `TENANT_ADMIN` para gerenciamento operacional

✅ **Monitore logs de auditoria**
```sql
SELECT * FROM audit_logs
WHERE user_role = 'MASTER'
ORDER BY created_at DESC
LIMIT 50;
```

### Configuração do SDR Endpoint

✅ **Use HTTPS em produção**
```
https://sdr-agent.example.com
```

✅ **Configure API Keys** (se necessário)
- Adicione `sdr_agent_api_key` na tabela `master_settings`
- Backend deve enviar header `Authorization: Bearer {key}`

✅ **Teste regularmente**
- Use o botão "Testar Conexão" semanalmente
- Configure health check automático

### Gerenciamento de Tenants

✅ **Nomeação consistente**
- Use slugs descritivos e únicos
- Evite caracteres especiais

✅ **Desative tenants inativos**
- Mantém dados históricos
- Impede novos acessos

✅ **Backup de associações inbox-tenant**
```sql
SELECT ti.tenant_id, t.name AS tenant_name, 
       ti.inbox_id, i.name AS inbox_name
FROM tenant_inboxes ti
JOIN tenants t ON t.id = ti.tenant_id
JOIN inboxes i ON i.id = ti.inbox_id
WHERE ti.is_active = TRUE;
```

### Monitoramento

✅ **Verifique métricas diariamente**
- Picos anormais de tokens/mensagens
- Latências acima de 5 segundos
- Tenants inativos com consumo

✅ **Configure alertas**
```sql
-- Exemplo: Tenants com alto consumo
SELECT t.name, SUM(cd.total_tokens) AS tokens
FROM consumption_inbox_daily cd
JOIN tenants t ON t.id = cd.tenant_id
WHERE cd.date_window >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY t.name
HAVING SUM(cd.total_tokens) > 1000000
ORDER BY tokens DESC;
```

---

## 🆘 Solução de Problemas

### Erro: "403 Forbidden" ao acessar Admin Master

**Causa:** Usuário não tem role MASTER

**Solução:**
```sql
-- Verificar role atual
SELECT role FROM users WHERE email = 'seu-email@example.com';

-- Promover a MASTER (se autorizado)
UPDATE users SET role = 'MASTER' WHERE email = 'seu-email@example.com';
```

### Erro: "Master settings not initialized"

**Causa:** Tabela `master_settings` vazia

**Solução:**
```sql
INSERT INTO master_settings (sdr_agent_endpoint, sdr_agent_timeout_ms)
VALUES ('http://localhost:8000', 30000);
```

### SDR Health Check Falha

**Possíveis causas:**
1. **Endpoint incorreto**: Verifique URL
2. **SDR Agent offline**: Inicie o serviço
3. **Firewall**: Libere porta do SDR
4. **Timeout curto**: Aumente timeout_ms

**Debug:**
```bash
# Teste manual
curl http://localhost:8000/health

# Esperado: {"status":"ok"}
```

### Inboxes não aparecem no modal

**Causa:** Nenhum inbox ativo ou erro de permissão

**Solução:**
```sql
-- Verificar inboxes ativos
SELECT id, name, is_active FROM inboxes;

-- Ativar inbox
UPDATE inboxes SET is_active = TRUE WHERE id = 'uuid-here';
```

---

## 📞 Suporte

- **Documentação completa**: `/docs`
- **Logs do backend**: `backend/logs/`
- **Audit trail**: Tabela `audit_logs`
- **Issues**: GitHub repository

---

## 🔄 Changelog

### v2.0.0 (2025-10-15)
- ✅ Interface Admin Master completa
- ✅ Gerenciamento de tenants e inboxes
- ✅ Configuração SDR Agent com health check
- ✅ Dashboard de métricas globais
- ✅ RLS e políticas de segurança
- ✅ Auditoria de ações MASTER

---

**Desenvolvido pela equipe DOM360** | **Última atualização:** 15/10/2025
