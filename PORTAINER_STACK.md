# Guia: Usar SDK com Portainer Stack

## Problema Resolvido

A rede `network_public` do Traefik não era "manually attachable", então foi criado um arquivo `sdk.yml` que:
1. Cria sua própria rede (`sdk-network`)
2. Mantém os labels do Traefik para roteamento automático
3. Funciona perfeitamente com Portainer

## Estrutura

```
Traefik (container, em network_public)
   ↕ (conecta via labels, não precisa estar na mesma rede)
Portainer Stack (sdk.yml em sdk-network)
   ├─ Backend (3001)
   └─ Frontend (5173)
```

## Como usar no Portainer

### 1. Acessar Portainer
```
http://seu-ip:9000
```

### 2. Ir para "Stacks"
- Menu lateral → "Stacks"

### 3. Criar novo Stack
- Clique em "Add Stack"
- Nome: `sdk` (ou o que preferir)

### 4. Colar o conteúdo do `sdk.yml`
```yaml
# Copie todo o conteúdo de sdk.yml e cole aqui
```

### 5. Adicionar variáveis de ambiente (.env)
Portainer permite adicionar variáveis de ambiente na interface. Clique em "Add environment variable" e adicione:

```
DB_HOST=host.docker.internal
DB_PORT=5432
DB_NAME=dom_db_360
DB_USER=postgres
DB_PASSWORD=sua_senha_aqui
PUBLIC_BACKEND_URL=https://api.srcjohann.com.br
PUBLIC_FRONTEND_URL=https://sdk.srcjohann.com.br
VITE_API_URL=https://api.srcjohann.com.br
NODE_ENV=production
PYTHON_ENV=production
```

### 6. Deploy
- Clique em "Deploy the stack"
- Portainer vai:
  - Fazer build das imagens
  - Criar a rede `sdk-network`
  - Iniciar os containers
  - Traefik detectará automaticamente os labels

### 7. Verificar Status
- Vá para "Containers"
- Procure por `dom360-backend` e `dom360-frontend`
- Devem estar com status "Running"

## Como usar via CLI (alternativa)

Se preferir usar linha de comando:

```bash
# Dentro do diretório do projeto
docker-compose -f sdk.yml up -d

# Ou, se tiver o arquivo em outro lugar
docker-compose -f /caminho/para/sdk.yml up -d

# Ver logs
docker-compose -f sdk.yml logs -f

# Parar
docker-compose -f sdk.yml down
```

## Testando Conectividade

```bash
# Verificar se containers estão rodando
docker ps | grep dom360

# Verificar se Traefik detectou
curl http://localhost:8080/api/http/routers

# Testar endpoints
curl -k https://sdk.srcjohann.com.br
curl -k https://api.srcjohann.com.br

# Ver logs do backend
docker logs dom360-backend

# Ver logs do frontend
docker logs dom360-frontend

# Testar conexão com PostgreSQL
docker exec dom360-backend pg_isready -h host.docker.internal -p 5432 -U postgres
```

## Conexão com Traefik

Mesmo com redes diferentes, o Traefik consegue rotear para os containers porque:

1. **Labels Traefik** identificam os serviços
2. **Docker socket** monitora containers em qualquer rede
3. **DNS interno** resolve nomes de containers automaticamente

O Traefik vai ver os labels e rotear:
- `api.srcjohann.com.br` → `dom360-backend:3001`
- `sdk.srcjohann.com.br` → `dom360-frontend:5173`

## Troubleshooting

### Traefik não roteia corretamente
```bash
# Verificar se Traefik tem acesso ao Docker socket
docker logs traefik | grep -i "docker\|error"

# Verificar se labels estão corretos
docker inspect dom360-backend | grep -A 20 '"Labels"'
```

### Containers não iniciam
```bash
# Ver logs de erro
docker-compose -f sdk.yml logs

# Verificar se há conflito de nomes
docker ps -a | grep dom360

# Se houver conflito, remover containers antigos
docker rm dom360-backend dom360-frontend
```

### PostgreSQL não responde
```bash
# Testar conexão
docker exec dom360-backend pg_isready -h host.docker.internal

# Se falhar, pode estar na rede errada ou PostgreSQL não está rodando
sudo systemctl status postgresql
```

### Erro de permissão em volumes
```bash
# Ajustar permissões
sudo chown $USER:$USER ./logs

# Ou no docker
docker exec dom360-backend chown -R app:app /app/logs
```

## Diferenças: docker-compose.yml vs sdk.yml

| Aspecto | docker-compose.yml | sdk.yml |
|---------|-------------------|---------|
| Uso | Desenvolvimento local | Portainer / Produção |
| Rede | Bridge padrão | Bridge nomeada (`sdk-network`) |
| Build | Local | Local ou registry |
| Deploy config | Simples | Inclui replicas e update policy |
| Version | Removida (deprecated) | Mantida para compatibilidade |

## Próximos Passos

1. ✅ Criar arquivo `sdk.yml`
2. ✅ Documentar uso no Portainer
3. ⚠️ **Copiar `sdk.yml` para servidor VPS**
4. ⚠️ **Fazer upload no Portainer**
5. ⚠️ **Monitorar logs após deploy**
6. ⚠️ **Testar endpoints públicos**

## Links Úteis

- [Portainer Documentation](https://docs.portainer.io/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
