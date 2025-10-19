#!/bin/bash
# ==============================================================================
# Entrypoint para Backend FastAPI
# ==============================================================================
# Responsabilidades:
# 1. Aguardar PostgreSQL estar disponível (na VPS)
# 2. Iniciar servidor FastAPI
#
# PostgreSQL deve estar instalado e rodando na máquina VPS
#
# ==============================================================================

set -e

# ============================================================================
# Cores para output
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# ============================================================================
# Variáveis de ambiente
# ============================================================================
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-dom360_db_sdk}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD}"
MAX_RETRIES="${DB_MAX_RETRIES:-30}"
RETRY_INTERVAL="${DB_RETRY_INTERVAL:-2}"

# ============================================================================
# Logo
# ============================================================================
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         DOM360 SDK - Backend FastAPI Initialization             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}[INFO]${NC} Configuração:"
echo "  DB_HOST: $DB_HOST"
echo "  DB_PORT: $DB_PORT"
echo "  DB_NAME: $DB_NAME"
echo "  DB_USER: $DB_USER"
echo "  MAX_RETRIES: $MAX_RETRIES"
echo ""

# ============================================================================
# Função: Aguardar PostgreSQL
# ============================================================================
wait_for_postgres() {
    echo -e "${YELLOW}[1/2]${NC} Aguardando PostgreSQL estar disponível..."
    
    local retry=0
    export PGPASSWORD="$DB_PASSWORD"
    
    while [ $retry -lt $MAX_RETRIES ]; do
        if pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} PostgreSQL está disponível!"
            unset PGPASSWORD
            return 0
        fi
        
        retry=$((retry + 1))
        percentage=$((retry * 100 / MAX_RETRIES))
        echo -e "  [${percentage}%] Tentativa $retry/$MAX_RETRIES (aguardando ${RETRY_INTERVAL}s)..."
        sleep $RETRY_INTERVAL
    done
    
    echo -e "${RED}✗ ERRO${NC}: PostgreSQL não respondeu após $MAX_RETRIES tentativas"
    echo "  Verifique:"
    echo "    - Se PostgreSQL está rodando em $DB_HOST:$DB_PORT"
    echo "    - Se as credenciais estão corretas"
    echo "    - Se há conexão de rede entre container e VPS"
    exit 1
}

# ============================================================================
# Função: Iniciar Servidor
# ============================================================================
start_server() {
    echo -e "${YELLOW}[2/2]${NC} Iniciando servidor FastAPI..."
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                  Backend iniciado com sucesso!                  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  URL: ${BLUE}http://0.0.0.0:3001${NC}"
    echo -e "  Docs: ${BLUE}http://0.0.0.0:3001/docs${NC}"
    echo -e "  Database: ${BLUE}$DB_HOST:$DB_PORT/$DB_NAME${NC}"
    echo ""
    
    # Executar comando passado como argumento
    exec "$@"
}

# ============================================================================
# Main
# ============================================================================

wait_for_postgres
start_server "$@"
