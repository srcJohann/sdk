# ✅ Checklist de Deploy VPS - DOM360

## 📋 Antes de Fazer Deploy

### Configuração Local
- [ ] Clonar/atualizar repositório no servidor VPS
- [ ] Verificar que todos os arquivos estão presentes
- [ ] Ler `Claude_Haiku4.5_observations.md` para entender problemas
- [ ] Ler `RESUMO_CORRECOES.md` para ver o que foi corrigido

### Configurar .env
- [ ] Copiar `.env.production.example` para `.env`
- [ ] **CRÍTICO:** Alterar `VITE_API_URL` para URL pública (NÃO localhost!)
- [ ] **CRÍTICO:** Gerar `JWT_SECRET` com `openssl rand -base64 32`
- [ ] Definir `DB_PASSWORD` forte (com quotes)
- [ ] Configurar `PUBLIC_BACKEND_HOST` (ex: api.seudominio.com)
- [ ] Configurar `PUBLIC_FRONTEND_HOST` (ex: seudominio.com)
- [ ] Verificar `VITE_TENANT_ID` e `VITE_INBOX_ID`
- [ ] Definir `NODE_ENV=production`
- [ ] Definir `PYTHON_ENV=production`

### DNS (Se usar domínio)
- [ ] Criar registro A: `seudominio.com` → IP da VPS
- [ ] Criar registro A: `api.seudominio.com` → IP da VPS
- [ ] Aguardar propagação DNS (pode levar até 48h)
- [ ] Testar resolução: `nslookup seudominio.com`

---

## 🚀 Durante o Deploy

### Opção A: Deploy Automatizado (Recomendado)
- [ ] Executar: `sudo bash deploy_vps.sh`
- [ ] Acompanhar output do script
- [ ] Confirmar quando solicitado
- [ ] Anotar mensagens de erro (se houver)

### Opção B: Deploy Manual
- [ ] Seguir todos os passos em `docs/DEPLOY_VPS_GUIDE.md`
- [ ] Instalar dependências (nginx, postgresql, python, node)
- [ ] Configurar PostgreSQL
- [ ] Aplicar schema do banco
- [ ] Instalar deps Python (`pip install -r backend/requirements.txt`)
- [ ] Instalar deps Node (`npm install` no frontend)
- [ ] Build frontend (`npm run build`)
- [ ] Configurar Nginx (`sudo bash setup_nginx.sh`)
- [ ] Configurar firewall (UFW)
- [ ] Criar serviço systemd para backend
- [ ] Iniciar serviços

---

## ✅ Validação Pós-Deploy

### Verificar Serviços
- [ ] PostgreSQL está rodando: `systemctl status postgresql`
- [ ] Nginx está rodando: `systemctl status nginx`
- [ ] Backend está rodando: `systemctl status dom360-backend.service`
- [ ] Nginx configuração válida: `nginx -t`

### Verificar Conectividade
- [ ] Backend responde localmente: `curl http://localhost:3001/api/health`
- [ ] Backend responde via nginx: `curl http://api.seudominio.com/api/health`
- [ ] Frontend carrega: `curl http://seudominio.com`
- [ ] Porta 80 está aberta: `sudo netstat -tlnp | grep :80`
- [ ] Porta 443 está aberta (se SSL): `sudo netstat -tlnp | grep :443`

### Verificar Logs
- [ ] Backend não tem erros: `sudo journalctl -u dom360-backend.service -n 50`
- [ ] Nginx não tem erros: `sudo tail -f /var/log/nginx/error.log`
- [ ] PostgreSQL não tem erros: `sudo tail -f /var/log/postgresql/*.log`

### Testar Funcionalidades
- [ ] Frontend carrega no navegador
- [ ] Login funciona (se implementado)
- [ ] Chat envia mensagem
- [ ] Chat recebe resposta
- [ ] Não há erros de CORS no console
- [ ] Network tab mostra requests bem-sucedidos

---

## 🔐 Segurança

### Firewall
- [ ] UFW está ativo: `sudo ufw status`
- [ ] Porta 22 (SSH) permitida
- [ ] Porta 80 (HTTP) permitida
- [ ] Porta 443 (HTTPS) permitida
- [ ] Outras portas bloqueadas por padrão

### SSL (Let's Encrypt)
- [ ] DNS está configurado e propagado
- [ ] Certbot instalado
- [ ] Executar: `sudo certbot --nginx -d seudominio.com -d api.seudominio.com`
- [ ] Certificado instalado com sucesso
- [ ] Auto-renovação configurada: `sudo certbot renew --dry-run`
- [ ] HTTPS funciona no navegador
- [ ] Redirect HTTP → HTTPS configurado

