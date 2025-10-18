# ==============================================================================
# Build stage for Frontend
# ==============================================================================
FROM node:18-alpine AS frontend-builder

WORKDIR /app/frontend

# Copiar package files
COPY frontend/app/package*.json ./

# Instalar dependências
RUN npm ci

# Copiar código do frontend
COPY frontend/app/ ./

# Build
RUN npm run build

# ==============================================================================
# Runtime stage - Backend + Frontend
# ==============================================================================
FROM python:3.11-slim

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Criar diretório de trabalho
WORKDIR /app

# Criar estrutura de diretórios
RUN mkdir -p /app/logs /app/backend /app/database

# Copiar requirements do backend
COPY backend/requirements.txt ./backend/
RUN pip install --no-cache-dir -r ./backend/requirements.txt

# Copiar código do backend (inclui auth e api)
COPY backend/ ./backend/

# Copiar database schemas e seeds
COPY database/ ./database/

# Copiar frontend buildado
COPY --from=frontend-builder /app/frontend/dist ./frontend/dist

# Script de inicialização
COPY docker-entrypoint.sh ./
RUN chmod +x ./docker-entrypoint.sh

# Definir variáveis padrão
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    BACKEND_HOST=0.0.0.0 \
    BACKEND_PORT=3001

# Expor portas
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:3001/api/health || exit 1

# Executar script de inicialização
ENTRYPOINT ["./docker-entrypoint.sh"]
