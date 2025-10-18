#!/bin/bash

# ============================================================================
# DOM360 - Script de Setup para Produção
# Preparação completa da aplicação com DNS, Nginx e SSL
# ============================================================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Diretório base
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# Funções Auxiliares
# ============================================================================

print_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║         DOM360 - Production Setup Script                 ║
║      Configure DNS, Nginx e SSL para Produção            ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_section() {
    echo ""
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

ask_question() {
    read -p "$1: " answer
    echo "$answer"
}

yes_no_question() {
    read -p "$1 (y/n): " answer
    [[ $answer == "y" || $answer == "Y" ]]
}

# ============================================================================
# Verificações Iniciais
# ============================================================================

check_requirements() {
    print_section "Verificando Dependências"
    
    # Verificar sudo
    if ! sudo -n true 2>/dev/null; then
        print_error "Requer acesso sudo (não interativo)"
        exit 1
    fi
    print_success "Sudo disponível"
    
    # Verificar se está em servidor
    if [ -z "$VARNISH" ] && [ ! -f "/.dockerenv" ]; then
        print_warning "Não está em um container, continuando..."
    fi
    
    # Verificar nginx
    if ! command -v nginx &> /dev/null; then
        print_error "Nginx não está instalado"
        exit 1
    fi
    print_success "Nginx instalado"
    
    # Verificar certbot
    if ! command -v certbot &> /dev/null; then
        print_warning "Certbot não está instalado (será necessário para SSL)"
    else
        print_success "Certbot disponível"
    fi
    
    # Verificar envsubst
    if ! command -v envsubst &> /dev/null; then
        print_error "envsubst não está instalado (requirido)"
        exit 1
    fi
    print_success "envsubst disponível"
}

# ============================================================================
# Menu Principal
# ============================================================================

show_menu() {
    echo ""
    echo -e "${CYAN}Escolha o modo de configuração:${NC}"
    echo ""
    echo "1) Configurar para IPv4 Direto (173.249.37.232)"
    echo "2) Configurar para Domínio (srcjohann.com.br) com HTTPS"
    echo "3) Apenas Validar Configuração"
    echo "4) Testar Conectividade"
    echo "5) Sair"
    echo ""
    
    read -p "Opção [1-5]: " option
}

# ============================================================================
# Configurar IPv4
# ============================================================================

setup_ipv4() {
    print_section "Configurando para IPv4 Direto"
    
    # Copiar .env
    print_section "1/4: Preparando variáveis de ambiente"
    cp "$BASE_DIR/.env.prod-ip" "$BASE_DIR/.env"
    print_success "Arquivo .env copiado de .env.prod-ip"
    
    # Rebuildar frontend
    print_section "2/4: Rebuildar Frontend"
    cd "$BASE_DIR/frontend/app"
    if yes_no_question "Fazer rebuild do frontend? (recomendado)"; then
        npm run build
        print_success "Frontend rebuilado"
    fi
    cd "$BASE_DIR"
    
    # Configurar Nginx
    print_section "3/4: Configurando Nginx"
    source "$BASE_DIR/.env"
    envsubst < "$BASE_DIR/nginx.conf" | sudo tee /etc/nginx/sites-available/dom360 > /dev/null
    print_success "Nginx configurado com envsubst"
    
    # Criar symlink
    if [ ! -L /etc/nginx/sites-enabled/dom360 ]; then
        sudo ln -s /etc/nginx/sites-available/dom360 /etc/nginx/sites-enabled/dom360
        print_success "Symlink criado em sites-enabled"
    fi
    
    # Testar Nginx
    print_section "4/4: Testando Nginx"
    if sudo nginx -t 2>&1 | grep -q "successful"; then
        print_success "Nginx configuration OK"
        sudo systemctl restart nginx
        print_success "Nginx reiniciado"
    else
        print_error "Nginx configuration tem erros"
        return 1
    fi
    
    echo ""
    echo -e "${GREEN}✓ Configuração para IPv4 completa!${NC}"
    echo ""
    echo "Próximos passos:"
    echo "1. Iniciar a aplicação: ./start.sh"
    echo "2. Testar conectividade: curl http://173.249.37.232"
    echo ""
}

# ============================================================================
# Configurar Domínio
# ============================================================================

setup_domain() {
    print_section "Configurando para Domínio com HTTPS"
    
    # Obter informações do domínio
    DOMAIN=$(ask_question "Digite o domínio (ex: srcjohann.com.br)")
    API_DOMAIN="api.$DOMAIN"
    
    echo ""
    print_section "Configuração do Domínio"
    echo "Frontend: https://$DOMAIN"
    echo "Backend:  https://$API_DOMAIN"
    echo ""
    
    if ! yes_no_question "Confirmar?"; then
        print_warning "Cancelado"
        return 1
    fi
    
    # Atualizar .env com domínio
    print_section "1/4: Preparando variáveis de ambiente"
    sed "s/srcjohann\.com\.br/$DOMAIN/g" "$BASE_DIR/.env.prod-domain" > "$BASE_DIR/.env"
    print_success "Arquivo .env configurado com domínio $DOMAIN"
    
    # Rebuildar frontend
    print_section "2/4: Rebuildar Frontend"
    cd "$BASE_DIR/frontend/app"
    if yes_no_question "Fazer rebuild do frontend? (recomendado)"; then
        npm run build
        print_success "Frontend rebuilado"
    fi
    cd "$BASE_DIR"
    
    # Configurar Nginx
    print_section "3/4: Configurando Nginx"
    source "$BASE_DIR/.env"
    envsubst < "$BASE_DIR/nginx.conf" | sudo tee /etc/nginx/sites-available/dom360 > /dev/null
    print_success "Nginx configurado com envsubst"
    
    # Criar symlink
    if [ ! -L /etc/nginx/sites-enabled/dom360 ]; then
        sudo ln -s /etc/nginx/sites-available/dom360 /etc/nginx/sites-enabled/dom360
        print_success "Symlink criado em sites-enabled"
    fi
    
    # Testar Nginx
    if ! sudo nginx -t 2>&1 | grep -q "successful"; then
        print_error "Nginx configuration tem erros"
        return 1
    fi
    print_success "Nginx configuration OK"
    
    # Certbot
    print_section "4/4: Configurando SSL com Certbot"
    echo ""
    echo "Será necessário:"
    echo "1. Domínio apontando para IP: 173.249.37.232"
    echo "2. Porta 80 aberta (Certbot precisa validar)"
    echo ""
    
    if yes_no_question "Continuar com Certbot?"; then
        sudo certbot --nginx -d "$DOMAIN" -d "$API_DOMAIN"
        print_success "Certificado SSL configurado"
        sudo systemctl restart nginx
        print_success "Nginx reiniciado com SSL"
    else
        print_warning "SSL não foi configurado"
        sudo systemctl restart nginx
    fi
    
    echo ""
    echo -e "${GREEN}✓ Configuração para Domínio completa!${NC}"
    echo ""
    echo "Próximos passos:"
    echo "1. Verificar DNS: nslookup $DOMAIN"
    echo "2. Iniciar a aplicação: ./start.sh"
    echo "3. Testar: curl https://$DOMAIN"
    echo ""
}

# ============================================================================
# Validar Configuração
# ============================================================================

validate_config() {
    print_section "Validando Configuração"
    echo ""
    
    # Verificar .env
    if [ ! -f "$BASE_DIR/.env" ]; then
        print_error ".env não encontrado"
        return 1
    fi
    print_success ".env existe"
    
    # Verificar variáveis essenciais
    source "$BASE_DIR/.env" 2>/dev/null || true
    
    if [ -z "$VITE_API_URL" ]; then
        print_error "VITE_API_URL não definido"
    else
        print_success "VITE_API_URL: $VITE_API_URL"
    fi
    
    if [ -z "$PUBLIC_BACKEND_URL" ]; then
        print_error "PUBLIC_BACKEND_URL não definido"
    else
        print_success "PUBLIC_BACKEND_URL: $PUBLIC_BACKEND_URL"
    fi
    
    if [ -z "$JWT_SECRET" ]; then
        print_error "JWT_SECRET não definido"
    else
        print_success "JWT_SECRET: ****"
    fi
    
    # Verificar Nginx
    print_section "Status do Nginx"
    if sudo systemctl is-active --quiet nginx; then
        print_success "Nginx está rodando"
    else
        print_warning "Nginx não está rodando"
    fi
    
    # Verificar configuração Nginx
    if [ -f /etc/nginx/sites-available/dom360 ]; then
        print_success "Arquivo de configuração Nginx existe"
        if sudo nginx -t 2>&1 | grep -q "successful"; then
            print_success "Configuração Nginx válida"
        else
            print_error "Configuração Nginx tem erros"
            sudo nginx -t
        fi
    else
        print_warning "Arquivo de configuração Nginx não encontrado"
    fi
    
    # Verificar SSL
    if [ -d /etc/letsencrypt/live ]; then
        print_success "Certbot está instalado"
        CERTS=$(sudo ls /etc/letsencrypt/live/ 2>/dev/null | wc -l)
        if [ $CERTS -gt 0 ]; then
            print_success "Certificados SSL encontrados: $CERTS"
            sudo certbot certificates
        else
            print_warning "Nenhum certificado SSL encontrado"
        fi
    fi
    
    echo ""
}

# ============================================================================
# Testar Conectividade
# ============================================================================

test_connectivity() {
    print_section "Testando Conectividade"
    echo ""
    
    # Testar DNS
    print_section "Teste de DNS"
    if yes_no_question "Testar resolução de domínio? (digite domínio quando pedido)"; then
        DOMAIN=$(ask_question "Digite o domínio (ex: srcjohann.com.br)")
        echo ""
        if command -v dig &> /dev/null; then
            dig "$DOMAIN"
        else
            nslookup "$DOMAIN"
        fi
    fi
    
    # Testar HTTP
    print_section "Teste de Conectividade HTTP"
    echo ""
    echo "Teste com IPv4:"
    echo "  curl -v http://173.249.37.232"
    echo ""
    echo "Teste com Domínio:"
    echo "  curl -v http://example.com"
    echo ""
    echo "Teste com HTTPS:"
    echo "  curl -v https://example.com"
    echo ""
    
    if yes_no_question "Executar teste? (será pedido um URL)"; then
        URL=$(ask_question "Digite a URL (ex: http://173.249.37.232)")
        echo ""
        curl -v "$URL" 2>&1 | head -20
    fi
    
    # Testar API
    print_section "Teste de API Health"
    if yes_no_question "Testar health check da API?"; then
        API_URL=$(ask_question "Digite a URL da API (ex: http://173.249.37.232)")
        echo ""
        curl -v "$API_URL/api/health"
    fi
    
    echo ""
}

# ============================================================================
# Loop Principal
# ============================================================================

main() {
    print_banner
    check_requirements
    
    while true; do
        show_menu
        
        case $option in
            1)
                setup_ipv4
                ;;
            2)
                setup_domain
                ;;
            3)
                validate_config
                ;;
            4)
                test_connectivity
                ;;
            5)
                echo ""
                print_success "Até logo!"
                exit 0
                ;;
            *)
                print_error "Opção inválida"
                ;;
        esac
    done
}

# ============================================================================
# Executar
# ============================================================================

main
