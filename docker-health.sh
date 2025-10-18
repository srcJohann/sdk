#!/bin/bash

# ==============================================================================
# DOM360 - Docker Health Check & Diagnostics
# Verifica saúde dos containers e ajuda a diagnosticar problemas
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

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} $1"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_service() {
    local service=$1
    local port=$2
    local timeout=${3:-10}
    
    echo -n "Verificando $service... "
    
    if timeout $timeout docker-compose ps | grep -q "$service.*Up"; then
        echo -e "${GREEN}✓ Rodando${NC}"
        return 0
    else
        echo -e "${RED}✗ Parado ou com problema${NC}"
        return 1
    fi
}

check_port() {
    local port=$1
    local service=$2
    
    if curl -s http://localhost:$port > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Porta $port ($service) respondendo"
        return 0
    else
        echo -e "${YELLOW}!${NC} Porta $port ($service) não respondendo"
        return 1
    fi
}

# ==============================================================================
# Main Checks
# ==============================================================================

print_header "DOM360 Docker Health Check"

echo -e "${BLUE}[1]${NC} Status dos Containers"
echo "─────────────────────────────────────"
docker-compose ps
echo ""

echo -e "${BLUE}[2]${NC} Verificações de Serviços"
echo "─────────────────────────────────────"
check_service "postgres" "5432" || true
check_service "backend" "3001" || true
check_service "pgadmin" "5050" || true
echo ""

echo -e "${BLUE}[3]${NC} Conectividade de Portas"
echo "─────────────────────────────────────"
check_port 3001 "Backend" || true
check_port 5432 "PostgreSQL" || true
check_port 5050 "PgAdmin" || true
echo ""

echo -e "${BLUE}[4]${NC} Verificar Volumes"
echo "─────────────────────────────────────"
docker volume ls | grep dom360 || echo -e "${YELLOW}Nenhum volume encontrado${NC}"
echo ""

echo -e "${BLUE}[5]${NC} Uso de Recursos"
echo "─────────────────────────────────────"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || echo "Docker stats não disponível"
echo ""

echo -e "${BLUE}[6]${NC} Últimos Logs"
echo "─────────────────────────────────────"
echo -e "${YELLOW}Backend:${NC}"
docker-compose logs --tail=5 backend 2>/dev/null || echo "Sem logs"
echo ""
echo -e "${YELLOW}PostgreSQL:${NC}"
docker-compose logs --tail=5 postgres 2>/dev/null || echo "Sem logs"
echo ""

# ==============================================================================
# Diagnostics
# ==============================================================================

print_header "Diagnóstico Detalhado"

echo -e "${BLUE}Backend Health Check${NC}"
if curl -s http://localhost:3001/api/health 2>/dev/null | jq . > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} API respondendo"
    curl -s http://localhost:3001/api/health | jq .
else
    echo -e "${RED}✗${NC} API não respondendo"
    echo "Checando logs..."
    docker-compose logs backend | tail -20
fi
echo ""

echo -e "${BLUE}PostgreSQL Connection${NC}"
if docker-compose exec -T postgres psql -U postgres -c "SELECT 1" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} PostgreSQL conectando"
    docker-compose exec -T postgres psql -U postgres -c "SELECT version();" | head -1
else
    echo -e "${RED}✗${NC} PostgreSQL não conectando"
fi
echo ""

echo -e "${BLUE}Database Status${NC}"
db_name=$(grep DB_NAME .env 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "dom360_db_sdk")
if docker-compose exec -T postgres psql -U postgres -lqt | cut -d \| -f 1 | grep -qw $db_name; then
    echo -e "${GREEN}✓${NC} Database $db_name existe"
    docker-compose exec -T postgres psql -U postgres -d $db_name -c "\dt" | head -10
else
    echo -e "${RED}✗${NC} Database $db_name não encontrado"
fi
echo ""

# ==============================================================================
# Recommendations
# ==============================================================================

print_header "Recomendações"

# Verificar espaço em disco
disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $disk_usage -gt 90 ]; then
    echo -e "${RED}[⚠]${NC} Espaço em disco baixo: ${disk_usage}%"
    echo "    Recomendação: docker system prune -a"
fi

# Verificar memória
if command -v free &> /dev/null; then
    mem_usage=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
    if [ $mem_usage -gt 80 ]; then
        echo -e "${YELLOW}[!]${NC} Memória disponível baixa: ${mem_usage}%"
    fi
fi

# Verificar atualizações de imagens
echo -e "${BLUE}[i]${NC} Imagens Docker utilizadas:"
docker-compose config --services | while read service; do
    image=$(docker-compose config | grep -A 5 "^  $service:" | grep image | awk '{print $2}')
    echo "    - $service: $image"
done

echo ""
echo -e "${CYAN}Para mais ajuda, veja: DOCKER_GUIDE.md${NC}"
echo ""
