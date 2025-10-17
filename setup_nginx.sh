#!/bin/bash

# ============================================================================
# DOM360 - Configuração do Nginx Reverse Proxy
# ============================================================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Diretório base
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}Configurando Nginx Reverse Proxy...${NC}"

# Verificar se está rodando como root ou sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗${NC} Execute como root: sudo $0"
    exit 1
fi

# Verificar se Nginx está instalado
if ! command -v nginx &> /dev/null; then
    echo -e "${YELLOW}Instalando Nginx...${NC}"
    apt update
    apt install -y nginx
    echo -e "${GREEN}✓${NC} Nginx instalado"
fi

# Copiar configuração
echo -e "${BLUE}Gerando e copiando configuração do Nginx...${NC}"

# Load .env variables (simple parser)
set -o allexport
if [ -f "$BASE_DIR/.env" ]; then
  # shellcheck disable=SC1091
  source "$BASE_DIR/.env"
fi
set +o allexport

NGINX_SRC="$BASE_DIR/nginx.conf"
NGINX_DEST="/etc/nginx/sites-available/dom360"

# Use envsubst if available, otherwise fallback to sed replacements
if command -v envsubst &> /dev/null; then
  envsubst < "$NGINX_SRC" > "$NGINX_DEST"
else
  cp "$NGINX_SRC" "$NGINX_DEST"
  sed -i "s|\${INTERNAL_FRONTEND_HOST:-localhost}|${INTERNAL_FRONTEND_HOST:-localhost}|g" "$NGINX_DEST" || true
  sed -i "s|\${INTERNAL_FRONTEND_PORT:-5173}|${INTERNAL_FRONTEND_PORT:-5173}|g" "$NGINX_DEST" || true
  sed -i "s|\${INTERNAL_BACKEND_HOST:-localhost}|${INTERNAL_BACKEND_HOST:-localhost}|g" "$NGINX_DEST" || true
  sed -i "s|\${INTERNAL_BACKEND_PORT:-3001}|${INTERNAL_BACKEND_PORT:-3001}|g" "$NGINX_DEST" || true
  sed -i "s|\${PUBLIC_FRONTEND_HOST:-srcjohann.com.br}|${PUBLIC_FRONTEND_HOST:-srcjohann.com.br}|g" "$NGINX_DEST" || true
  sed -i "s|\${PUBLIC_BACKEND_HOST:-api.srcjohann.com.br}|${PUBLIC_BACKEND_HOST:-api.srcjohann.com.br}|g" "$NGINX_DEST" || true
fi

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