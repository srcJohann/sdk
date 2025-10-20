#!/bin/bash

# ============================================================================
# QUICK START - SDK Docker Swarm Deployment
# Execute este script pela primeira vez para setup completo
# ============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear

cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║              🐳 SDK - Docker Swarm Quick Start Setup 🐳                  ║
║                                                                          ║
║  Este script preparará sua aplicação para deployment em Docker Swarm    ║
║  com integração automática de Traefik e HTTPS.                         ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
EOF

echo ""

# Step 1: Verificar Docker
echo -e "${BLUE}▶ PASSO 1${NC}: Verificando Docker..."
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓ Docker encontrado${NC}"
else
    echo -e "${RED}✗ Docker não está instalado${NC}"
    echo -e "${BLUE}ℹ${NC} Instale Docker em: https://docs.docker.com/get-docker/"
    exit 1
fi

# Step 2: Inicializar Swarm
echo ""
echo -e "${BLUE}▶ PASSO 2${NC}: Configurando Docker Swarm..."
if docker info | grep -q "Swarm: active"; then
    echo -e "${GREEN}✓ Docker Swarm já está ativo${NC}"
else
    echo -e "${YELLOW}⚠ Docker Swarm não está ativo${NC}"
    read -p "Deseja inicializar? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        docker swarm init
        echo -e "${GREEN}✓ Swarm inicializado${NC}"
    else
        echo -e "${RED}✗ Swarm necessário para continuar${NC}"
        exit 1
    fi
fi

# Step 3: Criar rede overlay
echo ""
echo -e "${BLUE}▶ PASSO 3${NC}: Configurando rede overlay..."
if docker network ls | grep -q "network_public"; then
    echo -e "${GREEN}✓ Rede 'network_public' já existe${NC}"
else
    echo -e "${YELLOW}⚠ Rede 'network_public' não encontrada${NC}"
    read -p "Deseja criar? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        docker network create -d overlay network_public
        echo -e "${GREEN}✓ Rede criada${NC}"
    else
        echo -e "${RED}✗ Rede necessária para continuar${NC}"
        exit 1
    fi
fi

# Step 4: Verificar arquivo .env
echo ""
echo -e "${BLUE}▶ PASSO 4${NC}: Verificando configuração..."
if [ -f .env ]; then
    echo -e "${GREEN}✓ Arquivo '.env' encontrado${NC}"
else
    echo -e "${YELLOW}⚠ Arquivo '.env' não encontrado${NC}"
    if [ -f .env.example ]; then
        read -p "Deseja usar .env.example como template? (s/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            cp .env.example .env
            echo -e "${GREEN}✓ .env criado de .env.example${NC}"
            echo -e "${YELLOW}⚠ IMPORTANTE: Edite .env com valores reais${NC}"
            read -p "Abrir .env no editor? (s/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Ss]$ ]]; then
                ${EDITOR:-nano} .env
            fi
        fi
    fi
fi

# Step 5: Executar verificações
echo ""
echo -e "${BLUE}▶ PASSO 5${NC}: Executando verificações..."
if [ -f check-deploy.sh ]; then
    ./check-deploy.sh
else
    echo -e "${RED}✗ Script check-deploy.sh não encontrado${NC}"
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}  ✓ Setup concluído! Próximos passos:${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "1. Build das imagens:"
echo "   ${BLUE}./build-local.sh${NC}"
echo ""
echo "2. Deploy do stack:"
echo "   ${BLUE}./deploy.sh deploy${NC}"
echo ""
echo "3. Verificar status:"
echo "   ${BLUE}./deploy.sh status${NC}"
echo ""
echo "Documentação:"
echo "   ${BLUE}cat SWARM_README.md${NC}"
echo ""
