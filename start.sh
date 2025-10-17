#!/bin/bash

# ============================================================================
# DOM360 - Inicialização Unificada
# Inicia Backend (FastAPI) e Frontend (React) simultaneamente
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

# Carregar variáveis de ambiente
if [ -f "$BASE_DIR/.env" ]; then
    export $(cat "$BASE_DIR/.env" | grep -v '^#' | grep -v '^$' | xargs)
fi

# ============================================================================
# Banner
# ============================================================================
clear
echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║                  DOM360 - Startup                        ║
║             Backend FastAPI + Frontend React             ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# ============================================================================
# Verificações
# ============================================================================

echo -e "${BLUE}[1/5]${NC} Verificando dependências..."

# Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}✗${NC} Python3 não encontrado!"
    exit 1
fi
echo -e "${GREEN}✓${NC} Python3: $(python3 --version)"

# Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}✗${NC} Node.js não encontrado!"
    exit 1
fi
echo -e "${GREEN}✓${NC} Node.js: $(node --version)"

# PostgreSQL
if ! psql -U ${DB_USER:-postgres} -h ${DB_HOST:-localhost} -c "SELECT version();" > /dev/null 2>&1; then
    echo -e "${YELLOW}!${NC} PostgreSQL não acessível. Tentando sem senha..."
    if ! psql -c "SELECT version();" > /dev/null 2>&1; then
        echo -e "${RED}✗${NC} PostgreSQL não está acessível!"
        echo "  Configure o arquivo .env com DB_PASSWORD ou use ./configure_postgres.sh"
        exit 1
    fi
fi
echo -e "${GREEN}✓${NC} PostgreSQL conectado"

# Nginx
if ! command -v nginx &> /dev/null; then
    echo -e "${YELLOW}!${NC} Nginx não encontrado. Para reverse proxy:"
    echo "  sudo apt update && sudo apt install nginx"
    echo "  sudo cp nginx.conf /etc/nginx/sites-available/dom360"
    echo "  sudo ln -s /etc/nginx/sites-available/dom360 /etc/nginx/sites-enabled/"
    echo "  sudo nginx -t && sudo systemctl restart nginx"
    echo "  Adicione ao /etc/hosts: 127.0.0.1 ${PUBLIC_FRONTEND_URL#http://} ${PUBLIC_BACKEND_URL#http://}"
else
    echo -e "${GREEN}✓${NC} Nginx instalado"
fi

# ============================================================================
# Verificar Banco de Dados
# ============================================================================

echo ""
echo -e "${BLUE}[2/5]${NC} Verificando banco de dados..."

if psql -U ${DB_USER:-postgres} -h ${DB_HOST:-localhost} -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw ${DB_NAME:-dom360_db}; then
    echo -e "${GREEN}✓${NC} Banco ${DB_NAME:-dom360_db} existe"
else
    echo -e "${YELLOW}!${NC} Banco não encontrado. Criando banco e aplicando schema..."
    
    # Criar banco de dados
    if createdb -U ${DB_USER:-postgres} -h ${DB_HOST:-localhost} ${DB_NAME:-dom360_db} 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Banco ${DB_NAME:-dom360_db} criado"
    else
        echo -e "${RED}✗${NC} Falha ao criar banco. Tentando com psql..."
    PGPASSWORD=${DB_PASSWORD:-admin} psql -U ${DB_USER:-postgres} -h ${DB_HOST:-localhost} -c "CREATE DATABASE ${DB_NAME:-dom360_db};" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓${NC} Banco ${DB_NAME:-dom360_db} criado via psql"
        else
            echo -e "${RED}✗${NC} Falha ao criar banco!"
            exit 1
        fi
    fi
    
    # Aplicar schema
    if PGPASSWORD=${DB_PASSWORD:-admin} psql -U ${DB_USER:-postgres} -h ${DB_HOST:-localhost} -d ${DB_NAME:-dom360_db} -f "$BASE_DIR/database/schema.sql" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Schema aplicado ao banco ${DB_NAME:-dom360_db}"
    else
        echo -e "${RED}✗${NC} Falha ao aplicar schema!"
        exit 1
    fi
fi

# ============================================================================
# Configurar Backend
# ============================================================================

echo ""
echo -e "${BLUE}[3/5]${NC} Configurando Backend (Python)..."

cd "$BASE_DIR"

# Verificar se venv principal existe
if [ ! -d "venv" ]; then
    echo "  Criando ambiente virtual principal..."
    python3 -m venv venv
fi

# Ativar venv principal
source venv/bin/activate

# Instalar dependências do backend
if [ ! -f "venv/backend_installed" ]; then
    echo "  Instalando dependências do backend..."
    pip install -q --upgrade pip
    pip install -q -r backend/requirements.txt
    touch venv/backend_installed
fi

echo -e "${GREEN}✓${NC} Backend configurado (usando venv principal)"

# ============================================================================
# Configurar Frontend
# ============================================================================

echo ""
echo -e "${BLUE}[4/5]${NC} Configurando Frontend (React)..."

cd "$BASE_DIR/frontend/app"

