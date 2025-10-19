# ==============================================================================
# Multi-stage Dockerfile para Frontend (React + Vite) - Produção
# ==============================================================================
# Otimizado para:
# - Build eficiente com cache
# - Imagem final mínima com Node.js (não Nginx)
# - Non-root user para segurança
# - Healthchecks funcionais
# ==============================================================================

# ============================================================================
# Stage 1: Build
# ============================================================================
FROM node:18-alpine AS builder

LABEL maintainer="srcjohann"
LABEL description="DOM360 SDK Frontend Build Stage"

WORKDIR /app

# Copiar package files
COPY package*.json ./

# Instalar dependências (incluindo dev para build)
RUN npm ci --prefer-offline --no-audit && npm cache clean --force

# Copiar código fonte
COPY . .

# Build da aplicação
RUN npm run build

# ============================================================================
# Stage 2: Production Runtime com Node.js
# ============================================================================
FROM node:18-alpine

LABEL maintainer="srcjohann"
LABEL description="DOM360 SDK Frontend - React + Vite"

# ============================================================================
# Instalar utilitários
# ============================================================================
RUN apk add --no-cache curl ca-certificates

# ============================================================================
# Criar usuário não-root (se não existir)
# ============================================================================
RUN addgroup -S appuser || true && \
    adduser -S -u 1001 appuser || true

# ============================================================================
# Instalar serve para servir static files
# ============================================================================
RUN npm install -g serve

# ============================================================================
# Copiar build do estágio anterior
# ============================================================================
WORKDIR /app
COPY --from=builder --chown=appuser:appuser /app/dist ./dist

# ============================================================================
# Mudar para usuário não-root
# ============================================================================
USER appuser

# ============================================================================
# Expor porta
# ============================================================================
EXPOSE 5173

# ============================================================================
# Health check
# ============================================================================
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5173/ || exit 1

# ============================================================================
# Servir aplicação com serve
# ============================================================================
CMD ["serve", "-s", "dist", "-l", "5173"]