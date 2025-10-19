# ==============================================================================
# Dockerfile para Backend (FastAPI) - Produção
# ==============================================================================
FROM python:3.11-slim

LABEL maintainer="srcjohann"
LABEL description="DOM360 SDK Backend API - FastAPI + PostgreSQL"

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Criar usuário não-root para segurança
RUN useradd -m -u 1000 appuser

# Criar estrutura de diretórios
WORKDIR /app
RUN mkdir -p /app/logs /app/database && \
    chown -R appuser:appuser /app

# Copiar requirements e instalar dependências Python
COPY --chown=appuser:appuser backend/requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copiar código do backend
COPY --chown=appuser:appuser backend/ ./

# Copiar database (schema, migrations, seeds)
COPY --chown=appuser:appuser database/ ./database/

# Tornar script de inicialização executável
RUN chmod +x ./entrypoint.sh

# Mudar para usuário não-root
USER appuser

# Variáveis de ambiente padrão
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    BACKEND_BIND_HOST=0.0.0.0 \
    BACKEND_BIND_PORT=3001

# Expor porta do backend
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:3001/api/health || exit 1

# Executar script de inicialização
ENTRYPOINT ["./entrypoint.sh"]
CMD ["python", "-m", "uvicorn", "server:app", "--host", "0.0.0.0", "--port", "3001"]
