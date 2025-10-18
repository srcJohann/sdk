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

# Definir valores padrão para evitar comportamento dependente do ambiente
DB_USER=${DB_USER:-postgres}
DB_HOST=${DB_HOST:-127.0.0.1}
DB_NAME=${DB_NAME:-dom360_db_sdk}
DB_PASSWORD=${DB_PASSWORD:-admin}

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
if ! PGPASSWORD=${DB_PASSWORD} psql -U ${DB_USER} -h ${DB_HOST} -c "SELECT version();" > /dev/null 2>&1; then
    echo -e "${YELLOW}!${NC} PostgreSQL não acessível com as credenciais fornecidas. Tentando sem senha local..."
    if ! psql -c "SELECT version();" > /dev/null 2>&1; then
        echo -e "${RED}✗${NC} PostgreSQL não está acessível!"
        echo "  Configure o arquivo .env com DB_USER/DB_PASSWORD/DB_HOST corretos ou use ./configure_postgres.sh"
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

if PGPASSWORD=${DB_PASSWORD} psql -U ${DB_USER} -h ${DB_HOST} -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw ${DB_NAME}; then
    echo -e "${GREEN}✓${NC} Banco ${DB_NAME} existe"
else
    echo -e "${YELLOW}!${NC} Banco não encontrado. Criando banco e aplicando schema..."

    # Try to create DB using: sudo -n -u postgres, sudo -u postgres, createdb, psql
    CREATEDB_DONE=0
    if command -v sudo > /dev/null 2>&1; then
        if sudo -n -u postgres createdb ${DB_NAME} 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Banco ${DB_NAME} criado (via sudo -n -u postgres)"
            CREATEDB_DONE=1
        elif sudo -u postgres createdb ${DB_NAME} 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Banco ${DB_NAME} criado (via sudo -u postgres)"
            CREATEDB_DONE=1
        fi
    fi

    if [ $CREATEDB_DONE -eq 0 ]; then
        if PGPASSWORD=${DB_PASSWORD} createdb -U ${DB_USER} -h ${DB_HOST} ${DB_NAME} 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Banco ${DB_NAME} criado (via createdb)"
            CREATEDB_DONE=1
        elif PGPASSWORD=${DB_PASSWORD} psql -U ${DB_USER} -h ${DB_HOST} -c "CREATE DATABASE ${DB_NAME};" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Banco ${DB_NAME} criado via psql"
            CREATEDB_DONE=1
        fi
    fi

    if [ $CREATEDB_DONE -ne 1 ]; then
        echo -e "${RED}✗${NC} Falha ao criar banco! Tente criar manualmente com sudo -u postgres createdb ${DB_NAME} ou verifique credenciais"
        exit 1
    fi

    # Apply schema: try sudo non-interactive, sudo interactive, then PGPASSWORD psql
    SCHEMA_DONE=0
    if command -v sudo > /dev/null 2>&1; then
        if sudo -n -u postgres psql -d ${DB_NAME} -f "$BASE_DIR/database/schema.sql" > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Schema aplicado ao banco ${DB_NAME} (via sudo -n -u postgres)"
            SCHEMA_DONE=1
        elif sudo -u postgres psql -d ${DB_NAME} -f "$BASE_DIR/database/schema.sql" > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Schema aplicado ao banco ${DB_NAME} (via sudo -u postgres)"
            SCHEMA_DONE=1
        fi
    fi

    if [ $SCHEMA_DONE -eq 0 ]; then
        if PGPASSWORD=${DB_PASSWORD} psql -U ${DB_USER} -h ${DB_HOST} -d ${DB_NAME} -f "$BASE_DIR/database/schema.sql" > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Schema aplicado ao banco ${DB_NAME}"
            SCHEMA_DONE=1
        fi
    fi

    if [ $SCHEMA_DONE -ne 1 ]; then
        echo -e "${RED}✗${NC} Falha ao aplicar schema!"
        exit 1
    fi

    # Run migrations wrapper (if present)
    if [ -f "$BASE_DIR/database/migrations/001_schema_apply.sql" ]; then
        if command -v sudo > /dev/null 2>&1; then
            sudo -n -u postgres psql -d ${DB_NAME} -f "$BASE_DIR/database/migrations/001_schema_apply.sql" > /dev/null 2>&1 || true
        else
            PGPASSWORD=${DB_PASSWORD} psql -U ${DB_USER} -h ${DB_HOST} -d ${DB_NAME} -f "$BASE_DIR/database/migrations/001_schema_apply.sql" > /dev/null 2>&1 || true
        fi
    fi

    # Run seeds
    if [ -f "$BASE_DIR/database/seeds/001_seed_master.sql" ]; then
        echo "  Aplicando seed do master user..."
        if command -v sudo > /dev/null 2>&1; then
            sudo -n -u postgres psql -d ${DB_NAME} -f "$BASE_DIR/database/seeds/001_seed_master.sql" || echo "Falha ao aplicar seed (verifique logs)"
        else
            PGPASSWORD=${DB_PASSWORD} psql -U ${DB_USER} -h ${DB_HOST} -d ${DB_NAME} -f "$BASE_DIR/database/seeds/001_seed_master.sql" || echo "Falha ao aplicar seed (verifique logs)"
        fi
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

    # Fechar tail se estiver rodando
    if [ ! -z "$TAIL_PID" ]; then
        kill $TAIL_PID 2>/dev/null || true
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

