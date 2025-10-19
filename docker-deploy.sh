#!/bin/bash

# ==============================================================================
# Docker Deployment Script - SDK DOM360
# ==============================================================================
# Este script automatiza o deployment da aplicação no Docker
# Uso: ./deploy.sh [up|down|restart|logs|build]
# ==============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# ==============================================================================
# Funções
# ==============================================================================

print_header() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  $1"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

check_prerequisites() {
    print_header "Verificando Pré-requisitos"
    
    # Verificar Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker não está instalado"
        exit 1
    fi
    print_success "Docker instalado"
    
    # Verificar Docker Compose
    if ! command -v docker compose &> /dev/null; then
        print_error "Docker Compose não está instalado"
        exit 1
    fi
    print_success "Docker Compose instalado"
    
    # Verificar .env
    if [ ! -f .env ]; then
        print_error ".env não encontrado"
        print_info "Criando .env a partir de .env.example..."
        cp .env.example .env
        print_info "Configure o arquivo .env com suas variáveis e tente novamente"
        exit 1
    fi
    print_success "Arquivo .env encontrado"
    
    # Verificar PostgreSQL na VPS
    DB_HOST=$(grep "^DB_HOST=" .env | cut -d'=' -f2 | tr -d '\r')
    DB_PORT=$(grep "^DB_PORT=" .env | cut -d'=' -f2 | tr -d '\r')
    DB_USER=$(grep "^DB_USER=" .env | cut -d'=' -f2 | tr -d '\r')
    
    if ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" &> /dev/null; then
        print_error "PostgreSQL não está acessível em $DB_HOST:$DB_PORT"
        print_info "Verifique se PostgreSQL está rodando na VPS"
        exit 1
    fi
    print_success "PostgreSQL acessível em $DB_HOST:$DB_PORT"
}

build_images() {
    print_header "Build das Imagens Docker"
    
    docker compose build --no-cache
    
    print_success "Imagens buildadas com sucesso"
}

start_services() {
    print_header "Iniciando Serviços"
    
    docker compose up -d
    
    print_success "Serviços iniciados"
    print_info "Aguardando health checks..."
    
    sleep 5
    
    # Mostrar status
    docker compose ps
    
    print_success "Backend disponível em http://localhost:3001"
    print_success "Frontend disponível em http://localhost:5173"
}

stop_services() {
    print_header "Parando Serviços"
    
    docker compose down
    
    print_success "Serviços parados"
}

restart_services() {
    print_header "Reiniciando Serviços"
    
    stop_services
    sleep 2
    start_services
}

show_logs() {
    print_header "Logs dos Serviços"
    
    SERVICE=${1:-""}
    
    if [ -z "$SERVICE" ]; then
        docker compose logs -f
    else
        docker compose logs -f "$SERVICE"
    fi
}

show_status() {
    print_header "Status dos Serviços"
    
    docker compose ps
    
    echo ""
    print_info "Testando endpoints..."
    echo ""
    
    if curl -s http://localhost:3001/api/health > /dev/null; then
        print_success "Backend está saudável"
    else
        print_error "Backend não respondeu"
    fi
    
    if curl -s http://localhost:5173/ > /dev/null; then
        print_success "Frontend está saudável"
    else
        print_error "Frontend não respondeu"
    fi
}

show_help() {
    cat << EOF
${BLUE}Docker Deployment Script - SDK DOM360${NC}

Uso: $0 [COMANDO]

Comandos disponíveis:
  ${GREEN}up${NC}        - Build e iniciar os containers
  ${GREEN}down${NC}      - Parar os containers
  ${GREEN}restart${NC}   - Reiniciar os containers
  ${GREEN}logs${NC}      - Mostrar logs dos containers
  ${GREEN}status${NC}    - Mostrar status dos serviços
  ${GREEN}build${NC}     - Build das imagens (sem cache)
  ${GREEN}clean${NC}     - Remover containers, volumes e imagens
  ${GREEN}help${NC}      - Mostrar esta mensagem

Exemplos:
  $0 up              # Build e iniciar
  $0 logs backend    # Logs apenas do backend
  $0 logs frontend   # Logs apenas do frontend
  $0 restart         # Reiniciar tudo

EOF
}

clean_all() {
    print_header "Limpando Recursos Docker"
    
    print_info "Removendo containers, volumes e imagens..."
    docker compose down -v --rmi all
    
    print_success "Limpeza concluída"
}

# ==============================================================================
# Main
# ==============================================================================

COMMAND=${1:-"help"}

case "$COMMAND" in
    up)
        check_prerequisites
        build_images
        start_services
        show_status
        ;;
    down)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    logs)
        show_logs "$2"
        ;;
    status)
        show_status
        ;;
    build)
        check_prerequisites
        build_images
        ;;
    clean)
        clean_all
        ;;
    help)
        show_help
        ;;
    *)
        print_error "Comando desconhecido: $COMMAND"
        show_help
        exit 1
        ;;
esac
