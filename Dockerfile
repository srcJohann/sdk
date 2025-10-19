# ==============================================================================
# Dockerfile para Backend (FastAPI) - Produção
# ==============================================================================
# Otimizado para:
# - PostgreSQL na VPS (não containerizado)
# - FastAPI servindo apenas a API
# - Non-root user para segurança
# - Healthchecks robustos
# ==============================================================================

FROM python:3.11-slim

LABEL maintainer="srcjohann"
LABEL description="DOM360 SDK Backend API - FastAPI"

# ============================================================================
# Instalar dependências do sistema
# ============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    curl \
    ca-certificates \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# Criar usuário não-root para segurança
# ============================================================================
RUN useradd -m -u 1000 appuser

# ============================================================================
# Criar estrutura de diretórios
# ============================================================================
WORKDIR /app
RUN mkdir -p /app/logs /app/database && \
    chown -R appuser:appuser /app

# ============================================================================
# Instalar dependências Python
# ============================================================================
COPY --chown=appuser:appuser backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt

# ============================================================================
# Copiar código do backend
# ============================================================================
COPY --chown=appuser:appuser backend/ ./

# ============================================================================
# Copiar database (schema, migrations, seeds)
# ============================================================================
COPY --chown=appuser:appuser database/ ./database/

# ============================================================================
# Entrypoint script
# ============================================================================
COPY --chown=appuser:appuser backend/entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

# ============================================================================
# Mudar para usuário não-root
# ============================================================================
USER appuser

# ============================================================================
# Variáveis de ambiente padrão
# ============================================================================
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    BACKEND_BIND_HOST=0.0.0.0 \
    BACKEND_BIND_PORT=3001

# ============================================================================
# Expor porta do backend
# ============================================================================
EXPOSE 3001

# ============================================================================
# Health check
# ============================================================================
HEALTHCHECK --interval=30s --timeout=10s --start-period=45s --retries=3 \
    CMD curl -f http://localhost:3001/api/health || exit 1

# ============================================================================
# Executar script de inicialização
# ============================================================================
ENTRYPOINT ["./entrypoint.sh"]
CMD ["python", "-m", "uvicorn", "server:app", "--host", "0.0.0.0", "--port", "3001"]
