#!/usr/bin/env python3
"""
Script para exportar o schema atual do banco de dados PostgreSQL dom360_db.

Este script conecta ao banco de dados usando as credenciais do arquivo .env
ou variáveis de ambiente, executa pg_dump com flags --schema-only, --no-owner,
--no-privileges, e salva o resultado em ./database/schema.sql.

Uso:
    python export_schema.py

Ou importe e use a função export_schema():
    from export_schema import export_schema
    export_schema()
"""

import os
import subprocess
import sys
from pathlib import Path

# Carregar variáveis de ambiente do .env se existir
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    print("Aviso: python-dotenv não instalado. Usando apenas variáveis de ambiente do sistema.")

# Credenciais do banco
DB_HOST = os.getenv('DB_HOST', '127.0.0.1')
DB_PORT = os.getenv('DB_PORT', '5432')
DB_NAME = os.getenv('DB_NAME', 'dom360_db_sdk')
DB_USER = os.getenv('DB_USER', 'postgres')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'admin')

# Caminho do arquivo de saída
OUTPUT_FILE = Path(__file__).parent / 'database' / 'schema.sql'

def export_schema():
    """
    Função para exportar o schema do banco de dados.

    Executa pg_dump e salva o schema em ./database/schema.sql.
    """
    # Comando pg_dump
    cmd = [
        'pg_dump',
        '--host', DB_HOST,
        '--port', DB_PORT,
        '--username', DB_USER,
        '--dbname', DB_NAME,
        '--schema-only',
        '--no-owner',
        '--no-privileges',
        '--file', str(OUTPUT_FILE)
    ]

    # Definir senha via variável de ambiente para pg_dump
    env = os.environ.copy()
    env['PGPASSWORD'] = DB_PASSWORD

    try:
        print(f"Conectando ao banco {DB_NAME} em {DB_HOST}:{DB_PORT} como {DB_USER}...")
        result = subprocess.run(cmd, env=env, check=True, capture_output=True, text=True)
        print(f"Schema exportado com sucesso para {OUTPUT_FILE}")
        print("O arquivo pode ser usado para inicializar novos bancos com: psql -U <user> -d <database> -f schema.sql")
    except subprocess.CalledProcessError as e:
        print(f"Erro ao executar pg_dump: {e}")
        print(f"Stdout: {e.stdout}")
        print(f"Stderr: {e.stderr}")
        sys.exit(1)
    except FileNotFoundError:
        print("Erro: pg_dump não encontrado. Certifique-se de que PostgreSQL está instalado e pg_dump está no PATH.")
        sys.exit(1)

if __name__ == '__main__':
    export_schema()