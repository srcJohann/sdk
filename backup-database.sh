#!/bin/bash
# ==============================================================================
# Script de Backup - PostgreSQL Database
# ==============================================================================
# Cria backup do banco de dados
# Usage: bash backup-database.sh
# ==============================================================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║               Backup - Database PostgreSQL                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Variáveis
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_${TIMESTAMP}.sql"

# Ler variáveis de ambiente
if [ -f .env.production ]; then
    export $(cat .env.production | grep -v '^#' | xargs)
fi

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-dom360_db_sdk}"
DB_USER="${DB_USER:-postgres}"

# Criar diretório de backup
mkdir -p "$BACKUP_DIR"

echo -e "${YELLOW}[1/3]${NC} Conectando ao banco de dados..."
echo "  Host: $DB_HOST:$DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo ""

echo -e "${YELLOW}[2/3]${NC} Criando backup..."
if [ "$DB_HOST" = "localhost" ] || [ "$DB_HOST" = "127.0.0.1" ]; then
    # Local
    pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" > "$BACKUP_FILE"
else
    # Docker
    docker exec sdk-postgres pg_dump \
        -U "$DB_USER" \
        "$DB_NAME" > "$BACKUP_FILE"
fi

echo -e "${GREEN}✓${NC} Backup criado: $BACKUP_FILE"
echo ""

# Tamanho do backup
SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo -e "${YELLOW}[3/3]${NC} Resumo:"
echo "  Arquivo: $BACKUP_FILE"
echo "  Tamanho: $SIZE"
echo "  Timestamp: $TIMESTAMP"
echo ""

# Limpeza de backups antigos (mais de 30 dias)
echo -e "${YELLOW}[Limpeza]${NC} Removendo backups com mais de 30 dias..."
find "$BACKUP_DIR" -name "backup_*.sql" -mtime +30 -delete

echo -e "${GREEN}✓${NC} Backup concluído com sucesso!"
