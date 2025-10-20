"""
Centralized Configuration Module for DOM360 SDK
Loads environment variables from .env at project root
All services should import configuration from this module
"""

import os
from dotenv import load_dotenv

# Load .env from project root
env_path = os.path.join(os.path.dirname(__file__), '.env')
load_dotenv(dotenv_path=env_path)

# ============================================================================
# Database Configuration
# ============================================================================
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_PORT = int(os.getenv('DB_PORT', 5432))
DB_NAME = os.getenv('DB_NAME', 'dom360_db_sdk')
DB_USER = os.getenv('DB_USER', 'postgres')
DB_PASSWORD = os.getenv('DB_PASSWORD', '')

DATABASE_CONFIG = {
    'host': DB_HOST,
    'port': DB_PORT,
    'database': DB_NAME,
    'user': DB_USER,
    'password': DB_PASSWORD,
}

# ============================================================================
# Backend API (FastAPI)
# ============================================================================
BACKEND_PORT = int(os.getenv('BACKEND_PORT', 3001))
BACKEND_BIND_HOST = os.getenv('BACKEND_BIND_HOST', '0.0.0.0')
BACKEND_BIND_PORT = int(os.getenv('BACKEND_BIND_PORT', BACKEND_PORT))
INTERNAL_BACKEND_HOST = os.getenv('INTERNAL_BACKEND_HOST', '127.0.0.1')
INTERNAL_BACKEND_PORT = int(os.getenv('INTERNAL_BACKEND_PORT', 3001))
PUBLIC_BACKEND_URL = os.getenv('PUBLIC_BACKEND_URL', 'https://api.srcjohann.com.br')
PUBLIC_BACKEND_HOST = os.getenv('PUBLIC_BACKEND_HOST', 'api.srcjohann.com.br')

# ============================================================================
# Frontend Configuration
# ============================================================================
FRONTEND_BIND_HOST = os.getenv('FRONTEND_BIND_HOST', '0.0.0.0')
FRONTEND_BIND_PORT = int(os.getenv('FRONTEND_BIND_PORT', 5173))
INTERNAL_FRONTEND_HOST = os.getenv('INTERNAL_FRONTEND_HOST', '127.0.0.1')
INTERNAL_FRONTEND_PORT = int(os.getenv('INTERNAL_FRONTEND_PORT', 5173))
PUBLIC_FRONTEND_URL = os.getenv('PUBLIC_FRONTEND_URL', 'https://sdk.srcjohann.com.br')
PUBLIC_FRONTEND_HOST = os.getenv('PUBLIC_FRONTEND_HOST', 'sdk.srcjohann.com.br')

# Vite environment variables for frontend
VITE_API_URL = os.getenv('VITE_API_URL', PUBLIC_BACKEND_URL)

# ============================================================================
# Security
# ============================================================================
JWT_SECRET = os.getenv('JWT_SECRET', 'eSGm2XZ8lBfB++3TOt0Tp0rR8MimWnohTD9oqaq+Q84=')
ENCRYPTION_KEY = os.getenv('ENCRYPTION_KEY', '')

# ============================================================================
# CORS Configuration
# ============================================================================
# Format: url1,url2,url3 (separated by commas)
CORS_ORIGINS_STR = os.getenv('CORS_ORIGINS', '')
CORS_ORIGINS = CORS_ORIGINS_STR.split(',') if CORS_ORIGINS_STR else [
    'http://localhost:5173',
    'http://localhost:3001',
    'http://127.0.0.1:5173',
    'http://127.0.0.1:3001',
    'http://srcjohann.com.br',
    'http://api.srcjohann.com.br',
    'https://srcjohann.com.br',
    'https://api.srcjohann.com.br',
]

# Clean up whitespace in CORS origins
CORS_ORIGINS = [origin.strip() for origin in CORS_ORIGINS if origin.strip()]

# ============================================================================
# Environment
# ============================================================================
NODE_ENV = os.getenv('NODE_ENV', 'production')
PYTHON_ENV = os.getenv('PYTHON_ENV', 'production')
DEBUG = PYTHON_ENV == 'development'

# ============================================================================
# Logging
# ============================================================================
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
LOG_FORMAT = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'

# ============================================================================
# Docker/Portainer Traefik Labels Configuration
# ============================================================================
# Service names for Traefik routing
BACKEND_SERVICE_NAME = 'dom360-backend'
FRONTEND_SERVICE_NAME = 'dom360-frontend'
TRAEFIK_NETWORK = 'traefik'
