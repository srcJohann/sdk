#!/bin/bash

# ============================================================================
# Script de verificação pre-deployment
# Verifica se tudo está configurado corretamente antes do deploy
# ============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Contadores
PASSED=0
FAILED=0
WARNINGS=0

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ============================================================================
print_header "📋 VERIFICAÇÃO PRE-DEPLOYMENT"

# 1. Docker
print_header "1️⃣  Docker"

if command -v docker &> /dev/null; then
    check_pass "Docker instalado"
    VERSION=$(docker --version)
    check_pass "$VERSION"
else
    check_fail "Docker não encontrado"
fi

if docker info > /dev/null 2>&1; then
    check_pass "Docker daemon está rodando"
else
    check_fail "Docker daemon não está respondendo"
fi

# 2. Docker Swarm
print_header "2️⃣  Docker Swarm"

if docker info | grep -q "Swarm: active"; then
    check_pass "Docker Swarm está ativo"
    SWARM_STATUS=$(docker info | grep "Swarm:" | awk '{print $2}')
    SWARM_NODE_ID=$(docker info | grep "NodeID:" | awk '{print $2}' | cut -c1-12)
    check_pass "Node ID: $SWARM_NODE_ID"
else
    check_warn "Docker Swarm não está ativo"
    echo -e "${BLUE}ℹ${NC} Para ativar: docker swarm init"
fi

# 3. Redes
print_header "3️⃣  Redes Docker"

if docker network ls | grep -q "network_public"; then
    check_pass "Rede 'network_public' existe"
    NETWORK_DRIVER=$(docker network inspect network_public | grep '"Driver"' | awk -F'"' '{print $4}')
    check_pass "Driver: $NETWORK_DRIVER"
else
    check_warn "Rede 'network_public' não encontrada"
    echo -e "${BLUE}ℹ${NC} Para criar: docker network create -d overlay network_public"
fi

# 4. Imagens Docker
print_header "4️⃣  Imagens Docker"

if docker images | grep -q "sdk-backend"; then
    check_pass "Imagem 'sdk-backend:latest' existe"
else
    check_warn "Imagem 'sdk-backend:latest' não encontrada"
    echo -e "${BLUE}ℹ${NC} Execute: ./build-local.sh"
fi

if docker images | grep -q "sdk-frontend"; then
    check_pass "Imagem 'sdk-frontend:latest' existe"
else
    check_warn "Imagem 'sdk-frontend:latest' não encontrada"
    echo -e "${BLUE}ℹ${NC} Execute: ./build-local.sh"
fi

# 5. Arquivos de Configuração
print_header "5️⃣  Configuração"

if [ -f .env ]; then
    check_pass "Arquivo '.env' encontrado"
    
    # Verificar variáveis críticas
    if grep -q "^DB_HOST=" .env; then
        DB_HOST=$(grep "^DB_HOST=" .env | cut -d'=' -f2)
        check_pass "DB_HOST configurado: $DB_HOST"
    else
        check_fail "DB_HOST não configurado em .env"
    fi
    
    if grep -q "^BACKEND_BIND_PORT=" .env; then
        BACK_PORT=$(grep "^BACKEND_BIND_PORT=" .env | cut -d'=' -f2)
        check_pass "BACKEND_BIND_PORT: $BACK_PORT"
    else
        check_warn "BACKEND_BIND_PORT não configurado (padrão: 3001)"
    fi
    
    if grep -q "^FRONTEND_BIND_PORT=" .env; then
        FRONT_PORT=$(grep "^FRONTEND_BIND_PORT=" .env | cut -d'=' -f2)
        check_pass "FRONTEND_BIND_PORT: $FRONT_PORT"
    else
        check_warn "FRONTEND_BIND_PORT não configurado (padrão: 5173)"
    fi
    
    if grep -q "^PUBLIC_BACKEND_HOST=" .env; then
        BACK_HOST=$(grep "^PUBLIC_BACKEND_HOST=" .env | cut -d'=' -f2)
        check_pass "PUBLIC_BACKEND_HOST: $BACK_HOST"
    else
        check_fail "PUBLIC_BACKEND_HOST não configurado"
    fi
    
    if grep -q "^PUBLIC_FRONTEND_HOST=" .env; then
        FRONT_HOST=$(grep "^PUBLIC_FRONTEND_HOST=" .env | cut -d'=' -f2)
        check_pass "PUBLIC_FRONTEND_HOST: $FRONT_HOST"
    else
        check_fail "PUBLIC_FRONTEND_HOST não configurado"
    fi
else
    check_fail "Arquivo '.env' não encontrado"
fi

if [ -f docker-stack.yml ]; then
    check_pass "Arquivo 'docker-stack.yml' encontrado"
else
    check_fail "Arquivo 'docker-stack.yml' não encontrado"
fi

if [ -f Dockerfile.backend ]; then
    check_pass "Arquivo 'Dockerfile.backend' encontrado"
else
    check_fail "Arquivo 'Dockerfile.backend' não encontrado"
fi

if [ -f Dockerfile.frontend ]; then
    check_pass "Arquivo 'Dockerfile.frontend' encontrado"
else
    check_fail "Arquivo 'Dockerfile.frontend' não encontrado"
fi

# 6. Stack existente
print_header "6️⃣  Stack Existente"

if docker stack ls | grep -q "^sdk "; then
    check_warn "Stack 'sdk' já existe"
    echo -e "${BLUE}ℹ${NC} Services rodando:"
    docker stack services sdk | tail -n +2 | sed 's/^/    /'
else
    check_pass "Stack 'sdk' não existe (novo deploy)"
fi

# 7. Traefik
print_header "7️⃣  Traefik"

if docker ps | grep -q "traefik"; then
    check_pass "Traefik está rodando"
    TRAEFIK_VERSION=$(docker ps | grep traefik | awk '{print $2}')
    check_pass "Versão: $TRAEFIK_VERSION"
else
    check_warn "Traefik não encontrado"
    echo -e "${BLUE}ℹ${NC} Verifique se Traefik está em outro host/stack"
fi

# 8. Resultado Final
print_header "📊 RESULTADO"

TOTAL=$((PASSED + FAILED + WARNINGS))
PASS_PERCENT=$((PASSED * 100 / TOTAL))

echo ""
echo -e "Verificações realizadas: ${BLUE}$TOTAL${NC}"
echo -e "✓ Passou: ${GREEN}$PASSED${NC}"
echo -e "✗ Falhou: ${RED}$FAILED${NC}"
echo -e "⚠ Avisos: ${YELLOW}$WARNINGS${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ✓ Tudo pronto para deploy!${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Próximos passos:"
    echo "  1. ./build-local.sh    # Build das imagens (se necessário)"
    echo "  2. ./deploy.sh deploy  # Deploy do stack"
    echo "  3. ./deploy.sh status  # Verificar status"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}  ✗ Existem problemas a resolver${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi
