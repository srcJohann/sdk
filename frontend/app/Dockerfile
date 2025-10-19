# ==============================================================================
# Multi-stage Dockerfile para Frontend (React + Vite) - Produção
# ==============================================================================

# ==============================================================================
# Stage 1: Build
# ==============================================================================
FROM node:18-alpine AS builder

LABEL maintainer="srcjohann"
LABEL description="DOM360 SDK Frontend Build Stage"

WORKDIR /app

# Copiar package files e lock para instalar dependências
COPY package*.json ./
COPY package-lock.json ./

# Instalar todas as dependências (incluindo dev) necessárias para o build
RUN npm ci && npm cache clean --force

# Copiar código fonte
COPY . .

# Build da aplicação
RUN npm run build

# Opcional: remover dependências de desenvolvimento para reduzir imagem (não necessário
# para o stage atual já que será copiado apenas o build), mantido como comentário
# RUN npm prune --production

# ==============================================================================
# Stage 2: Production com Nginx
# ==============================================================================
FROM nginx:alpine

LABEL maintainer="srcjohann"
LABEL description="DOM360 SDK Frontend - Nginx"

# Copiar build do estágio anterior
COPY --from=builder /app/dist /usr/share/nginx/html

# Copiar configuração customizada do Nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Criar usuário não-root
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser && \
    chown -R appuser:appuser /usr/share/nginx/html && \
    chown -R appuser:appuser /var/cache/nginx && \
    chown -R appuser:appuser /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R appuser:appuser /var/run/nginx.pid

# Mudar para usuário não-root
USER appuser

# Expor porta
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1

# Iniciar Nginx
CMD ["nginx", "-g", "daemon off;"]
