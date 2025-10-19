#!/bin/bash
# ==============================================================================
# Entrypoint para Backend
# - Aguarda PostgreSQL estar disponível
# - Executa migrations e seeds
# - Inicia servidor FastAPI
# ==============================================================================

set -e

echo "=========================================="
echo "DOM360 SDK Backend - Inicialização"
echo "=========================================="

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variáveis de ambiente
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-dom360_db_sdk}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD}"
MAX_RETRIES="${DB_MAX_RETRIES:-30}"
RETRY_INTERVAL="${DB_RETRY_INTERVAL:-2}"

echo ""
echo "Configuração:"
echo "  DB_HOST: $DB_HOST"
echo "  DB_PORT: $DB_PORT"
echo "  DB_NAME: $DB_NAME"
echo "  DB_USER: $DB_USER"
echo ""

# ==============================================================================
# Função: Aguardar PostgreSQL
# ==============================================================================
wait_for_postgres() {
    echo -e "${YELLOW}[1/3] Aguardando PostgreSQL estar disponível...${NC}"
    
    local retry=0
    export PGPASSWORD="$DB_PASSWORD"
    
    while [ $retry -lt $MAX_RETRIES ]; do
        if pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PostgreSQL está disponível!${NC}"
            return 0
        fi
        
        retry=$((retry + 1))
        echo "  Tentativa $retry/$MAX_RETRIES - Aguardando ${RETRY_INTERVAL}s..."
        sleep $RETRY_INTERVAL
    done
    
    echo -e "${RED}✗ ERRO: PostgreSQL não respondeu após $MAX_RETRIES tentativas${NC}"
    exit 1
}

# ==============================================================================
# Função: Verificar/Criar Database
# ==============================================================================
setup_database() {
    echo -e "${YELLOW}[2/3] Configurando banco de dados...${NC}"
    
    export PGPASSWORD="$DB_PASSWORD"
    
    # Verificar se o banco existe
    DB_EXISTS=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -tAc \
        "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'")
    
    if [ "$DB_EXISTS" != "1" ]; then
        echo "  Criando banco de dados '$DB_NAME'..."
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c \
            "CREATE DATABASE $DB_NAME WITH ENCODING='UTF8' LC_COLLATE='en_US.UTF-8' LC_CTYPE='en_US.UTF-8';"
        echo -e "${GREEN}✓ Banco de dados criado${NC}"
    else
        echo -e "${GREEN}✓ Banco de dados já existe${NC}"
    fi
    
    # Verificar se as tabelas existem
    TABLES_EXIST=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'")
    
    if [ "$TABLES_EXIST" = "0" ]; then
        echo "  Executando schema inicial..."
        
        # Aplicar schema
        if [ -f "./database/schema.sql" ]; then
            psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f ./database/schema.sql
            echo -e "${GREEN}✓ Schema aplicado${NC}"
        else
            echo -e "${RED}✗ AVISO: schema.sql não encontrado${NC}"
        fi
        
        # Aplicar migrations
        if [ -d "./database/migrations" ]; then
            for migration in ./database/migrations/*.sql; do
                if [ -f "$migration" ]; then
                    echo "  Aplicando migration: $(basename $migration)"
                    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$migration"
                fi
            done
            echo -e "${GREEN}✓ Migrations aplicadas${NC}"
        fi
        
        # Aplicar seeds
        if [ -d "./database/seeds" ]; then
            for seed in ./database/seeds/*.sql; do
                if [ -f "$seed" ]; then
                    echo "  Aplicando seed: $(basename $seed)"
                    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$seed"
                fi
            done
            echo -e "${GREEN}✓ Seeds aplicadas${NC}"
        fi
    else
        echo -e "${GREEN}✓ Tabelas já existem - pulando migrations${NC}"
    fi
}

# ==============================================================================
# Função: Iniciar Servidor
# ==============================================================================
start_server() {
    echo -e "${YELLOW}[3/3] Iniciando servidor FastAPI...${NC}"
    echo ""
    echo "=========================================="
    echo -e "${GREEN}Backend iniciado com sucesso!${NC}"
    echo "=========================================="
    echo ""
    
    # Executar comando passado como argumento
    exec "$@"
}

# ==============================================================================
# Main
# ==============================================================================

wait_for_postgres
setup_database
start_server "$@"
