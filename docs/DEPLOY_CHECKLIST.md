# ✅ Checklist de Deploy: Master & Tenant RBAC

## 🔐 Segurança Pré-Deploy

### Credenciais

- [ ] Alterar senha do usuário MASTER (nunca usar `ChangeMe123!`)
- [ ] Gerar JWT_SECRET forte (mínimo 32 caracteres aleatórios)
  ```bash
  python3 -c "import secrets; print(secrets.token_urlsafe(32))"
  ```
- [ ] Configurar variáveis de ambiente via secrets manager (não commitar `.env`)
- [ ] Habilitar SSL/TLS para conexões PostgreSQL em produção
- [ ] Configurar firewall para restringir acesso ao banco

### PostgreSQL

- [ ] Criar usuário específico da aplicação (não usar `postgres`)
  ```sql
  CREATE USER dom360_app WITH PASSWORD 'senha_forte_aqui';
  GRANT USAGE ON SCHEMA public TO dom360_app;
  GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO dom360_app;
  ```
- [ ] Habilitar SSL: `ssl = on` em `postgresql.conf`
- [ ] Configurar `pg_hba.conf` para autenticação via certificado
- [ ] Backup automatizado configurado
- [ ] Point-in-time recovery (PITR) configurado

### RLS

- [ ] Verificar que RLS está habilitado em todas as tabelas:
  ```sql
  SELECT tablename, rowsecurity 
  FROM pg_tables 
  WHERE schemaname = 'public' AND rowsecurity = false;
  ```
- [ ] Testar isolation entre tenants:
  ```sql
  SET app.tenant_id = 'tenant-1';
  SELECT COUNT(*) FROM messages;  -- Deve retornar apenas do tenant-1
  ```

### JWT

- [ ] Configurar expiração adequada (`JWT_EXPIRATION_HOURS=24`)
- [ ] Implementar refresh tokens (TODO se necessário)
- [ ] Configurar blacklist de tokens revogados (Redis)
- [ ] Validar issuer e audience no JWT

---

## 🚀 Deploy Backend

### Ambiente

- [ ] Python 3.9+ instalado
- [ ] Virtualenv configurado
  ```bash
  python3 -m venv venv
  source venv/bin/activate
  ```
- [ ] Dependências instaladas: `pip install -r requirements.txt`
- [ ] `.env` configurado com variáveis de produção

### Migrations

- [ ] Aplicar migração 004_master_tenant_rbac.sql
  ```bash
  psql -U dom360_app -d dom360_db_prod -f database/004_master_tenant_rbac.sql
  ```
- [ ] Verificar schema_migrations:
  ```sql
  SELECT * FROM schema_migrations ORDER BY version DESC LIMIT 5;
  ```

### Servidor

- [ ] Configurar Uvicorn para produção:
  ```bash
  uvicorn server_rbac:app \
    --host 0.0.0.0 \
    --port 3001 \
    --workers 4 \
    --log-level info \
    --access-log \
    --proxy-headers \
    --forwarded-allow-ips='*'
  ```
- [ ] Configurar systemd service (ver exemplo abaixo)
- [ ] Configurar Nginx como reverse proxy (SSL termination)
- [ ] Limitar CORS para domínios específicos:
  ```python
  app.add_middleware(
      CORSMiddleware,
      allow_origins=["https://app.dom360.com"],  # Específico!
      allow_credentials=True,
      allow_methods=["GET", "POST", "PUT", "DELETE"],
      allow_headers=["*"],
  )
  ```

### Monitoring

- [ ] Configurar logs estruturados (JSON)
- [ ] Enviar logs para Elasticsearch/Splunk/CloudWatch
- [ ] Configurar alertas para erros 5xx
- [ ] Monitorar latência de endpoints
- [ ] Configurar health checks:
  ```bash
  curl http://localhost:3001/api/health
  ```

---

## 🌐 Deploy Frontend

### Build

- [ ] Atualizar `VITE_API_URL` para produção:
  ```bash
  VITE_API_URL=https://api.dom360.com npm run build
  ```
- [ ] Minificar e otimizar assets
- [ ] Gerar source maps (se permitido)

### Hosting

- [ ] Deploy para CDN (Cloudflare, AWS CloudFront, Vercel)
- [ ] Configurar HTTPS obrigatório
- [ ] Configurar cache headers:
  - HTML: `Cache-Control: no-cache`
  - JS/CSS: `Cache-Control: max-age=31536000, immutable`