# Consistent backend host/port vars
BACKEND_HOST=${INTERNAL_BACKEND_HOST:-127.0.0.1}
BACKEND_PORT=${INTERNAL_BACKEND_PORT:-3001}

# Se o backend já responde no endpoint /api/health, não tenta iniciar novamente
if curl -s http://${BACKEND_HOST}:${BACKEND_PORT}/api/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Backend já está rodando em http://${BACKEND_HOST}:${BACKEND_PORT}"
    # tenta recuperar PID de um processo conhecido (server_rbac.py / uvicorn)
    BACKEND_PID=$(pgrep -f "server_rbac.py|uvicorn" | head -n1 || true)
else
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
        if curl -s http://${BACKEND_HOST}:${BACKEND_PORT}/api/health > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Backend rodando em http://${BACKEND_HOST}:${BACKEND_PORT} | ${PUBLIC_BACKEND_URL}"
            break
        fi
        if [ $i -eq 10 ]; then
            echo -e "${RED}✗${NC} Backend não respondeu!"
            cat "$BASE_DIR/logs/backend.log"
            exit 1
        fi
        sleep 1
    done
fi

# Iniciar Frontend
echo -e "${CYAN}➜ Iniciando Frontend (Vite)...${NC}"
cd "$BASE_DIR/frontend/app"

# Consistent frontend host/port vars
FRONTEND_HOST=${INTERNAL_FRONTEND_HOST:-127.0.0.1}
FRONTEND_PORT=${INTERNAL_FRONTEND_PORT:-5173}

# Se o frontend já responde, não tenta iniciar novamente
if curl -s http://${FRONTEND_HOST}:${FRONTEND_PORT} > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Frontend já está rodando em http://${FRONTEND_HOST}:${FRONTEND_PORT}"
    FRONTEND_PID=$(pgrep -f "vite" | head -n1 || true)
else
    npm run dev > "$BASE_DIR/logs/frontend.log" 2>&1 &
    FRONTEND_PID=$!

    # Aguardar frontend iniciar
    sleep 3

    if ! ps -p $FRONTEND_PID > /dev/null; then
        echo -e "${RED}✗${NC} Frontend falhou ao iniciar!"
        cat "$BASE_DIR/logs/frontend.log"
        exit 1
    fi

    echo -e "${GREEN}✓${NC} Frontend rodando em http://${FRONTEND_HOST}:${FRONTEND_PORT} | ${PUBLIC_FRONTEND_URL}"
fi

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

# Mostrar logs em tempo real (rodado como filho do script)
tail -f "$BASE_DIR/logs/backend.log" "$BASE_DIR/logs/frontend.log" &
TAIL_PID=$!

# Aguardar o tail (é filho direto) — assim o script mantém-se vivo enquanto logs forem exibidos
wait $TAIL_PID
