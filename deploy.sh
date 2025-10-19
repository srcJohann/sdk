#!/bin/bash
# ==============================================================================
# Deploy Helper Script
# Facilita o deploy da aplicação DOM360 SDK
# ==============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════╗"
echo "║     DOM360 SDK - Deploy Helper Script         ║"
echo "╔════════════════════════════════════════════════╝"
echo -e "${NC}"

# Função para mostrar uso
show_usage() {
    echo "Uso: ./deploy.sh [comando]"
    echo ""
    echo "Comandos disponíveis:"
    echo "  start           - Iniciar aplicação (com Postgres externo)"
    echo "  start-db        - Iniciar aplicação (com Postgres interno)"
    echo "  stop            - Parar aplicação"
    echo "  restart         - Reiniciar aplicação"
    echo "  logs            - Ver logs de todos os serviços"
    echo "  logs-backend    - Ver logs do backend"
    echo "  logs-frontend   - Ver logs do frontend"
    echo "  status          - Ver status dos containers"
    echo "  rebuild         - Rebuild e restart da aplicação"
    echo "  clean           - Parar e remover containers (mantém volumes)"
    echo "  clean-all       - Parar e remover containers e volumes (CUIDADO!)"
    echo "  setup           - Setup inicial (criar .env.production)"
    echo "  check           - Verificar pré-requisitos"
    echo ""
}

# Função para verificar pré-requisitos
check_requirements() {
    echo -e "${YELLOW}[CHECK] Verificando pré-requisitos...${NC}"
    
    # Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}✗ Docker não está instalado${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Docker instalado: $(docker --version)${NC}"
    
    # Docker Compose
    if ! docker compose version &> /dev/null; then
        echo -e "${RED}✗ Docker Compose não está instalado${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Docker Compose instalado: $(docker compose version)${NC}"
    
    # Arquivo .env.production
    if [ ! -f .env.production ]; then
        echo -e "${YELLOW}⚠ Arquivo .env.production não encontrado${NC}"
        echo -e "${BLUE}Execute: ./deploy.sh setup${NC}"
        return 1
    fi
    echo -e "${GREEN}✓ Arquivo .env.production existe${NC}"
    
    echo ""
}

# Função para setup inicial
setup() {
    echo -e "${YELLOW}[SETUP] Configuração inicial...${NC}"
    
    if [ -f .env.production ]; then
        echo -e "${YELLOW}⚠ Arquivo .env.production já existe${NC}"
        read -p "Deseja sobrescrever? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Setup cancelado."
            exit 0
        fi
    fi
    
    cp .env.example .env.production
    
    echo -e "${GREEN}✓ Arquivo .env.production criado${NC}"
    echo -e "${BLUE}Edite o arquivo .env.production com suas configurações:${NC}"
    echo "  nano .env.production"
    echo ""
    echo -e "${YELLOW}Variáveis importantes:${NC}"
    echo "  - DB_HOST (use 'host.docker.internal' para Postgres local)"
    echo "  - DB_PASSWORD"
    echo "  - JWT_SECRET (gere com: openssl rand -base64 32)"
    echo "  - PUBLIC_BACKEND_URL"
    echo "  - PUBLIC_FRONTEND_URL"
    echo ""
}

# Função para iniciar aplicação
start() {
    local with_db=$1
    echo -e "${YELLOW}[START] Iniciando aplicação...${NC}"
    
    if [ "$with_db" = "true" ]; then
        echo -e "${BLUE}Modo: Com PostgreSQL interno${NC}"
        docker compose -f docker-compose.prod.yml --env-file .env.production --profile with-db up -d
    else
        echo -e "${BLUE}Modo: Com PostgreSQL externo${NC}"
        docker compose -f docker-compose.prod.yml --env-file .env.production up -d
    fi
    
    echo ""
    echo -e "${GREEN}✓ Aplicação iniciada!${NC}"
    echo ""
    echo "Verificando status..."
    sleep 5
    docker compose -f docker-compose.prod.yml ps
    echo ""
    echo -e "${BLUE}Acesse:${NC}"
    echo "  Frontend: http://sdk.srcjohann.com.br"
    echo "  Backend:  http://api.srcjohann.com.br/api/health"
    echo ""
}

# Função para parar aplicação
stop() {
    echo -e "${YELLOW}[STOP] Parando aplicação...${NC}"
    docker compose -f docker-compose.prod.yml stop
    echo -e "${GREEN}✓ Aplicação parada${NC}"
}

# Função para reiniciar aplicação
restart() {
    echo -e "${YELLOW}[RESTART] Reiniciando aplicação...${NC}"
    docker compose -f docker-compose.prod.yml restart
    echo -e "${GREEN}✓ Aplicação reiniciada${NC}"
}

# Função para ver logs
logs() {
    local service=$1
    if [ -z "$service" ]; then
        docker compose -f docker-compose.prod.yml logs -f
    else
        docker compose -f docker-compose.prod.yml logs -f "$service"
    fi
}

# Função para ver status
status() {
    echo -e "${YELLOW}[STATUS] Status dos containers...${NC}"
    docker compose -f docker-compose.prod.yml ps
}

# Função para rebuild
rebuild() {
    echo -e "${YELLOW}[REBUILD] Rebuilding e reiniciando...${NC}"
    docker compose -f docker-compose.prod.yml up -d --build
    echo -e "${GREEN}✓ Rebuild completo${NC}"
}

# Função para limpar
clean() {
    local all=$1
    echo -e "${YELLOW}[CLEAN] Limpando...${NC}"
    
    if [ "$all" = "true" ]; then
        echo -e "${RED}⚠ ATENÇÃO: Isso irá remover os volumes (dados do banco)${NC}"
        read -p "Tem certeza? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker compose -f docker-compose.prod.yml down -v
            echo -e "${GREEN}✓ Containers e volumes removidos${NC}"
        else
            echo "Operação cancelada."
        fi
    else
        docker compose -f docker-compose.prod.yml down
        echo -e "${GREEN}✓ Containers removidos (volumes mantidos)${NC}"
    fi
}

# Main
case "$1" in
    start)
        check_requirements || exit 1
        start false
        ;;
    start-db)
        check_requirements || exit 1
        start true
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    logs)
        logs
        ;;
    logs-backend)
        logs backend
        ;;
    logs-frontend)
        logs frontend
        ;;
    status)
        status
        ;;
    rebuild)
        check_requirements || exit 1
        rebuild
        ;;
    clean)
        clean false
        ;;
    clean-all)
        clean true
        ;;
    setup)
        setup
        ;;
    check)
        check_requirements
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
