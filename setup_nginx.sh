#!/bin/bash

# ============================================================================
# DOM360 - Configuração do Nginx Reverse Proxy
# ============================================================================
# Este script configura o Nginx como reverse proxy para frontend e backend
# Corrige o problema de placeholders não expandidos do nginx.conf
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

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}    DOM360 - Nginx Reverse Proxy Setup${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Verificar se está rodando como root ou sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Este script precisa ser executado como root${NC}"
    echo -e "  Use: ${CYAN}sudo $0${NC}"
    exit 1
fi

# Verificar se Nginx está instalado
if ! command -v nginx &> /dev/null; then
    echo -e "${YELLOW}⚠ Nginx não encontrado. Instalando...${NC}"
    apt update
    apt install -y nginx
    echo -e "${GREEN}✓ Nginx instalado${NC}"
fi

# Verificar se envsubst está instalado
if ! command -v envsubst &> /dev/null; then
    echo -e "${YELLOW}⚠ envsubst não encontrado. Instalando gettext-base...${NC}"
    apt update
    apt install -y gettext-base
    echo -e "${GREEN}✓ gettext-base instalado${NC}"
fi

# Load .env variables
echo -e "${BLUE}⚙ Carregando variáveis do .env...${NC}"
if [ -f "$BASE_DIR/.env" ]; then
  set -o allexport
  # shellcheck disable=SC1091
  source "$BASE_DIR/.env"
  set +o allexport
  echo -e "${GREEN}✓ Variáveis carregadas${NC}"
else
  echo -e "${RED}✗ Arquivo .env não encontrado!${NC}"
  exit 1
fi

# Set defaults
INTERNAL_FRONTEND_HOST=${INTERNAL_FRONTEND_HOST:-localhost}
INTERNAL_FRONTEND_PORT=${INTERNAL_FRONTEND_PORT:-5173}
INTERNAL_BACKEND_HOST=${INTERNAL_BACKEND_HOST:-localhost}
INTERNAL_BACKEND_PORT=${INTERNAL_BACKEND_PORT:-3001}
PUBLIC_FRONTEND_HOST=${PUBLIC_FRONTEND_HOST:-srcjohann.com.br}
PUBLIC_BACKEND_HOST=${PUBLIC_BACKEND_HOST:-api.srcjohann.com.br}

echo ""
echo -e "${BLUE}📋 Configuração:${NC}"
echo "  Frontend interno:  ${INTERNAL_FRONTEND_HOST}:${INTERNAL_FRONTEND_PORT}"
echo "  Frontend público:  ${PUBLIC_FRONTEND_HOST}"
echo "  Backend interno:   ${INTERNAL_BACKEND_HOST}:${INTERNAL_BACKEND_PORT}"
echo "  Backend público:   ${PUBLIC_BACKEND_HOST}"
echo ""

# Backup existing configuration
NGINX_SRC="$BASE_DIR/nginx.conf"
NGINX_DEST="/etc/nginx/sites-available/dom360"

if [ -f "$NGINX_DEST" ]; then
    BACKUP_FILE="${NGINX_DEST}.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${BLUE}⚙ Fazendo backup da configuração existente...${NC}"
    cp "$NGINX_DEST" "$BACKUP_FILE"
    echo -e "${GREEN}✓ Backup salvo em: $BACKUP_FILE${NC}"
fi

# Generate nginx config using envsubst
echo -e "${BLUE}⚙ Gerando configuração do Nginx com envsubst...${NC}"

# Export variables for envsubst
export INTERNAL_FRONTEND_HOST INTERNAL_FRONTEND_PORT
export INTERNAL_BACKEND_HOST INTERNAL_BACKEND_PORT
export PUBLIC_FRONTEND_HOST PUBLIC_BACKEND_HOST

# Process template with envsubst
envsubst '${INTERNAL_FRONTEND_HOST} ${INTERNAL_FRONTEND_PORT} ${INTERNAL_BACKEND_HOST} ${INTERNAL_BACKEND_PORT} ${PUBLIC_FRONTEND_HOST} ${PUBLIC_BACKEND_HOST}' \
    < "$NGINX_SRC" > "$NGINX_DEST"

echo -e "${GREEN}✓ Configuração gerada em: $NGINX_DEST${NC}"

# Habilitar site
if [ ! -L /etc/nginx/sites-enabled/dom360 ]; then
    ln -s "$NGINX_DEST" /etc/nginx/sites-enabled/
    echo -e "${GREEN}✓${NC} Site habilitado"
fi

# Desabilitar default se existir
if [ -L /etc/nginx/sites-enabled/default ]; then
    rm /etc/nginx/sites-enabled/default
    echo -e "${GREEN}✓${NC} Site padrão desabilitado"
fi

# Testar configuração
echo -e "${BLUE}Testando configuração...${NC}"
if nginx -t; then
    echo -e "${GREEN}✓${NC} Configuração válida"
else
    echo -e "${RED}✗${NC} Erro na configuração!"
    exit 1
fi

# Reiniciar Nginx
echo -e "${BLUE}Reiniciando Nginx...${NC}"
systemctl restart nginx
systemctl enable nginx

echo -e "${GREEN}✓${NC} Nginx configurado com sucesso!"

# Configurar /etc/hosts usando PUBLIC_FRONTEND_HOST and PUBLIC_BACKEND_HOST (sem esquema)
FRH=${PUBLIC_FRONTEND_HOST#http://}
FRH=${FRH#https://}
BRH=${PUBLIC_BACKEND_HOST#http://}
BRH=${BRH#https://}

echo -e "${BLUE}Configurando /etc/hosts...${NC}"
if ! grep -q "$FRH" /etc/hosts; then
    echo "127.0.0.1 $FRH $BRH" >> /etc/hosts
    echo -e "${GREEN}✓${NC} Domínios adicionados ao /etc/hosts"
else
    echo -e "${GREEN}✓${NC} Domínios já configurados no /etc/hosts"
fi

echo ""
echo -e "${GREEN}Configuração completa!${NC}"
echo -e "${CYAN}URLs:${NC}"
echo -e "  Frontend: ${PUBLIC_FRONTEND_URL:-http://$FRH}"
echo -e "  Backend:  ${PUBLIC_BACKEND_URL:-http://$BRH}"
echo ""
echo -e "${YELLOW}Certifique-se de que o start.sh está rodando os serviços.${NC}"