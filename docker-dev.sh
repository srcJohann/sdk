#!/bin/bash

# ==============================================================================
# DOM360 - Docker Development Script
# Facilita execução em ambiente de desenvolvimento com Docker
# ==============================================================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ==============================================================================
# Functions
# ==============================================================================

print_help() {
    cat << EOF
${CYAN}DOM360 Docker Development${NC}

${BLUE}Uso:${NC}
  ./docker-dev.sh [comando] [opções]

${BLUE}Comandos:${NC}
  up              Iniciar containers (build se necessário)
  down            Parar containers
  restart         Reiniciar containers
  rebuild         Rebuild de imagens
  logs            Ver logs em tempo real
  shell           Acessar shell do backend
  db              Acessar shell do PostgreSQL
  clean           Parar containers e remover volumes
  status          Ver status dos containers
  test            Executar testes
  backup          Fazer backup do banco
  restore         Restaurar backup do banco

${BLUE}Exemplos:${NC}
  ./docker-dev.sh up
  ./docker-dev.sh logs backend
  ./docker-dev.sh shell
  ./docker-dev.sh db
EOF
}

# Verificar se Docker está rodando
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}✗ Docker não está rodando!${NC}"
        echo "  Inicie o Docker e tente novamente."
        exit 1
    fi
}

# Verificar se arquivo .env existe
check_env() {
    if [ ! -f ".env.local" ] && [ ! -f ".env" ]; then
        echo -e "${YELLOW}! Arquivo .env não encontrado${NC}"
        echo "  Criando .env.local com valores padrão..."
        cp .env.production .env.local 2>/dev/null || {
            echo -e "${RED}✗ Erro ao criar .env.local${NC}"
            exit 1
        }
        echo -e "${GREEN}✓ Arquivo .env.local criado${NC}"
        echo "  Edite conforme necessário: nano .env.local"
    fi
}

# ==============================================================================
# Main Commands
# ==============================================================================

up() {
    echo -e "${CYAN}Iniciando containers...${NC}"
    check_docker
    check_env
    docker-compose -f docker-compose.dev.yml up -d
    echo ""
    sleep 5
    status
    echo ""
    echo -e "${GREEN}✓ Containers iniciados!${NC}"
    echo ""
    echo -e "${CYAN}Acesso:${NC}"
    echo "  Frontend:    http://localhost:5173"
    echo "  Backend:     http://localhost:3001"
    echo "  API Docs:    http://localhost:3001/docs"
    echo "  PgAdmin:     http://localhost:5050 (admin@dom360.com / admin)"
    echo ""
    echo -e "${CYAN}Próximos passos:${NC}"
    echo "  ./docker-dev.sh logs       - Ver logs"
    echo "  ./docker-dev.sh shell      - Acessar shell do backend"
    echo "  ./docker-dev.sh db         - Acessar banco"
}

down() {
    echo -e "${CYAN}Parando containers...${NC}"
    docker-compose -f docker-compose.dev.yml down
    echo -e "${GREEN}✓ Containers parados${NC}"
}

restart() {
    echo -e "${CYAN}Reiniciando containers...${NC}"
    docker-compose -f docker-compose.dev.yml restart
    sleep 3
    status
}

rebuild() {
    echo -e "${CYAN}Reconstruindo imagens...${NC}"
    docker-compose -f docker-compose.dev.yml build --no-cache
    echo -e "${GREEN}✓ Build concluído!${NC}"
    echo -e "${CYAN}Para iniciar: ./docker-dev.sh up${NC}"
}

logs() {
    local service=${1:-"backend"}
    echo -e "${CYAN}Logs de $service:${NC}"
    docker-compose -f docker-compose.dev.yml logs -f "$service"
}

shell() {
    echo -e "${CYAN}Acessando shell do backend...${NC}"
    docker-compose -f docker-compose.dev.yml exec backend bash
}

db_shell() {
    echo -e "${CYAN}Acessando PostgreSQL...${NC}"
    docker-compose -f docker-compose.dev.yml exec postgres psql -U postgres -d dom360_db_sdk
}

clean() {
    echo -e "${YELLOW}! Isto removerá containers, volumes e dados!${NC}"
    read -p "Continuar? (s/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        echo -e "${CYAN}Limpando...${NC}"
        docker-compose -f docker-compose.dev.yml down -v
        echo -e "${GREEN}✓ Limpeza concluída${NC}"
    else
        echo "Cancelado."
    fi
}

status() {
    echo -e "${CYAN}Status dos containers:${NC}"
    docker-compose -f docker-compose.dev.yml ps
}

test_cmd() {
    echo -e "${CYAN}Executando testes...${NC}"
    docker-compose -f docker-compose.dev.yml exec backend python -m pytest backend/tests -v
}

backup_db() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="backup_${timestamp}.sql"
    echo -e "${CYAN}Fazendo backup para $backup_file...${NC}"
    docker-compose -f docker-compose.dev.yml exec -T postgres pg_dump -U postgres dom360_db_sdk > "$backup_file"
    gzip "$backup_file"
    echo -e "${GREEN}✓ Backup criado: ${backup_file}.gz${NC}"
}

restore_db() {
    if [ -z "$1" ]; then
        echo -e "${RED}✗ Especifique o arquivo de backup${NC}"
        echo "  Uso: ./docker-dev.sh restore backup.sql.gz"
        exit 1
    fi
    
    if [ ! -f "$1" ]; then
        echo -e "${RED}✗ Arquivo não encontrado: $1${NC}"
        exit 1
    fi
    
    local file=$1
    if [[ "$file" == *.gz ]]; then
        gunzip -c "$file" | docker-compose -f docker-compose.dev.yml exec -T postgres psql -U postgres -d dom360_db_sdk
    else
        docker-compose -f docker-compose.dev.yml exec -T postgres psql -U postgres -d dom360_db_sdk < "$file"
    fi
    echo -e "${GREEN}✓ Banco restaurado${NC}"
}

# ==============================================================================
# Main
# ==============================================================================

case "${1:-help}" in
    up)
        up
        ;;
    down)
        down
        ;;
    restart)
        restart
        ;;
    rebuild)
        rebuild
        ;;
    logs)
        logs "$2"
        ;;
    shell)
        shell
        ;;
    db)
        db_shell
        ;;
    clean)
        clean
        ;;
    status)
        status
        ;;
    test)
        test_cmd
        ;;
    backup)
        backup_db
        ;;
    restore)
        restore_db "$2"
        ;;
    *)
        print_help
        ;;
esac