# Instalar dependências se necessário
if [ ! -d "node_modules" ]; then
    echo "  Instalando dependências..."
    npm install --silent
fi

echo -e "${GREEN}✓${NC} Frontend configurado"

# ============================================================================
# Iniciar Serviços
# ============================================================================

echo ""
echo -e "${BLUE}[5/5]${NC} Iniciando serviços..."
echo ""

# Criar diretório para logs
mkdir -p "$BASE_DIR/logs"

# Função para cleanup
cleanup() {
    echo ""
    echo -e "${YELLOW}Encerrando serviços...${NC}"
    
    if [ ! -z "$BACKEND_PID" ]; then
        kill $BACKEND_PID 2>/dev/null || true
    fi
    
    if [ ! -z "$FRONTEND_PID" ]; then
        kill $FRONTEND_PID 2>/dev/null || true
    fi
    
    # Matar processos remanescentes
    pkill -f "uvicorn server:app" 2>/dev/null || true
    pkill -f "vite" 2>/dev/null || true
    
    echo -e "${GREEN}✓${NC} Serviços encerrados"
    exit 0
}

trap cleanup EXIT INT TERM

# Iniciar Backend
echo -e "${CYAN}➜ Iniciando Backend (FastAPI com RBAC)...${NC}"
cd "$BASE_DIR"
source venv/bin/activate

# Verificar se server_rbac.py existe, senão usar server.py
if [ -f "backend/server_rbac.py" ]; then
    echo "  Usando server_rbac.py (com autenticação)"
    python backend/server_rbac.py > "$BASE_DIR/logs/backend.log" 2>&1 &
else
    echo "  Usando server.py (sem autenticação - legacy)"
    python backend/server.py > "$BASE_DIR/logs/backend.log" 2>&1 &
fi
BACKEND_PID=$!

# Aguardar backend iniciar
sleep 2

if ! ps -p $BACKEND_PID > /dev/null; then
    echo -e "${RED}✗${NC} Backend falhou ao iniciar!"
    cat "$BASE_DIR/logs/backend.log"
    exit 1
fi

# Verificar se backend está respondendo
for i in {1..10}; do
    if curl -s http://${INTERNAL_BACKEND_HOST:-localhost}:${INTERNAL_BACKEND_PORT:-3001}/api/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Backend rodando em http://${INTERNAL_BACKEND_HOST:-localhost}:${INTERNAL_BACKEND_PORT:-3001} | ${PUBLIC_BACKEND_URL}"
        break
    fi
    if [ $i -eq 10 ]; then
        echo -e "${RED}✗${NC} Backend não respondeu!"
        cat "$BASE_DIR/logs/backend.log"
        exit 1
    fi
    sleep 1
done

# Iniciar Frontend
echo -e "${CYAN}➜ Iniciando Frontend (Vite)...${NC}"
cd "$BASE_DIR/frontend/app"

npm run dev > "$BASE_DIR/logs/frontend.log" 2>&1 &
FRONTEND_PID=$!

# Aguardar frontend iniciar
sleep 3

if ! ps -p $FRONTEND_PID > /dev/null; then
    echo -e "${RED}✗${NC} Frontend falhou ao iniciar!"
    cat "$BASE_DIR/logs/frontend.log"
    exit 1
fi

echo -e "${GREEN}✓${NC} Frontend rodando em http://${INTERNAL_FRONTEND_HOST:-localhost}:${INTERNAL_FRONTEND_PORT:-5173} | ${PUBLIC_FRONTEND_URL}"

# ============================================================================
# Pronto!
# ============================================================================

echo ""
echo -e "${GREEN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║              ✓ Sistema Online!                          ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${CYAN}Serviços:${NC}"
echo -e "  Backend:  ${GREEN}http://localhost:${BACKEND_PORT:-3001}${NC} | ${GREEN}http://api.srcjohann.com.br${NC}"
echo -e "  Frontend: ${GREEN}http://localhost:5173${NC} | ${GREEN}http://srcjohann.com.br${NC}"
echo -e "  Health:   ${GREEN}http://localhost:${BACKEND_PORT:-3001}/api/health${NC} | ${GREEN}http://api.srcjohann.com.br/api/health${NC}"
echo ""

echo -e "${CYAN}Logs:${NC}"
echo -e "  Backend:  tail -f $BASE_DIR/logs/backend.log"
echo -e "  Frontend: tail -f $BASE_DIR/logs/frontend.log"
echo ""

echo -e "${CYAN}Documentação:${NC}"
echo -e "  API:     http://localhost:${BACKEND_PORT:-3001}/docs | http://api.srcjohann.com.br/docs"
echo -e "  Resumo:  $BASE_DIR/RESUMO_IMPLEMENTACAO.md"
echo ""

echo -e "${YELLOW}Pressione Ctrl+C para parar todos os serviços${NC}"
echo ""

# Mostrar logs em tempo real
tail -f "$BASE_DIR/logs/backend.log" "$BASE_DIR/logs/frontend.log" &
TAIL_PID=$!

# Aguardar
wait $BACKEND_PID $FRONTEND_PID
