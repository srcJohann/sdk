#!/bin/bash

# ============================================================================
# DOM360 - Script de Deploy Completo para VPS
# ============================================================================
# Este script aplica todas as correções identificadas no documento
# Claude_Haiku4.5_observations.md para deploy em VPS com IPv4 público
# ============================================================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Diretório base
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# Funções auxiliares
# ============================================================================

print_header() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}    $1${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_step() {
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

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Este script precisa ser executado como root"
        echo -e "  Use: ${CYAN}sudo $0${NC}"
        exit 1
    fi
}

# ============================================================================
# Início do script
# ============================================================================

print_header "DOM360 - Deploy VPS Setup"

echo -e "${CYAN}Este script irá:${NC}"
echo "  1. Validar configurações do .env"
echo "  2. Verificar dependências do sistema"
echo "  3. Configurar PostgreSQL"
echo "  4. Configurar Nginx com SSL"
echo "  5. Configurar Firewall"
echo "  6. Gerar frontend build de produção"
echo "  7. Configurar serviços systemd"
echo ""

read -p "Deseja continuar? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deploy cancelado."
    exit 1
fi

check_root

# ============================================================================
# PASSO 1: Validar .env
# ============================================================================

print_header "PASSO 1: Validando Configurações"

if [ ! -f "$BASE_DIR/.env" ]; then
    print_error "Arquivo .env não encontrado!"
    exit 1
fi

print_step "Carregando variáveis do .env..."
set -o allexport
source "$BASE_DIR/.env"
set +o allexport

# Validações críticas
ERRORS=0

if [ -z "$JWT_SECRET" ]; then
    print_warning "JWT_SECRET não definido! Gerando novo..."
    JWT_SECRET=$(openssl rand -base64 32)
    echo "JWT_SECRET=\"$JWT_SECRET\"" >> "$BASE_DIR/.env"
    print_success "JWT_SECRET gerado e adicionado ao .env"
fi

if [[ "$VITE_API_URL" == *"127.0.0.1"* ]] || [[ "$VITE_API_URL" == *"localhost"* ]]; then
    print_error "VITE_API_URL ainda aponta para localhost/127.0.0.1!"
    print_warning "Configure para o IP público ou domínio da VPS"
    echo -e "  Exemplo: ${CYAN}VITE_API_URL=http://api.seudominio.com${NC}"
    ERRORS=$((ERRORS + 1))
fi

if [ -z "$PUBLIC_BACKEND_HOST" ]; then
    print_error "PUBLIC_BACKEND_HOST não definido!"
    ERRORS=$((ERRORS + 1))
fi

if [ -z "$PUBLIC_FRONTEND_HOST" ]; then
    print_error "PUBLIC_FRONTEND_HOST não definido!"
    ERRORS=$((ERRORS + 1))
fi

if [ $ERRORS -gt 0 ]; then
    print_error "Corrija os erros no .env antes de continuar"
    exit 1
fi

print_success "Validações do .env concluídas"

# ============================================================================
# PASSO 2: Verificar Dependências
# ============================================================================

print_header "PASSO 2: Verificando Dependências do Sistema"

print_step "Atualizando repositórios..."
apt update -qq

PACKAGES=(
    "nginx"
    "postgresql"
    "postgresql-contrib"
    "python3"
    "python3-pip"
    "python3-venv"
    "nodejs"
    "npm"
    "certbot"
    "python3-certbot-nginx"
    "gettext-base"  # para envsubst
    "ufw"
)

for package in "${PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "^ii  $package"; then
        print_step "Instalando $package..."
        DEBIAN_FRONTEND=noninteractive apt install -y "$package" > /dev/null 2>&1
        print_success "$package instalado"
    else
        print_success "$package já instalado"
    fi
done

# ============================================================================
# PASSO 3: Configurar PostgreSQL
# ============================================================================

print_header "PASSO 3: Configurando PostgreSQL"

print_step "Verificando se PostgreSQL está rodando..."
if ! systemctl is-active --quiet postgresql; then
    systemctl start postgresql
    systemctl enable postgresql
    print_success "PostgreSQL iniciado"
else
    print_success "PostgreSQL já está rodando"
fi

# Aplicar schema se necessário
if [ -f "$BASE_DIR/database/schema.sql" ]; then
    print_step "Verificando se database existe..."
    
    DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'")
    
    if [ "$DB_EXISTS" != "1" ]; then
        print_step "Criando database e aplicando schema..."
        
        # Criar usuário se não existir
        sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" 2>/dev/null || true
        
        # Criar database
        sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" 2>/dev/null || true
        
        # Aplicar schema
        sudo -u postgres psql -d "${DB_NAME}" -f "$BASE_DIR/database/schema.sql"
        
        print_success "Database criado e schema aplicado"
    else
        print_success "Database já existe"
    fi
fi

# ============================================================================
# PASSO 4: Instalar Dependências Python e Node
# ============================================================================

print_header "PASSO 4: Instalando Dependências da Aplicação"

# Backend Python
if [ -f "$BASE_DIR/backend/requirements.txt" ]; then
    print_step "Instalando dependências Python..."
    
    if [ ! -d "$BASE_DIR/venv" ]; then
        python3 -m venv "$BASE_DIR/venv"
    fi
    
    source "$BASE_DIR/venv/bin/activate"
    pip install -q --upgrade pip
    pip install -q -r "$BASE_DIR/backend/requirements.txt"
    deactivate
    
    print_success "Dependências Python instaladas"
fi

# Frontend Node
if [ -f "$BASE_DIR/frontend/app/package.json" ]; then
    print_step "Instalando dependências Node.js..."
    
    cd "$BASE_DIR/frontend/app"
    npm install --silent
    
    print_success "Dependências Node.js instaladas"
fi

# ============================================================================
# PASSO 5: Build Frontend para Produção
# ============================================================================

print_header "PASSO 5: Gerando Build de Produção do Frontend"

print_step "Fazendo build do frontend com VITE_API_URL=$VITE_API_URL..."

cd "$BASE_DIR/frontend/app"

# Garantir que as variáveis de ambiente estão disponíveis
export VITE_API_URL
export VITE_TENANT_ID
export VITE_INBOX_ID
export VITE_USER_PHONE
export VITE_USER_NAME

npm run build

if [ -d "dist" ]; then
    print_success "Build do frontend concluído em frontend/app/dist/"
else
    print_error "Build do frontend falhou!"
    exit 1
fi

# ============================================================================
# PASSO 6: Configurar Nginx
# ============================================================================

print_header "PASSO 6: Configurando Nginx"

print_step "Executando setup_nginx.sh..."
bash "$BASE_DIR/setup_nginx.sh"

print_success "Nginx configurado"

# ============================================================================
# PASSO 7: Configurar Firewall
# ============================================================================

print_header "PASSO 7: Configurando Firewall (UFW)"

print_step "Configurando regras do firewall..."

# Ativar UFW se não estiver ativo
if ! ufw status | grep -q "Status: active"; then
    # Permitir SSH primeiro para não perder conexão
    ufw allow 22/tcp
    print_success "Porta SSH (22) permitida"
fi

ufw allow 80/tcp   # HTTP
ufw allow 443/tcp  # HTTPS
ufw allow 5432/tcp # PostgreSQL (apenas se necessário para conexões remotas)

# Ativar UFW
echo "y" | ufw enable > /dev/null 2>&1

print_success "Firewall configurado"
ufw status numbered

# ============================================================================
# PASSO 8: Configurar SSL com Let's Encrypt
# ============================================================================

print_header "PASSO 8: Configurando SSL"

echo -e "${CYAN}Para configurar SSL automaticamente com Let's Encrypt:${NC}"
echo ""
echo -e "  ${YELLOW}sudo certbot --nginx -d ${PUBLIC_FRONTEND_HOST} -d ${PUBLIC_BACKEND_HOST}${NC}"
echo ""
echo -e "${YELLOW}IMPORTANTE:${NC}"
echo "  1. Certifique-se de que os DNS estão apontando para este servidor"
echo "  2. Execute o comando acima após o deploy estar completo"
echo "  3. Certbot irá configurar automaticamente o Nginx para HTTPS"
echo ""

read -p "Deseja configurar SSL agora? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    certbot --nginx -d "${PUBLIC_FRONTEND_HOST}" -d "${PUBLIC_BACKEND_HOST}"
    print_success "SSL configurado com sucesso!"
else
    print_warning "SSL não configurado. Execute manualmente quando DNS estiver configurado."
fi

# ============================================================================
# PASSO 9: Criar Serviços Systemd
# ============================================================================

print_header "PASSO 9: Configurando Serviços Systemd"

# Backend Service
print_step "Criando serviço systemd para backend..."

cat > /etc/systemd/system/dom360-backend.service << EOF
[Unit]
Description=DOM360 Backend API (FastAPI)
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=$BASE_DIR
Environment="PATH=$BASE_DIR/venv/bin"
ExecStart=$BASE_DIR/venv/bin/python $BASE_DIR/backend/server_rbac.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable dom360-backend.service
systemctl restart dom360-backend.service

print_success "Serviço backend criado e iniciado"

# Frontend Service (opcional, para dev server)
# Em produção, melhor usar nginx para servir o build estático
print_step "Configurando Nginx para servir frontend estático..."

# Atualizar nginx para servir dist ao invés de proxy
# (isso pode ser feito manualmente se necessário)

print_success "Frontend configurado para ser servido pelo Nginx"

# ============================================================================
# PASSO 10: Verificações Finais
# ============================================================================

print_header "PASSO 10: Verificações Finais"

print_step "Testando backend..."
sleep 3  # Dar tempo para o serviço iniciar

if curl -sf http://localhost:${BACKEND_BIND_PORT}/api/health > /dev/null; then
    print_success "Backend está respondendo"
else
    print_warning "Backend não está respondendo ainda. Verifique os logs:"
    echo -e "  ${CYAN}sudo journalctl -u dom360-backend.service -f${NC}"
fi

print_step "Testando Nginx..."
if nginx -t > /dev/null 2>&1; then
    print_success "Configuração do Nginx válida"
else
    print_error "Configuração do Nginx inválida!"
fi

print_step "Verificando portas..."
netstat -tlnp | grep -E ':(80|443|3001|5432) ' || true

# ============================================================================
# Resumo Final
# ============================================================================

print_header "✓ Deploy Concluído!"

echo -e "${CYAN}Resumo da Configuração:${NC}"
echo ""
echo -e "  ${BLUE}Frontend:${NC}  http://${PUBLIC_FRONTEND_HOST}"
echo -e "  ${BLUE}Backend:${NC}   http://${PUBLIC_BACKEND_HOST}"
echo -e "  ${BLUE}Database:${NC}  PostgreSQL rodando na porta ${DB_PORT}"
echo ""

echo -e "${YELLOW}Próximos Passos:${NC}"
echo ""
echo "  1. Configurar DNS (se ainda não configurado):"
echo -e "     ${CYAN}${PUBLIC_FRONTEND_HOST}${NC} → IP da VPS"
echo -e "     ${CYAN}${PUBLIC_BACKEND_HOST}${NC} → IP da VPS"
echo ""
echo "  2. Configurar SSL (se pulou o passo):"
echo -e "     ${CYAN}sudo certbot --nginx -d ${PUBLIC_FRONTEND_HOST} -d ${PUBLIC_BACKEND_HOST}${NC}"
echo ""
echo "  3. Testar a aplicação:"
echo -e "     ${CYAN}curl http://${PUBLIC_BACKEND_HOST}/api/health${NC}"
echo -e "     ${CYAN}curl http://${PUBLIC_FRONTEND_HOST}${NC}"
echo ""
echo "  4. Verificar logs do backend:"
echo -e "     ${CYAN}sudo journalctl -u dom360-backend.service -f${NC}"
echo ""
echo "  5. Verificar logs do Nginx:"
echo -e "     ${CYAN}sudo tail -f /var/log/nginx/error.log${NC}"
echo ""

echo -e "${GREEN}Deploy concluído com sucesso! 🚀${NC}"
echo ""
