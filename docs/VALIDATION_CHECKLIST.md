# ✅ Checklist de Validação - UI Master + Backend Multi-Tenant

## 🎯 Como usar este checklist

Marque cada item após testar e validar. Este documento serve como critério de aceite (DoD).

---

## 📦 1. Backend - APIs

### Tenants
- [ ] `GET /api/admin/tenants` retorna lista de tenants
- [ ] `POST /api/admin/tenants` cria novo tenant com sucesso
- [ ] Validação de slug único funciona (409 Conflict)
- [ ] `GET /api/admin/tenants/{id}` retorna tenant específico
- [ ] `PUT /api/admin/tenants/{id}` atualiza tenant
- [ ] Filtro `is_active` funciona corretamente

### Inboxes
- [ ] `GET /api/admin/inboxes` lista todos inboxes
- [ ] `GET /api/admin/tenants/{id}/inboxes` retorna inboxes do tenant
- [ ] `POST /api/admin/tenants/{id}/inboxes` associa inbox único
- [ ] `POST /api/admin/tenants/{id}/inboxes/bulk` associa múltiplos inboxes
- [ ] `DELETE /api/admin/tenants/{id}/inboxes/{inboxId}` desassocia inbox
- [ ] Associação em massa substitui inboxes antigos

### Master Settings
- [ ] `GET /api/admin/master-settings` retorna configurações
- [ ] `PUT /api/admin/master-settings` atualiza endpoint SDR
- [ ] `POST /api/admin/master-settings/health-check` testa conectividade
- [ ] Validação de URL no `sdr_agent_endpoint` funciona
- [ ] Validação de JSON no `server_config` funciona
- [ ] Health check retorna latência correta

### Métricas
- [ ] `GET /api/admin/metrics` retorna métricas globais
- [ ] Filtros `from_date` e `to_date` funcionam
- [ ] Métricas refletem dados corretos (tenants, inboxes, conversas, tokens)

### Segurança
- [ ] Todas as rotas `/api/admin/*` retornam **403** para não-MASTER
- [ ] JWT token válido é aceito
- [ ] JWT token expirado retorna **401**
- [ ] RLS funciona (MASTER vê tudo, outros apenas seu tenant)

---

## 🎨 2. Frontend - Componentes

### Login & Autenticação
- [ ] Login com credenciais MASTER funciona
- [ ] Token é armazenado no localStorage
- [ ] Usuário é redirecionado após login
- [ ] Logout limpa token e redireciona

### Layout Master
- [ ] Rota `/admin/master` é acessível apenas para MASTER
- [ ] Usuário não-MASTER vê "Access Denied"
- [ ] Menu lateral exibe:
  - 🏢 Tenants
  - ⚙️ Configurações
  - 📊 Métricas
- [ ] Navegação entre abas funciona

### Tenants List
- [ ] Lista carrega tenants automaticamente
- [ ] Busca por nome/slug funciona
- [ ] Filtro de status (todos/ativos/inativos) funciona
- [ ] Paginação funciona (anterior/próxima)
- [ ] Botão "Criar Tenant" abre modal
- [ ] Botão 📥 (Gerenciar Inboxes) abre modal correto
- [ ] Botão 🔴/🟢 (Ativar/Desativar) altera status

### Create Tenant Form
- [ ] Validação de nome obrigatório funciona
- [ ] Validação de slug (apenas `[a-z0-9-]`) funciona
- [ ] Slug é gerado automaticamente ao digitar nome
- [ ] Validação de email Chatwoot funciona
- [ ] Validação de URL Chatwoot funciona
- [ ] Formulário envia dados corretamente
- [ ] Feedback de sucesso é exibido
- [ ] Feedback de erro é exibido (ex: slug duplicado)
- [ ] Botão "Cancelar" fecha modal

### Manage Inboxes Modal
- [ ] Modal carrega todos inboxes disponíveis
- [ ] Busca por nome de inbox funciona
- [ ] Checkboxes selecionam/desselecionam inboxes
- [ ] "Selecionar todos" marca todos filtrados
- [ ] "Desmarcar todos" desmarca todos filtrados
- [ ] Counter exibe número de selecionados corretamente
- [ ] Botão "Salvar" envia associações
- [ ] Feedback de sucesso é exibido
- [ ] Modal fecha após salvar
- [ ] Lista de tenants é atualizada após salvar

### Master Settings Form
- [ ] Form carrega configurações existentes
- [ ] Campo `sdr_agent_endpoint` valida URL
- [ ] Campo `timeout_ms` aceita apenas números
- [ ] Editor JSON valida sintaxe em tempo real
- [ ] Botão "Testar Conexão" chama health check
- [ ] Status saudável exibe latência em ms
- [ ] Status falha exibe mensagem de erro
- [ ] Botão "Salvar" envia dados corretamente
- [ ] Feedback de sucesso é exibido

### Master Metrics Dashboard
- [ ] Cards carregam métricas automaticamente
- [ ] Select de tenant lista todos tenants
- [ ] Filtros de data funcionam
- [ ] Botão "Limpar" reseta filtros
- [ ] Valores são formatados em PT-BR (1.234.567)
- [ ] Métricas são atualizadas ao alterar filtros

