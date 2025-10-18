#!/bin/bash

set -e

echo "======================================"
echo "DOM360 - Docker Initialization"
echo "======================================"

# Carregar variáveis de ambiente
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | grep -v '^$' | xargs)
fi

# Definir valores padrão
DB_HOST=${DB_HOST:-postgres}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-dom360_db_sdk}
DB_USER=${DB_USER:-postgres}
DB_PASSWORD=${DB_PASSWORD:-admin}

BACKEND_PORT=${BACKEND_PORT:-3001}
BACKEND_BIND_HOST=${BACKEND_BIND_HOST:-0.0.0.0}
BACKEND_BIND_PORT=${BACKEND_BIND_PORT:-3001}

echo "[1/4] Aguardando banco de dados..."
# Aguardar PostgreSQL ficar pronto
max_attempts=30
attempt=1
while ! PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d postgres -c "SELECT 1" > /dev/null 2>&1; do
    if [ $attempt -ge $max_attempts ]; then
        echo "❌ Timeout aguardando PostgreSQL!"
        exit 1
    fi
    echo "  ⏳ Tentativa $attempt/$max_attempts... PostgreSQL não disponível ainda"
    sleep 2
    attempt=$((attempt + 1))
done

echo "✅ PostgreSQL está disponível"

# Verificar se banco existe, senão criar
echo "[2/4] Criando banco de dados se necessário..."
if ! PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw $DB_NAME; then
    echo "  Criando banco $DB_NAME..."
    PGPASSWORD=$DB_PASSWORD createdb -h $DB_HOST -U $DB_USER $DB_NAME
    echo "✅ Banco criado"
else
    echo "✅ Banco já existe"
fi

# Aplicar schema
echo "[3/4] Aplicando schema do banco..."
if [ -f "database/schema.sql" ]; then
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f database/schema.sql > /dev/null 2>&1
    echo "✅ Schema aplicado"
else
    echo "⚠️  Schema não encontrado"
fi

# Aplicar seeds
echo "[4/4] Aplicando seed data..."
if [ -f "database/seeds/001_seed_master.sql" ]; then
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f database/seeds/001_seed_master.sql > /dev/null 2>&1
    echo "✅ Seed aplicado"
else
    echo "⚠️  Seed não encontrado"
fi

echo ""
echo "======================================"
echo "Iniciando serviços..."
echo "======================================"
echo ""

# Iniciar backend
echo "🚀 Iniciando Backend (FastAPI)..."
cd /app

if [ -f "backend/server_rbac.py" ]; then
    exec python backend/server_rbac.py
else
    exec python backend/server.py
fi
