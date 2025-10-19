#!/bin/bash
# ==============================================================================
# Script: Push Docker Images to Docker Hub
# ==============================================================================
# Objetivo: Build e fazer push das imagens Docker para Docker Hub
# Uso: ./push-to-hub.sh [tag]
# Exemplo: ./push-to-hub.sh latest
#          ./push-to-hub.sh 1.0.0
# ==============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# Configuração
DOCKER_USERNAME="johannalves"
DOCKER_REPO="sdk"
TAG="${1:-latest}"
REGISTRY="${DOCKER_USERNAME}/${DOCKER_REPO}"

# ==============================================================================
# Logo
# ==============================================================================
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║        DOM360 SDK - Push to Docker Hub                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}Configuração:${NC}"
echo "  Registry: $REGISTRY"
echo "  Tag: $TAG"
echo "  Backend Image: ${REGISTRY}-backend:${TAG}"
echo "  Frontend Image: ${REGISTRY}-frontend:${TAG}"
echo ""

# ==============================================================================
# Verificar Docker
# ==============================================================================
echo -e "${YELLOW}[1/5]${NC} Verificando Docker..."
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker não está instalado${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker encontrado${NC}"
echo ""

# ==============================================================================
# Verificar Login no Docker Hub
# ==============================================================================
echo -e "${YELLOW}[2/5]${NC} Verificando autenticação Docker Hub..."
if ! docker info | grep -q "Username: ${DOCKER_USERNAME}"; then
    echo -e "${YELLOW}Fazendo login no Docker Hub...${NC}"
    docker login -u "${DOCKER_USERNAME}"
fi
echo -e "${GREEN}✓ Autenticado${NC}"
echo ""

# ==============================================================================
# Build Backend
# ==============================================================================
echo -e "${YELLOW}[3/5]${NC} Building Backend Image..."
echo "  Building: ${REGISTRY}-backend:${TAG}"
docker build \
    --tag "${REGISTRY}-backend:${TAG}" \
    --tag "${REGISTRY}-backend:latest" \
    --file Dockerfile \
    .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Backend image built successfully${NC}"
else
    echo -e "${RED}✗ Failed to build backend image${NC}"
    exit 1
fi
echo ""

# ==============================================================================
# Build Frontend
# ==============================================================================
echo -e "${YELLOW}[4/5]${NC} Building Frontend Image..."
echo "  Building: ${REGISTRY}-frontend:${TAG}"
docker build \
    --tag "${REGISTRY}-frontend:${TAG}" \
    --tag "${REGISTRY}-frontend:latest" \
    --file frontend/app/Dockerfile \
    ./frontend/app

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Frontend image built successfully${NC}"
else
    echo -e "${RED}✗ Failed to build frontend image${NC}"
    exit 1
fi
echo ""

# ==============================================================================
# Push Images
# ==============================================================================
echo -e "${YELLOW}[5/5]${NC} Pushing images to Docker Hub..."
echo ""

echo -e "${BLUE}Pushing backend:${TAG}...${NC}"
docker push "${REGISTRY}-backend:${TAG}"

echo -e "${BLUE}Pushing backend:latest...${NC}"
docker push "${REGISTRY}-backend:latest"

echo -e "${BLUE}Pushing frontend:${TAG}...${NC}"
docker push "${REGISTRY}-frontend:${TAG}"

echo -e "${BLUE}Pushing frontend:latest...${NC}"
docker push "${REGISTRY}-frontend:latest"

echo ""

# ==============================================================================
# Resumo
# ==============================================================================
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Push concluído com sucesso!                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${YELLOW}Backend:${NC}"
echo "    - https://hub.docker.com/r/${REGISTRY}-backend/tags"
echo "    - docker pull ${REGISTRY}-backend:${TAG}"
echo ""
echo -e "  ${YELLOW}Frontend:${NC}"
echo "    - https://hub.docker.com/r/${REGISTRY}-frontend/tags"
echo "    - docker pull ${REGISTRY}-frontend:${TAG}"
echo ""

# ==============================================================================
# Próximos passos
# ==============================================================================
echo -e "${YELLOW}Próximos passos:${NC}"
echo "  1. Atualizar docker-compose.yml para usar as imagens do Docker Hub:"
echo "     - image: ${REGISTRY}-backend:${TAG}"
echo "     - image: ${REGISTRY}-frontend:${TAG}"
echo ""
echo "  2. Ou atualizar sdk.yml para Portainer com as mesmas imagens"
echo ""