---

## 🔒 3. Segurança e RBAC

### Feature Gating
- [ ] Menu "Admin Master" **não aparece** para usuários não-MASTER
- [ ] Navegação direta para `/admin/master` redireciona não-MASTER
- [ ] `MasterRoute` guard funciona corretamente

### Database (RLS)
- [ ] MASTER vê todos os tenants
- [ ] TENANT_ADMIN vê apenas seu tenant
- [ ] TENANT_USER vê apenas seu tenant
- [ ] Política `master_settings_master_only` bloqueia não-MASTER

### Audit Logs
- [ ] Criação de tenant é registrada em `audit_logs`
- [ ] Associação de inboxes é registrada
- [ ] Atualização de settings é registrada
- [ ] Logs incluem `user_id`, `action`, `resource_type`, `resource_id`
- [ ] IP address é capturado quando disponível

---

## 🧪 4. Testes de Integração

### Fluxo Completo: Criar Tenant
1. [ ] Login como MASTER
2. [ ] Acessar `/admin/master/tenants`
3. [ ] Clicar em "Criar Tenant"
4. [ ] Preencher nome: "Teste ABC"
5. [ ] Slug gerado: "teste-abc"
6. [ ] Submeter formulário
7. [ ] Tenant aparece na lista
8. [ ] Audit log registra ação

### Fluxo Completo: Associar Inboxes
1. [ ] Na lista, clicar em 📥 do tenant criado
2. [ ] Modal exibe inboxes disponíveis
3. [ ] Selecionar 2-3 inboxes
4. [ ] Clicar em "Salvar Associações"
5. [ ] Sucesso exibido
6. [ ] Reabrir modal: inboxes selecionados estão marcados
7. [ ] Audit log registra ação

### Fluxo Completo: Configurar SDR
1. [ ] Acessar `/admin/master/settings`
2. [ ] Alterar endpoint para `http://localhost:8000`
3. [ ] Clicar em "Testar Conexão"
4. [ ] Health check retorna status
5. [ ] Salvar configurações
6. [ ] Sucesso exibido
7. [ ] Recarregar página: configurações persistem

### Fluxo Completo: Visualizar Métricas
1. [ ] Acessar `/admin/master/metrics`
2. [ ] Verificar métricas iniciais
3. [ ] Selecionar tenant específico
4. [ ] Métricas são atualizadas
5. [ ] Selecionar período de datas
6. [ ] Métricas refletem filtro

---

## 🌐 5. Responsividade

### Desktop (>1024px)
- [ ] Layout Master exibe sidebar fixa
- [ ] Tabelas são legíveis
- [ ] Modais não ultrapassam viewport

### Tablet (768px - 1024px)
- [ ] Layout se adapta
- [ ] Tabelas têm scroll horizontal se necessário
- [ ] Formulários são usáveis

### Mobile (<768px)
- [ ] Sidebar ocupa largura total
- [ ] Tabelas scrollam horizontalmente
- [ ] Modais ocupam tela inteira
- [ ] Botões são clicáveis (touch-friendly)

---

## 📊 6. Performance

- [ ] Lista de tenants carrega em <2s (100 tenants)
- [ ] Lista de inboxes carrega em <2s (500 inboxes)
- [ ] Health check retorna em <5s
- [ ] Métricas globais carregam em <3s
- [ ] Nenhum console.error no navegador

---

## 📚 7. Documentação

- [ ] `MASTER_ADMIN_GUIDE.md` está completo
- [ ] Instruções de login MASTER estão claras
- [ ] Exemplos de SQL para promover usuários
- [ ] Troubleshooting covers common issues
- [ ] Changelog atualizado

---

## ✅ 8. Critérios de Aceitação (DoD)

- [ ] Usuário MASTER consegue criar tenant e associar inboxes
- [ ] Usuário MASTER consegue configurar `sdr_agent_endpoint` e testar
- [ ] Usuário não-MASTER **não** consegue acessar rotas/telas Master (403)
- [ ] RLS está ativo e efetivo
- [ ] Painel de métricas exibe dados corretos
- [ ] APIs possuem validação robusta (200/201/400/403/422/500)
- [ ] Todos os testes manuais passam
- [ ] Documentação está completa

---

## 🐛 Issues Encontrados

Liste aqui problemas encontrados durante a validação:

1. [ ] **Issue:** _______________  
   **Gravidade:** [ ] Crítico [ ] Alto [ ] Médio [ ] Baixo  
   **Resolução:** _______________

2. [ ] **Issue:** _______________  
   **Gravidade:** [ ] Crítico [ ] Alto [ ] Médio [ ] Baixo  
   **Resolução:** _______________

---

## 📝 Notas Finais

**Testado por:** _______________  
**Data:** _______________  
**Ambiente:** [ ] Dev [ ] Staging [ ] Prod  
**Status:** [ ] ✅ Aprovado [ ] ⚠️ Com Ressalvas [ ] ❌ Reprovado  

**Comentários:**
```
[Adicione observações, sugestões ou melhorias aqui]
```

---

**Assinatura do Revisor:** _______________  
**Data:** _______________
