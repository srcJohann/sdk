# Build e Push para Docker Hub

## Scripts Disponíveis

Existem dois scripts para fazer build e push das imagens:

### 1. `push-to-hub-simple.sh` (RECOMENDADO)
Script simplificado que você pode rodar em background:

```bash
# Rodar em background com output para arquivo
nohup ./push-to-hub-simple.sh latest > push.log 2>&1 &

# Ver o progresso em tempo real
tail -f push.log

# Verificar se finalizou
ps aux | grep push-to-hub
```

### 2. `push-to-hub.sh`
Script completo com mais validações.

---

## Passo a Passo

### 1. Fazer login no Docker Hub (primeira vez)

```bash
docker login -u johannalves
# Digite sua senha quando solicitado
```

### 2. Buildar e fazer push

```bash
# Com tag "latest"
./push-to-hub-simple.sh latest

# Com tag versionada
./push-to-hub-simple.sh 1.0.0
```

### 3. Rodar em background (recomendado para VPS)

```bash
# Rodar em background e salvar logs
nohup ./push-to-hub-simple.sh latest > push-output.log 2>&1 &

# Ver o progresso
tail -f push-output.log

# Parar de ver os logs (Ctrl+C não para o script)
# Script continua rodando
```

---

## Tempo Estimado

- **Build Backend**: ~5-10 minutos (primeira vez, menos depois)
- **Build Frontend**: ~3-5 minutos
- **Push para Hub**: ~2-5 minutos (depende da conexão)
- **Total**: ~15-20 minutos

---

## Verificar Imagens no Docker Hub

Após o push completar, você pode verificar:

1. **Via navegador**:
   - Backend: https://hub.docker.com/r/johannalves/sdk-backend
   - Frontend: https://hub.docker.com/r/johannalves/sdk-frontend

2. **Via CLI**:
   ```bash
   docker pull johannalves/sdk-backend:latest
   docker pull johannalves/sdk-frontend:latest
   ```

---

## Troubleshooting

### Build falha por espaço em disco

```bash
# Verificar espaço disponível
df -h

# Limpar imagens e containers não usados
docker system prune -a --volumes
```

### Push falha por não autenticado

```bash
# Fazer login novamente
docker logout
docker login -u johannalves
```

### Container ou imagem já existe

```bash
# Remover imagens antigas
docker rmi johannalves/sdk-backend:latest
docker rmi johannalves/sdk-frontend:latest

# Depois rodar o script novamente
```

---

## Usar as Imagens no Portainer

Após o push, você pode usar as imagens no `sdk.yml`:

```yaml
backend:
  image: johannalves/sdk-backend:latest
  # ...

frontend:
  image: johannalves/sdk-frontend:latest
  # ...
```

E fazer pull direto do Docker Hub:

```bash
docker-compose -f sdk.yml pull
docker-compose -f sdk.yml up -d
```

---

## Próximos Passos

1. ✅ Fazer login no Docker Hub
2. ⚠️ **Rodar: `nohup ./push-to-hub-simple.sh latest > push.log 2>&1 &`**
3. ✅ Verificar imagens no Hub
4. ✅ Atualizar `sdk.yml` para usar as imagens (se desejar)

---

## Dicas

- **Não deixe o terminal aberto**: Use `nohup` para rodar em background
- **SSH se desconectar**: O script continua rodando via `nohup`
- **Múltiplas tags**: Pode fazer push de várias tags
  ```bash
  ./push-to-hub-simple.sh 1.0.0
  ./push-to-hub-simple.sh 1.0.1
  ./push-to-hub-simple.sh latest
  ```

---

## Suporte

Se tiver problemas, verifique:
- `push-output.log` para erros de build
- `docker logs` para problemas de runtime
- Espaço em disco com `df -h`
- Conexão com Docker Hub: `curl https://hub.docker.com`
