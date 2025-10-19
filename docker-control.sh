#!/bin/bash
# ==============================================================================
# Script de Controle - DOM360 SDK Docker
# ==============================================================================
# Controla os containers (start, stop, restart, clean)
# Usage: bash docker-control.sh [start|stop|restart|clean|logs]
# ==============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variáveis
COMPOSE_FILE="docker-compose.prod.yml"
COMPOSE_CMD="docker compose -f $COMPOSE_FILE"

# Função de uso
usage() {
    echo "Uso: bash docker-control.sh [COMANDO]"
    echo ""
    echo "Comandos:"
    echo "  start       - Inicia todos os containers"
    echo "  stop        - Para todos os containers"
    echo "  restart     - Reinicia todos os containers"
    echo "  clean       - Remove containers, volumes e networks"
    echo "  logs        - Mostra logs em tempo real"
    echo "  status      - Mostra status dos containers"
    echo "  backup      - Faz backup do banco de dados"
    echo ""
    echo "Exemplos:"
    echo "  bash docker-control.sh start"
    echo "  bash docker-control.sh logs"
    echo "  bash docker-control.sh restart"
    exit 1
}

# Verificar comando
if [ -z "$1" ]; then
    usage
fi

COMMAND=$1

# ==========================================================================
# Comando: START
# ==========================================================================
if [ "$COMMAND" = "start" ]; then
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                   Iniciando containers...                       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Verificar se .env.production existe
    if [ ! -f ".env.production" ]; then
        echo -e "${RED}Erro: .env.production não encontrado${NC}"
        echo "Execute: cp .env.production.example .env.production"
        exit 1
    fi
    
    # Iniciar com ou sem perfil with-db
    if [ "$2" = "with-db" ]; then
        echo "Modo: Com PostgreSQL containerizado"
        $COMPOSE_CMD --profile with-db up -d
    else
        echo "Modo: PostgreSQL local (host.docker.internal)"
        $COMPOSE_CMD up -d
    fi
    
    echo ""
    echo -e "${GREEN}✓${NC} Containers iniciados!"
    echo "Aguardando inicialização (30s)..."
    sleep 30
    
    bash "$0" status
    exit 0

# ==========================================================================
# Comando: STOP
# ==========================================================================
elif [ "$COMMAND" = "stop" ]; then
    echo -e "${YELLOW}Parando containers...${NC}"
    $COMPOSE_CMD down
    echo -e "${GREEN}✓${NC} Containers parados!"
    exit 0

# ==========================================================================
# Comando: RESTART
# ==========================================================================
elif [ "$COMMAND" = "restart" ]; then
    echo -e "${YELLOW}Reiniciando containers...${NC}"
    $COMPOSE_CMD restart
    echo -e "${GREEN}✓${NC} Containers reiniciados!"
    sleep 10
    bash "$0" status
    exit 0

# ==========================================================================
# Comando: CLEAN
# ==========================================================================
elif [ "$COMMAND" = "clean" ]; then
    echo -e "${RED}Aviso: Isto vai remover todos os containers, volumes e networks${NC}"
    echo -e "${YELLOW}Digite 'sim' para confirmar:${NC}"
    read -r confirm
    
    if [ "$confirm" = "sim" ]; then
        echo "Removendo containers..."
        $COMPOSE_CMD down -v
        echo -e "${GREEN}✓${NC} Limpeza concluída!"
    else
        echo "Operação cancelada"
    fi
    exit 0

# ==========================================================================
# Comando: LOGS
# ==========================================================================
elif [ "$COMMAND" = "logs" ]; then
    SERVICE=${2:-""}
    
    if [ -z "$SERVICE" ]; then
        echo -e "${BLUE}Mostrando logs de todos os serviços...${NC}"
        echo "Pressione Ctrl+C para parar"
        $COMPOSE_CMD logs -f
    else
        echo -e "${BLUE}Mostrando logs de: $SERVICE${NC}"
        echo "Pressione Ctrl+C para parar"
        $COMPOSE_CMD logs -f "$SERVICE"
    fi
    exit 0

# ==========================================================================
# Comando: STATUS
# ==========================================================================
elif [ "$COMMAND" = "status" ]; then
    echo -e "${BLUE}Status dos containers:${NC}"
    echo ""
    
    # Usar docker ps
    docker ps --filter "label!=skip" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | \
        grep -E "sdk-|dom360-" || true
    
    echo ""
    echo -e "${BLUE}Healthchecks:${NC}"
    
    # Backend
    if curl -s http://localhost:3001/api/health > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Backend: OK"
    else
        echo -e "  ${RED}✗${NC} Backend: FAIL"
    fi
    
    # Frontend
    if curl -s http://localhost:8080/ > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Frontend: OK"
    else
        echo -e "  ${RED}✗${NC} Frontend: FAIL"
    fi
    
    echo ""
    exit 0

# ==========================================================================
# Comando: BACKUP
# ==========================================================================
elif [ "$COMMAND" = "backup" ]; then
    bash backup-database.sh
    exit 0

# ==========================================================================
# Comando desconhecido
# ==========================================================================
else
    echo -e "${RED}Comando desconhecido: $COMMAND${NC}"
    usage
fi