- [ ] Configurar CSP (Content Security Policy):
  ```
  Content-Security-Policy: default-src 'self'; connect-src https://api.dom360.com
  ```

### Environment

- [ ] Remover console.log em produção
- [ ] Configurar error boundary para React
- [ ] Implementar Sentry/LogRocket para error tracking

---

## 🗄️ PostgreSQL Otimizações

### Índices

- [ ] Verificar índices criados:
  ```sql
  SELECT 
      tablename, 
      indexname, 
      indexdef 
  FROM pg_indexes 
  WHERE schemaname = 'public' 
  ORDER BY tablename;
  ```
- [ ] Criar índices adicionais se necessário:
  ```sql
  -- Para queries frequentes
  CREATE INDEX CONCURRENTLY idx_messages_tenant_inbox 
  ON messages(tenant_id, inbox_id, created_at DESC);
  ```

### Partições

- [ ] Criar partições futuras (messages, audit_logs):
  ```sql
  SELECT create_monthly_partitions('messages', 12);  -- Próximos 12 meses
  SELECT create_monthly_partitions('audit_logs', 12);
  ```
- [ ] Configurar job para criar partições automaticamente:
  ```bash
  # Cron job mensal
  0 0 1 * * psql -U dom360_app -d dom360_db_prod -c "SELECT create_monthly_partitions('messages', 3)"
  ```

### Vacuuming

- [ ] Habilitar autovacuum:
  ```sql
  ALTER TABLE messages SET (autovacuum_enabled = true);
  ```
- [ ] Configurar `autovacuum_vacuum_scale_factor` adequado
- [ ] Monitorar bloat de tabelas:
  ```sql
  SELECT 
      schemaname, 
      tablename, 
      pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
  FROM pg_tables
  WHERE schemaname = 'public'
  ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
  ```

### Connection Pooling

- [ ] Configurar PgBouncer para pooling:
  ```ini
  [databases]
  dom360_db_prod = host=localhost port=5432 dbname=dom360_db_prod
  
  [pgbouncer]
  pool_mode = transaction
  max_client_conn = 1000
  default_pool_size = 25
  ```
- [ ] Backend conecta via PgBouncer (porta 6432)

---

## 📊 Master Settings Inicial

### SDR Endpoint

- [ ] Configurar endpoint de produção:
  ```sql
  UPDATE master_settings 
  SET 
      sdr_agent_endpoint = 'https://agent.dom360.com',
      sdr_agent_timeout_ms = 30000,
      health_check_enabled = true
  WHERE id = (SELECT id FROM master_settings LIMIT 1);
  ```
- [ ] Testar health check:
  ```bash
  curl -X POST https://api.dom360.com/api/admin/master-settings/health-check \
    -H "Authorization: Bearer MASTER_TOKEN"
  ```

### Server Config

- [ ] Configurar limites de produção:
  ```sql
  UPDATE master_settings
  SET server_config = '{
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
  }'::jsonb
  WHERE id = (SELECT id FROM master_settings LIMIT 1);
  ```

---

## 👥 Criação de Tenants

### Primeiro Tenant

- [ ] Criar tenant de produção:
  ```bash
  curl -X POST https://api.dom360.com/api/admin/tenants \
    -H "Authorization: Bearer MASTER_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "Cliente ABC",
      "slug": "cliente-abc",
      "chatwoot_account_id": 12345,
      "chatwoot_account_name": "Cliente ABC Chatwoot",
      "chatwoot_host": "https://app.chatwoot.com"
    }'
  ```

### Inboxes

- [ ] Associar inboxes ao tenant:
  ```bash
  curl -X POST https://api.dom360.com/api/admin/tenants/{tenant_id}/inboxes \
    -H "Authorization: Bearer MASTER_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"inbox_id": "inbox-uuid-aqui"}'
  ```

### Usuários

- [ ] Criar TENANT_ADMIN:
  ```bash
  curl -X POST https://api.dom360.com/api/auth/users \
    -H "Authorization: Bearer MASTER_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "tenant_id": "tenant-uuid",
      "role": "TENANT_ADMIN",
      "name": "Admin Cliente",
      "username": "admin.cliente",
      "email": "admin@cliente.com",
      "password": "SenhaSegura123!"
    }'
  ```

---

