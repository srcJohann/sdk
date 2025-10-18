#!/bin/bash

# ==============================================================================
# DOM360 - Deploy Script para VPS com Docker
# Instala Docker, Docker Compose e faz deploy da aplicação
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

print_step() {
    echo -e "${BLUE}[→]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# ==============================================================================
# Main Script
# ==============================================================================

print_header "DOM360 - Deploy para VPS com Docker"

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    print_error "Este script deve ser executado como root (use: sudo ./deploy-docker.sh)"
    exit 1
fi

# ==============================================================================
# 1. Atualizar sistema
# ==============================================================================

print_step "Atualizando sistema..."
apt-get update -qq
apt-get upgrade -y -qq > /dev/null 2>&1
print_success "Sistema atualizado"

# ==============================================================================
# 2. Instalar Docker
# ==============================================================================

print_step "Verificando Docker..."

if ! command -v docker &> /dev/null; then
    print_warning "Docker não encontrado. Instalando..."
    
    # Remover versões antigas
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Instalar dependências
    apt-get install -y -qq ca-certificates curl gnupg lsb-release > /dev/null 2>&1
    
    # Adicionar chave GPG do Docker
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Adicionar repositório
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Instalar Docker
    apt-get update -qq > /dev/null 2>&1
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null 2>&1
    
    # Habilitar Docker
    systemctl enable docker
    systemctl start docker
    
    print_success "Docker instalado"
else
    print_success "Docker já está instalado: $(docker --version)"
fi

# ==============================================================================
# 3. Instalar Docker Compose
# ==============================================================================

print_step "Verificando Docker Compose..."

if ! command -v docker-compose &> /dev/null; then
    print_warning "Docker Compose não encontrado. Instalando..."
    
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    print_success "Docker Compose instalado: $(docker-compose --version)"
else
    print_success "Docker Compose já está instalado: $(docker-compose --version)"
fi

# ==============================================================================
# 4. Clonar/atualizar repositório
# ==============================================================================

DEPLOY_DIR="/opt/dom360"

print_step "Configurando diretório de deploy: $DEPLOY_DIR"

if [ ! -d "$DEPLOY_DIR" ]; then
    print_warning "Diretório não existe. Criando..."
    mkdir -p "$DEPLOY_DIR"
else
    print_success "Diretório já existe"
fi

# ==============================================================================
# 5. Preparar arquivos .env
# ==============================================================================

print_step "Verificando configuração de ambiente..."

if [ ! -f "$DEPLOY_DIR/.env" ]; then
    print_warning ".env não encontrado em $DEPLOY_DIR"
    
    if [ -f ".env.production" ]; then
        cp .env.production "$DEPLOY_DIR/.env"
        print_success "Copiado .env.production para $DEPLOY_DIR/.env"
        print_warning "⚠️  EDITE O ARQUIVO .env ANTES DE CONTINUAR!"
        print_warning "   sudo nano $DEPLOY_DIR/.env"
        echo ""
        read -p "Pressione ENTER quando terminar de configurar o .env..."
    else
        print_error ".env.production não encontrado"
        exit 1
    fi
else
    print_success ".env já configurado"
fi

# ==============================================================================
# 6. Build e Deploy
# ==============================================================================

print_step "Preparando aplicação..."

# Se este script foi executado do diretório raiz do projeto
if [ -f "docker-compose.yml" ] && [ -f "Dockerfile" ]; then
    cp -r . "$DEPLOY_DIR/" 2>/dev/null || true
    print_success "Arquivos copiados para $DEPLOY_DIR"
fi

cd "$DEPLOY_DIR"

print_step "Fazendo build das imagens Docker..."
docker-compose build --no-cache > /dev/null 2>&1
print_success "Build concluído"

print_step "Iniciando containers..."
docker-compose up -d
print_success "Containers iniciados"

# ==============================================================================
# 7. Verificações finais
# ==============================================================================

print_step "Aguardando serviços ficarem prontos..."
sleep 10

print_step "Verificando status..."

# Backend
if docker exec dom360-backend curl -s http://localhost:3001/api/health > /dev/null 2>&1; then
    print_success "Backend está respondendo ✓"
else
    print_warning "Backend pode estar iniciando ainda..."
fi

# PostgreSQL
if docker exec dom360-postgres pg_isready -U postgres > /dev/null 2>&1; then
    print_success "PostgreSQL está respondendo ✓"
else
    print_error "PostgreSQL não está respondendo"
fi

# ==============================================================================
# 8. Instruções finais
# ==============================================================================

print_header "✓ Deployment Concluído!"

echo -e "${CYAN}Informações de Acesso:${NC}"
echo ""
echo "  🌐 Frontend:  http://$(hostname -I | awk '{print $1}'):5173"
echo "  🔧 API:       http://$(hostname -I | awk '{print $1}'):3001"
echo "  📚 Docs API:  http://$(hostname -I | awk '{print $1}'):3001/docs"
echo "  🗄️  Database: porta 5432 (localhost)"
echo ""

echo -e "${CYAN}Comandos Úteis:${NC}"
echo ""
echo "  Ver status dos containers:"
echo "    docker-compose -f $DEPLOY_DIR/docker-compose.yml ps"
echo ""
echo "  Ver logs do backend:"
echo "    docker-compose -f $DEPLOY_DIR/docker-compose.yml logs -f backend"
echo ""
echo "  Ver logs do banco:"
echo "    docker-compose -f $DEPLOY_DIR/docker-compose.yml logs -f postgres"
echo ""
echo "  Parar serviços:"
echo "    docker-compose -f $DEPLOY_DIR/docker-compose.yml down"
echo ""
echo "  Reiniciar:"
echo "    docker-compose -f $DEPLOY_DIR/docker-compose.yml restart"
echo ""
echo "  Shell do backend:"
echo "    docker exec -it dom360-backend bash"
echo ""
echo "  Shell do PostgreSQL:"
echo "    docker exec -it dom360-postgres psql -U postgres -d dom360_db_sdk"
echo ""

echo -e "${CYAN}Próximos Passos:${NC}"
echo ""
echo "  1. Configure seu domínio (DNS)"
echo "     Aponte seu domínio para: $(hostname -I | awk '{print $1}')"
echo ""
echo "  2. Configure SSL/HTTPS com Let's Encrypt"
echo "     sudo apt install certbot python3-certbot-nginx"
echo "     sudo certbot certonly --standalone -d seu-dominio.com"
echo ""
echo "  3. Configure Nginx para reverse proxy e SSL"
echo "     Edite: $DEPLOY_DIR/nginx.conf"
echo "     docker-compose up -d nginx (com profile nginx)"
echo ""
echo "  4. Monitore os logs:"
echo "     tail -f $DEPLOY_DIR/logs/*.log"
echo ""

print_header "Deployment Concluído!"
