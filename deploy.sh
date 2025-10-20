#!/bin/bash

# ============================================================================
# SDK Deploy Script - Docker Swarm
# Uso: ./deploy.sh [build|deploy|update|status|logs|down]
# ============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
STACK_NAME="sdk"
REGISTRY=""  # Deixe vazio para usar imagens locais

# Funções auxiliares
print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  $1"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Verificar se está em Swarm Mode
check_swarm() {
    if ! docker info | grep -q "Swarm: active"; then
        print_error "Docker não está em Swarm Mode!"
        print_info "Execute: docker swarm init"
        exit 1
    fi
    print_success "Docker Swarm está ativo"
}

# Verificar se a rede existe
check_network() {
    if ! docker network ls | grep -q "network_public"; then
        print_error "Rede 'network_public' não encontrada!"
        print_info "Execute: docker network create -d overlay network_public"
        exit 1
    fi
    print_success "Rede 'network_public' existe"
}

# Build das imagens
build_images() {
    print_header "Fazendo Build das Imagens"
    
    print_info "Building backend..."
    docker build -f Dockerfile.backend -t sdk-backend:latest .
    print_success "Backend built"
    
    print_info "Building frontend..."
    docker build -f Dockerfile.frontend -t sdk-frontend:latest .
    print_success "Frontend built"
}

# Deploy do stack
deploy_stack() {
    print_header "Deployando Stack"
    
    check_swarm
    check_network
    
    print_info "Deployando $STACK_NAME..."
    docker stack deploy -c docker-stack.yml $STACK_NAME
    print_success "Stack $STACK_NAME deployado com sucesso!"
}

# Atualizar stack
update_stack() {
    print_header "Atualizando Stack"
    
    build_images
    deploy_stack
}

# Status do stack
show_status() {
    print_header "Status do Stack $STACK_NAME"
    
    print_info "Serviços:"
    docker stack services $STACK_NAME
    
    echo ""
    print_info "Tasks:"
    docker stack ps $STACK_NAME
}

# Logs
show_logs() {
    local service=${1:-backend}
    print_header "Logs do serviço: $service"
    
    docker service logs $STACK_NAME"_"$service -f 2>/dev/null || print_error "Serviço não encontrado"
}

# Down - remover stack
remove_stack() {
    print_header "Removendo Stack"
    
    read -p "Você tem certeza que quer remover o stack $STACK_NAME? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        docker stack rm $STACK_NAME
        print_success "Stack $STACK_NAME removido"
    else
        print_warning "Operação cancelada"
    fi
}

# Main
case "${1:-help}" in
    build)
        build_images
        ;;
    deploy)
        deploy_stack
        ;;
    update)
        update_stack
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs ${2:-backend}
        ;;
    down)
        remove_stack
        ;;
    *)
        echo "Uso: $0 [COMANDO]"
        echo ""
        echo "Comandos disponíveis:"
        echo "  build       - Fazer build das imagens Docker"
        echo "  deploy      - Deployar o stack no Docker Swarm"
        echo "  update      - Build + Deploy (rebuild e redeploy)"
        echo "  status      - Mostrar status dos serviços"
        echo "  logs        - Mostrar logs (ex: logs backend)"
        echo "  down        - Remover o stack"
        echo ""
        echo "Exemplos:"
        echo "  $0 build"
        echo "  $0 deploy"
        echo "  $0 logs backend"
        echo "  $0 logs frontend"
        ;;
esac
