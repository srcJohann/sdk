#!/bin/bash

# ============================================================================
# Script para preparar o build local das imagens Docker no Swarm
# Use este script antes de fazer deploy em produção
# ============================================================================

set -e

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  SDK - Build Local para Docker Swarm"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"

# Verificar Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker não está instalado${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker encontrado${NC}"

# Verificar arquivo .env
if [ ! -f .env ]; then
    echo -e "${RED}✗ Arquivo .env não encontrado${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Arquivo .env encontrado${NC}"

# Build Backend
echo -e "\n${BLUE}[1/2]${NC} Fazendo build do Backend..."
docker build \
    --progress=plain \
    -f Dockerfile.backend \
    -t sdk-backend:latest \
    .

echo -e "${GREEN}✓ Backend built com sucesso${NC}"

# Build Frontend
echo -e "\n${BLUE}[2/2]${NC} Fazendo build do Frontend..."
docker build \
    --progress=plain \
    -f Dockerfile.frontend \
    -t sdk-frontend:latest \
    .

echo -e "${GREEN}✓ Frontend built com sucesso${NC}"

# Listar imagens
echo -e "\n${BLUE}Imagens locais:${NC}"
docker images | grep sdk

echo -e "\n${GREEN}✓ Build completo!${NC}"
echo -e "${BLUE}Próximo passo: ./deploy.sh deploy${NC}"
