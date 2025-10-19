# Configuração com Traefik

## Visão Geral

Este docker-compose está configurado para funcionar com **Traefik** como proxy reverso. O Traefik gerencia:
- Roteamento de domínios
- SSL/TLS com Let's Encrypt
- Load balancing
- Middlewares (CORS, headers, etc)

## Estrutura com Traefik

```
User (navegador)
   ↓
Traefik (proxy reverso - portas 80/443)
   ├─→ sdk.srcjohann.com.br → Frontend (5173)
   └─→ api.srcjohann.com.br → Backend (3001)
```

## Requisitos

1. **Traefik instalado** e rodando em rede Docker
2. **DNS configurado** apontando os domínios para a VPS
3. **PostgreSQL rodando** na máquina host (acessível via `host.docker.internal`)

## Configuração

### 1. Rede Traefik

Se o Traefik está em um docker-compose separado, certifique-se de que está em uma rede bridge compartilhada.

**docker-compose do Traefik (exemplo):**
```yaml
services:
  traefik:
    image: traefik:v2.10
    # ... configuração ...
    networks:
      - traefik-network

networks:
  traefik-network:
    driver: bridge
```

**Este projeto (sdk-deploy):**
```yaml
networks:
  dom360-network:
    external: true
    name: traefik-network  # Mesmo nome da rede do Traefik
```

### 2. Labels Traefik

Os serviços estão configurados com labels que o Traefik detecta automaticamente:

**Backend (api.srcjohann.com.br):**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.dom360-backend.rule=Host(`api.srcjohann.com.br`)"
  - "traefik.http.routers.dom360-backend.entrypoints=websecure"
  - "traefik.http.routers.dom360-backend.tls.certresolver=letsencrypt"
  - "traefik.http.services.dom360-backend.loadbalancer.server.port=3001"
```

**Frontend (sdk.srcjohann.com.br):**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.dom360-frontend.rule=Host(`sdk.srcjohann.com.br`)"
  - "traefik.http.routers.dom360-frontend.entrypoints=websecure"
  - "traefik.http.routers.dom360-frontend.tls.certresolver=letsencrypt"
  - "traefik.http.services.dom360-frontend.loadbalancer.server.port=5173"
```

### 3. Configuração do Traefik (traefik.yml ou docker-compose)

Certifique-se que o Traefik tem:

```yaml
# Docker provider habilitado
providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false

# Entry points
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entrypoint:
          regex: "^http://(.*)$"
          replacement: "https://$1"
          permanent: true
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: letsencrypt

# Let's Encrypt
certificatesResolvers:
  letsencrypt:
    acme:
      email: seu-email@example.com
      storage: /acme.json
      httpChallenge:
        entryPoint: web
```

## Iniciando os Serviços

```bash
# 1. Certifique-se que Traefik está rodando
docker-compose -f traefik/docker-compose.yml up -d

# 2. Inicie este projeto
cd sdk-deploy
docker-compose up -d --build

# 3. Verifique se os serviços foram detectados
docker-compose ps
docker-compose logs -f
```

## Verificando o Setup

```bash
# Verificar se Traefik detectou os roteadores
curl http://localhost:8080/api/http/routers

# Testar endpoints (com tratamento de certificado auto-assinado)
curl -k https://sdk.srcjohann.com.br
curl -k https://api.srcjohann.com.br

# Ver logs do Traefik
docker logs traefik -f

# Ver logs dos serviços
docker-compose logs -f backend
docker-compose logs -f frontend
```

## Alterando Domínios

Para adicionar novos domínios ou mudar os existentes:

1. **Editar docker-compose.yml**
   ```yaml
   - "traefik.http.routers.dom360-backend.rule=Host(`novo-api.exemplo.com`)"
   ```

2. **Reiniciar os serviços**
   ```bash
   docker-compose restart backend
   ```

3. **Traefik detectará automaticamente** as mudanças (se Docker provider está habilitado)

## Middleware CORS

O backend está configurado com middleware CORS que só permite requisições de `sdk.srcjohann.com.br`:

```yaml
- "traefik.http.middlewares.cors.headers.accesscontrolalloworigins=https://sdk.srcjohann.com.br"
```

Para adicionar mais origens:
```yaml
- "traefik.http.middlewares.cors.headers.accesscontrolalloworigins=https://sdk.srcjohann.com.br,https://outra-origem.com"
```

## Troubleshooting

### Serviços não aparecem no Traefik Dashboard
```bash
# Verificar se o serviço tem labels corretos
docker-compose config | grep -A 10 "labels:"

# Verificar conectividade de rede
docker network inspect traefik-network
```

### SSL Certificate não é gerado
```bash
# Verificar logs do Traefik
docker logs traefik | grep -i "acme\|certificate\|error"

# Verificar arquivo de storage do ACME
docker exec traefik cat /acme.json
```

### Conexão recusada ao backend
```bash
# Verificar se backend está acessível
docker-compose exec frontend curl http://backend:3001/api/health

# Verificar port mapping
docker-compose ps

# Verificar rede
docker network inspect dom360-network
```

### PostgreSQL não responde
```bash
# Testar conexão do backend ao host
docker-compose exec backend pg_isready -h host.docker.internal -p 5432 -U postgres

# Se falhar, verificar configuração no .env
cat .env | grep DB_
```

## Remover Nginx

Se tinha Nginx antes:
```bash
# Remover containers e volumes
docker-compose down -v

# Remover arquivo nginx.conf (opcional)
rm nginx.conf

# Reconstruir sem Nginx
docker-compose up -d --build
```

## Próximas Etapas

1. ✅ Remover Nginx (feito - este docker-compose não tem Nginx)
2. ✅ Configurar labels Traefik (feito)
3. ⚠️ **Atualizar rede docker-compose** para usar rede do Traefik (se necessário)
4. ⚠️ **Testar conectividade** com domínios
5. ⚠️ **Monitorar logs** para erros

## Notas Importantes

- O backend e frontend **não expõem portas públicas** (apenas para Traefik via rede Docker interna)
- O Traefik cuida de SSL/TLS, você não precisa manter certificados manualmente
- Se quiser acessar os serviços diretamente (sem passar por Traefik), descomente as `ports` no docker-compose
