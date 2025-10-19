#!/bin/bash
# ==============================================================================
# Script: Build and Push Docker Images to Docker Hub (Simplified)
# ==============================================================================
# Objetivo: Build e fazer push das imagens Docker para Docker Hub
# Uso: nohup ./push-to-hub-simple.sh latest > push.log 2>&1 &
#      tail -f push.log
# ==============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuração
DOCKER_USERNAME="johannalves"
DOCKER_REPO="sdk"
TAG="${1:-latest}"
REGISTRY="${DOCKER_USERNAME}/${DOCKER_REPO}"

# ==============================================================================
# Funções auxiliares
# ==============================================================================
log_step() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] ✓${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ✗${NC} $1"
}

# ==============================================================================
# Main
# ==============================================================================

echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}DOM360 SDK - Build & Push to Docker Hub${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo ""

log_step "Registry: $REGISTRY"
log_step "Tag: $TAG"
echo ""

# Build Backend
log_step "Building backend image..."
if docker build \
    --tag "${REGISTRY}-backend:${TAG}" \
    --tag "${REGISTRY}-backend:latest" \
    --file Dockerfile \
    . > /tmp/backend-build.log 2>&1; then
    log_success "Backend image built: ${REGISTRY}-backend:${TAG}"
else
    log_error "Failed to build backend image"
    cat /tmp/backend-build.log
    exit 1
fi
echo ""

# Build Frontend
log_step "Building frontend image..."
if docker build \
    --tag "${REGISTRY}-frontend:${TAG}" \
    --tag "${REGISTRY}-frontend:latest" \
    --file frontend/app/Dockerfile \
    ./frontend/app > /tmp/frontend-build.log 2>&1; then
    log_success "Frontend image built: ${REGISTRY}-frontend:${TAG}"
else
    log_error "Failed to build frontend image"
    cat /tmp/frontend-build.log
    exit 1
fi
echo ""

# Push Backend
log_step "Pushing backend:${TAG}..."
if docker push "${REGISTRY}-backend:${TAG}" > /tmp/backend-push.log 2>&1; then
    log_success "Pushed ${REGISTRY}-backend:${TAG}"
else
    log_error "Failed to push backend:${TAG}"
    tail -20 /tmp/backend-push.log
    exit 1
fi

log_step "Pushing backend:latest..."
if docker push "${REGISTRY}-backend:latest" > /tmp/backend-push-latest.log 2>&1; then
    log_success "Pushed ${REGISTRY}-backend:latest"
else
    log_error "Failed to push backend:latest"
    tail -20 /tmp/backend-push-latest.log
    exit 1
fi
echo ""

# Push Frontend
log_step "Pushing frontend:${TAG}..."
if docker push "${REGISTRY}-frontend:${TAG}" > /tmp/frontend-push.log 2>&1; then
    log_success "Pushed ${REGISTRY}-frontend:${TAG}"
else
    log_error "Failed to push frontend:${TAG}"
    tail -20 /tmp/frontend-push.log
    exit 1
fi

log_step "Pushing frontend:latest..."
if docker push "${REGISTRY}-frontend:latest" > /tmp/frontend-push-latest.log 2>&1; then
    log_success "Pushed ${REGISTRY}-frontend:latest"
else
    log_error "Failed to push frontend:latest"
    tail -20 /tmp/frontend-push-latest.log
    exit 1
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Push concluído com sucesso!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "Imagens disponíveis no Docker Hub:"
echo ""
echo -e "  ${YELLOW}Backend:${NC}"
echo "    - ${REGISTRY}-backend:${TAG}"
echo "    - ${REGISTRY}-backend:latest"
echo "    - URL: https://hub.docker.com/r/${REGISTRY}-backend"
echo ""
echo -e "  ${YELLOW}Frontend:${NC}"
echo "    - ${REGISTRY}-frontend:${TAG}"
echo "    - ${REGISTRY}-frontend:latest"
echo "    - URL: https://hub.docker.com/r/${REGISTRY}-frontend"
echo ""
echo -e "Comandos para usar as imagens:"
echo "    docker pull ${REGISTRY}-backend:${TAG}"
echo "    docker pull ${REGISTRY}-frontend:${TAG}"
echo ""

# Atualizar docker-compose
echo -e "${YELLOW}Próximas etapas:${NC}"
echo "  1. Atualizar docker-compose.yml com as imagens do Hub (opcional)"
echo "  2. Atualizar sdk.yml para Portainer (opcional)"
echo ""
echo "  Exemplo para docker-compose.yml:"
echo "    backend:"
echo "      image: ${REGISTRY}-backend:${TAG}"
echo "    frontend:"
echo "      image: ${REGISTRY}-frontend:${TAG}"
echo ""
