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
echo -e "${BLUE}Copiando configuração...${NC}"
cp "$BASE_DIR/nginx.conf" /etc/nginx/sites-available/dom360

# Habilitar site
if [ ! -L /etc/nginx/sites-enabled/dom360 ]; then
    ln -s /etc/nginx/sites-available/dom360 /etc/nginx/sites-enabled/
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

# Configurar /etc/hosts
echo -e "${BLUE}Configurando /etc/hosts...${NC}"
if ! grep -q "srcjohann.com.br" /etc/hosts; then
    echo "127.0.0.1 srcjohann.com.br api.srcjohann.com.br" >> /etc/hosts
    echo -e "${GREEN}✓${NC} Domínios adicionados ao /etc/hosts"
else
    echo -e "${GREEN}✓${NC} Domínios já configurados no /etc/hosts"
fi

echo ""
echo -e "${GREEN}Configuração completa!${NC}"
echo -e "${CYAN}URLs:${NC}"
echo -e "  Frontend: http://srcjohann.com.br"
echo -e "  Backend:  http://api.srcjohann.com.br"
echo ""
echo -e "${YELLOW}Certifique-se de que o start.sh está rodando os serviços.${NC}"