#!/bin/bash
# ==============================================================================
# Script de Verificação - DOM360 SDK Docker Deployment
# ==============================================================================
# Verifica se todos os serviços estão funcionando corretamente
# Usage: bash validate-deployment.sh
# ==============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      DOM360 SDK - Validação de Deployment                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ==========================================================================
# Função: Verificar comando
# ==========================================================================
check_command() {
    local cmd=$1
    local name=$2
    
    if command -v $cmd &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $name instalado"
        return 0
    else
        echo -e "  ${RED}✗${NC} $name NÃO encontrado"
        return 1
    fi
}

# ==========================================================================
# Função: Verificar container
# ==========================================================================
check_container() {
    local container=$1
    local name=$2
    
    if docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "^${container}$"; then
        local status=$(docker ps --filter "name=$container" --format "{{.Status}}" | head -1)
        echo -e "  ${GREEN}✓${NC} $name: $status"
        return 0
    else
        echo -e "  ${RED}✗${NC} $name: NÃO está rodando"
        return 1
    fi
}

# ==========================================================================
# Função: Verificar endpoint HTTP
# ==========================================================================
check_endpoint() {
    local url=$1
    local name=$2
    local expected=$3
    
    if curl -s -f "$url" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $name: Respondendo"
        return 0
    else
        echo -e "  ${RED}✗${NC} $name: Não respondendo"
        return 1
    fi
}

# ==========================================================================
# Verificações
# ==========================================================================

echo -e "${YELLOW}[1/5]${NC} Verificando dependências..."
docker_ok=$(check_command docker "Docker" && echo "1" || echo "0")
compose_ok=$(check_command docker-compose "Docker Compose" && echo "1" || echo "0")
echo ""

if [ "$docker_ok" = "0" ] || [ "$compose_ok" = "0" ]; then
    echo -e "${RED}Erro: Docker ou Docker Compose não instalado${NC}"
    exit 1
fi

echo -e "${YELLOW}[2/5]${NC} Verificando containers..."
backend_ok=$(check_container "sdk-backend" "Backend" && echo "1" || echo "0")
frontend_ok=$(check_container "sdk-frontend" "Frontend" && echo "1" || echo "0")
nginx_ok=$(check_container "sdk-nginx" "Nginx" && echo "1" || echo "0")
echo ""

echo -e "${YELLOW}[3/5]${NC} Verificando healthchecks..."
backend_health=$(check_endpoint "http://localhost:3001/api/health" "Backend Health" && echo "1" || echo "0")
frontend_health=$(check_endpoint "http://localhost:8080/" "Frontend Health" && echo "1" || echo "0")
echo ""

echo -e "${YELLOW}[4/5]${NC} Verificando CORS..."
cors_ok=$(curl -s -i -X OPTIONS \
    -H "Origin: https://sdk.srcjohann.com.br" \
    -H "Access-Control-Request-Method: POST" \
    http://localhost:3001/api/health 2>/dev/null | grep -q "Access-Control-Allow-Origin" && echo "1" || echo "0")

if [ "$cors_ok" = "1" ]; then
    echo -e "  ${GREEN}✓${NC} CORS Headers: Presentes"
else
    echo -e "  ${YELLOW}⚠${NC} CORS Headers: Não encontrados"
fi
echo ""

echo -e "${YELLOW}[5/5]${NC} Resumo de Configuração..."
grep "DB_HOST\|DB_NAME\|PUBLIC_BACKEND_URL\|PUBLIC_FRONTEND_URL" .env.production 2>/dev/null | sed 's/^/  /' || echo "  ⚠️ .env.production não encontrado"
echo ""

# ==========================================================================
# Resultado Final
# ==========================================================================

if [ "$backend_ok" = "1" ] && [ "$frontend_ok" = "1" ] && [ "$nginx_ok" = "1" ] && \
   [ "$backend_health" = "1" ] && [ "$frontend_health" = "1" ]; then
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                  ✓ Deployment OK!                             ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Endpoints disponíveis:"
    echo "  Backend:  http://localhost:3001/api/health"
    echo "  Frontend: http://localhost:8080"
    echo "  Nginx:    http://localhost:80"
    echo ""
    exit 0
else
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                  ✗ Alguns problemas encontrados               ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Próximos passos:"
    echo "  1. Verifique logs: docker compose logs -f"
    echo "  2. Leia DOCKER_PRODUCTION.md para troubleshooting"
    echo "  3. Verifique .env.production está configurado"
    echo ""
    exit 1
fi
