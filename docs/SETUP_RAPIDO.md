# 🔧 Guia de Configuração Rápida - PostgreSQL

## Problema Atual

O erro ocorre porque o PostgreSQL está configurado para exigir senha, mas não temos a senha do usuário `postgres`.

## Soluções

### Opção 1: Conectar como Usuário do Sistema (Mais Fácil)

No Linux, você pode conectar como o usuário `postgres` do sistema sem senha:

```bash
# Entrar como usuário postgres
sudo -u postgres psql

# Dentro do psql, criar o banco e aplicar migrações
\i /home/johann/SDK/database/001_schema_up.sql
\i /home/johann/SDK/database/002_triggers_functions.sql

# Ou sair e usar o script:
\q

# Executar como usuário postgres
sudo -u postgres bash /home/johann/SDK/database/migrate.sh up
```

### Opção 2: Definir Senha para o Usuário postgres

```bash
# 1. Conectar como usuário postgres
sudo -u postgres psql

# 2. Definir senha (dentro do psql)
ALTER USER postgres WITH PASSWORD 'sua_senha_aqui';

# 3. Sair
\q

# 4. Exportar variável de ambiente
export DB_PASSWORD='sua_senha_aqui'

# 5. Executar migração
cd /home/johann/SDK/database
./migrate.sh up
```

### Opção 3: Usar Autenticação Trust Local (Desenvolvimento)

**⚠️ APENAS PARA DESENVOLVIMENTO LOCAL**

```bash
# 1. Editar pg_hba.conf
sudo nano /etc/postgresql/*/main/pg_hba.conf

# 2. Mudar a linha:
# De:   local   all   postgres   peer
# Para: local   all   postgres   trust

# 3. Reiniciar PostgreSQL
sudo systemctl restart postgresql

# 4. Agora pode conectar sem senha
psql -U postgres

# 5. Executar migração
cd /home/johann/SDK/database
./migrate.sh up
```

## Comandos Rápidos

### Para começar AGORA (Opção 1):

```bash
# Executar migração como usuário postgres
sudo -u postgres bash /home/johann/SDK/database/migrate.sh up

# Ver status
sudo -u postgres psql -d dom360_db -c "\dt"

# Criar dados de teste
sudo -u postgres bash /home/johann/SDK/database/migrate.sh seed
```

### Para Backend (depois da migração):

```bash
# Criar usuário de aplicação com senha
sudo -u postgres psql -d dom360_db << EOF
ALTER ROLE dom360_app WITH PASSWORD 'change_me_in_production';
EOF

# Configurar backend/.env
cd /home/johann/SDK/backend
cat > .env << EOF
PORT=3001
NODE_ENV=development

DB_HOST=localhost
DB_PORT=5432
DB_NAME=dom360_db
DB_USER=dom360_app
DB_PASSWORD=change_me_in_production

ENCRYPTION_KEY=$(openssl rand -base64 32)
EOF

# Instalar e rodar
npm install
npm start
```

## Verificação

```bash
# Testar conexão
sudo -u postgres psql -d dom360_db -c "SELECT COUNT(*) FROM tenants;"

# Ver tabelas
sudo -u postgres psql -d dom360_db -c "\dt"

# Ver dados de teste
sudo -u postgres psql -d dom360_db << EOF
SET app.tenant_id = '00000000-0000-0000-0000-000000000001';
SELECT * FROM tenants;
SELECT * FROM inboxes;
SELECT COUNT(*) FROM messages;
EOF
```

## Próximos Passos

1. ✅ Aplicar migração do banco
2. ✅ Criar dados de teste
3. ✅ Configurar backend/.env
4. ✅ Instalar dependências do backend
5. ✅ Rodar backend
6. ✅ Configurar frontend/.env
7. ✅ Rodar frontend

Siga os comandos abaixo na ordem!