### Credenciais
- [ ] `JWT_SECRET` forte e único
- [ ] `DB_PASSWORD` forte e único
- [ ] Credenciais NÃO estão no git
- [ ] `.env` tem permissões corretas (600): `chmod 600 .env`

---

## 🔧 Troubleshooting

### Se Backend Não Inicia
- [ ] Verificar logs: `sudo journalctl -u dom360-backend.service -n 100`
- [ ] Verificar se Python venv está ativo
- [ ] Verificar se requirements.txt foram instalados
- [ ] Verificar se PostgreSQL está acessível
- [ ] Testar conexão DB manualmente

### Se Frontend Não Carrega
- [ ] Verificar se build foi gerado: `ls frontend/app/dist/`
- [ ] Verificar se nginx está servindo dist correto
- [ ] Verificar logs nginx: `sudo tail -f /var/log/nginx/error.log`
- [ ] Testar diretamente: `curl -I http://seudominio.com`

### Se CORS Error
- [ ] Verificar `CORS_ORIGINS` no backend
- [ ] Verificar que domínio frontend está na lista
- [ ] Reiniciar backend: `sudo systemctl restart dom360-backend.service`
- [ ] Verificar headers: `curl -I -X OPTIONS http://api.seudominio.com/api/health -H "Origin: http://seudominio.com"`

### Se 502 Bad Gateway
- [ ] Backend está rodando? `systemctl status dom360-backend.service`
- [ ] Backend escuta na porta certa? `netstat -tlnp | grep 3001`
- [ ] Nginx upstream está correto? `cat /etc/nginx/sites-enabled/dom360`

---

## 📈 Otimização Pós-Deploy

### Performance
- [ ] Habilitar gzip no nginx (já está no nginx.conf)
- [ ] Configurar cache de assets estáticos
- [ ] Monitorar uso de recursos: `htop`
- [ ] Configurar connection pooling no PostgreSQL

### Monitoramento
- [ ] Configurar log rotation
- [ ] Configurar alertas de erro
- [ ] Monitorar disco: `df -h`
- [ ] Monitorar memória: `free -m`
- [ ] Configurar backup automático do banco

### Backup
- [ ] Criar script de backup: `pg_dump -U user db > backup.sql`
- [ ] Adicionar ao crontab: `crontab -e`
- [ ] Testar restore: `psql -U user db < backup.sql`
- [ ] Configurar backup remoto (S3, etc)

---

## 🎯 Checklist Final

### Antes de Considerar Deploy Completo
- [ ] ✅ Todas as correções do `Claude_Haiku4.5_observations.md` aplicadas
- [ ] ✅ `.env` configurado corretamente
- [ ] ✅ DNS configurado (se usar domínio)
- [ ] ✅ SSL instalado e funcionando
- [ ] ✅ Firewall configurado
- [ ] ✅ Todos os serviços rodando
- [ ] ✅ Backend responde via API
- [ ] ✅ Frontend carrega
- [ ] ✅ Sem erros CORS
- [ ] ✅ Login funciona
- [ ] ✅ Chat funciona
- [ ] ✅ Logs não mostram erros
- [ ] ✅ Backup configurado
- [ ] ✅ Monitoramento configurado

---

## 📞 Ajuda

Se algo não funcionar:

1. **Consulte a documentação:**
   - `docs/DEPLOY_VPS_GUIDE.md` - Guia completo
   - `docs/CORRECOES_APLICADAS.md` - O que foi corrigido
   - `RESUMO_CORRECOES.md` - Resumo executivo

2. **Verifique os logs:**
   ```bash
   sudo journalctl -u dom360-backend.service -f
   sudo tail -f /var/log/nginx/error.log
   ```

3. **Valide configurações:**
   ```bash
   cat .env | grep -E "VITE_API_URL|PUBLIC_"
   sudo nginx -t
   systemctl status dom360-backend.service
   ```

4. **Teste conectividade:**
   ```bash
   curl -v http://api.seudominio.com/api/health
   curl -I http://seudominio.com
   ```

---

## 🎉 Deploy Bem-Sucedido!

Se todos os itens acima estão marcados:

**🎊 Parabéns! Seu DOM360 SDK está rodando em produção!**

URLs de acesso:
- Frontend: https://seudominio.com
- Backend: https://api.seudominio.com

Próximos passos:
1. Monitorar logs por 24-48h
2. Testar todas as funcionalidades
3. Configurar alertas
4. Documentar customizações
5. Treinar usuários

---

**Versão:** 2.0.0  
**Data:** 18 de outubro de 2025  
**Status:** ✅ Pronto para uso