## 🔍 Monitoring & Alertas

### Métricas

- [ ] Configurar Prometheus exporters:
  ```python
  from prometheus_client import Counter, Histogram
  
  request_count = Counter('http_requests_total', 'Total HTTP Requests')
  request_latency = Histogram('http_request_duration_seconds', 'HTTP Request Latency')
  ```
- [ ] Criar dashboards Grafana:
  - Requests por segundo
  - Latência p50, p95, p99
  - Taxa de erro (4xx, 5xx)
  - Consumo de tokens por tenant
  - Pool de conexões DB

### Alertas

- [ ] Configurar alertas:
  - [ ] Erro rate > 5% por 5 minutos
  - [ ] Latência p95 > 2s
  - [ ] DB connection pool exausto
  - [ ] Health check SDR endpoint failing
  - [ ] Disk usage > 80%
  - [ ] Memory usage > 90%

### Logs

- [ ] Centralizar logs:
  ```python
  import logging
  import json
  
  logging.basicConfig(
      format='%(message)s',
      level=logging.INFO,
      handlers=[
          logging.StreamHandler(),
          logging.FileHandler('/var/log/dom360/api.log')
      ]
  )
  
  # Structured logging
  logger.info(json.dumps({
      "event": "user_login",
      "user_id": user.id,
      "tenant_id": user.tenant_id,
      "timestamp": datetime.utcnow().isoformat()
  }))
  ```

---

## 🧪 Testes Pré-Deploy

### Smoke Tests

- [ ] Login Master:
  ```bash
  curl -X POST https://api.dom360.com/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"master@dom360.local","password":"..."}'
  ```
- [ ] Health check:
  ```bash
  curl https://api.dom360.com/api/health
  ```
- [ ] Criar tenant de teste
- [ ] Enviar mensagem de teste
- [ ] Verificar RLS (tenant A não vê dados de tenant B)

### Load Tests

- [ ] Rodar testes de carga com Locust/k6:
  ```bash
  locust -f locustfile.py --host=https://api.dom360.com
  ```
- [ ] Target: 100 req/s sustentável
- [ ] Verificar degradação graciosa sob carga

### Security Tests

- [ ] SQL injection:
  ```bash
  # Tentar injetar SQL em parâmetros
  curl "https://api.dom360.com/api/conversations?limit=1; DROP TABLE users--"
  ```
- [ ] XSS em inputs
- [ ] CSRF protection
- [ ] JWT tampering:
  ```python
  # Tentar modificar claims do JWT
  # Deve retornar 401 Unauthorized
  ```
- [ ] RLS bypass:
  ```sql
  -- Tentar acessar outro tenant via SQL direto
  -- Deve ser bloqueado por RLS
  ```

---

## 📝 Documentação

- [ ] Atualizar API docs (Swagger/OpenAPI)
- [ ] Criar runbook para incidentes
- [ ] Documentar rollback procedure
- [ ] Criar guia de onboarding para novos tenants
- [ ] Documentar playbooks:
  - Criar novo tenant
  - Associar inbox
  - Resetar senha usuário
  - Investigar logs de auditoria

---

## 🔄 Rollback Plan

### Se algo der errado

1. **Backend:**
   ```bash
   # Reverter para versão anterior
   git checkout main
   systemctl restart dom360-api
   ```

2. **Database:**
   ```bash
   # Aplicar migração DOWN
   psql -U dom360_app -d dom360_db_prod -f database/004_master_tenant_rbac_down.sql
   ```

3. **Frontend:**
   ```bash
   # Reverter deploy no CDN
   # Depende da plataforma (Vercel, Cloudflare, etc.)
   ```

---

## ✅ Checklist Final

- [ ] Todos os itens acima verificados
- [ ] Backup completo do banco feito
- [ ] Logs de deploy capturados
- [ ] Equipe notificada sobre mudanças
- [ ] Plano de rollback documentado
- [ ] Monitoring dashboards configurados
- [ ] Alertas testados e funcionando
- [ ] Smoke tests passando
- [ ] Load tests aceitáveis
- [ ] Security audit realizado

---

## 📞 Contatos de Emergência

- **DevOps:** devops@dom360.com
- **Backend:** backend@dom360.com
- **Infraestrutura:** infra@dom360.com
- **On-call:** +55 11 99999-9999

---

**✅ Deploy aprovado! Boa sorte! 🚀**
