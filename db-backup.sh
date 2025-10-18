#!/bin/bash

# ==============================================================================
# DOM360 - Database Backup & Restore
# Script para fazer backup e restore do PostgreSQL em Docker
# ==============================================================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ==============================================================================
# Configuration
# ==============================================================================

BACKUP_DIR="./backups"
DB_NAME="${DB_NAME:-dom360_db_sdk}"
DB_USER="${DB_USER:-postgres}"
COMPOSE_FILE="${COMPOSE_FILE:-.env}"

# ==============================================================================
# Functions
# ==============================================================================

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} $1"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}[→]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

create_backup() {
    print_header "Criando Backup do Banco de Dados"
    
    mkdir -p "$BACKUP_DIR"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/backup_${DB_NAME}_${timestamp}.sql"
    
    print_step "Backup: $backup_file"
    
    # Verificar se container está rodando
    if ! docker-compose ps postgres | grep -q "Up"; then
        print_error "PostgreSQL não está rodando!"
        exit 1
    fi
    
    # Fazer dump
    if docker-compose exec -T postgres pg_dump -U $DB_USER $DB_NAME > "$backup_file"; then
        print_success "Dump SQL criado"
    else
        print_error "Falha ao criar dump!"
        exit 1
    fi
    
    # Comprimir
    print_step "Comprimindo..."
    gzip "$backup_file"
    backup_file="${backup_file}.gz"
    
    local size=$(du -h "$backup_file" | cut -f1)
    print_success "Backup criado: $(basename "$backup_file") (${size})"
    
    # Listar backups antigos
    echo ""
    print_step "Backups disponíveis:"
    ls -lh "$BACKUP_DIR"/backup_${DB_NAME}_*.sql.gz 2>/dev/null | tail -5 || echo "  Nenhum backup anterior"
    
    # Limpeza automática de backups antigos (mais de 30 dias)
    echo ""
    print_step "Limpando backups com mais de 30 dias..."
    find "$BACKUP_DIR" -name "backup_${DB_NAME}_*.sql.gz" -mtime +30 -delete
    print_success "Limpeza concluída"
}

list_backups() {
    print_header "Backups Disponíveis"
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        print_warning "Nenhum backup encontrado em $BACKUP_DIR"
        return
    fi
    
    echo -e "${CYAN}Backups disponíveis:${NC}"
    ls -lh "$BACKUP_DIR"/backup_${DB_NAME}_*.sql.gz 2>/dev/null | awk '{
        print NR ". " $9 " (" $5 ")"
    }' || print_error "Nenhum backup encontrado"
}

restore_backup() {
    local backup_file=$1
    
    if [ -z "$backup_file" ]; then
        print_header "Restaurar Backup"
        list_backups
        echo ""
        read -p "Digite o caminho completo do backup: " backup_file
    fi
    
    if [ ! -f "$backup_file" ]; then
        print_error "Arquivo não encontrado: $backup_file"
        exit 1
    fi
    
    print_header "Restaurando Backup"
    print_warning "ATENÇÃO: Isto SOBRESCREVERÁ o banco de dados atual!"
    echo ""
    
    read -p "Continuar? Digite o nome do banco ($DB_NAME) para confirmar: " confirm
    
    if [ "$confirm" != "$DB_NAME" ]; then
        print_error "Cancelado pelo usuário"
        exit 1
    fi
    
    # Verificar se container está rodando
    if ! docker-compose ps postgres | grep -q "Up"; then
        print_error "PostgreSQL não está rodando!"
        exit 1
    fi
    
    print_step "Restaurando de $backup_file..."
    
    # Detectar se arquivo está comprimido
    if [[ "$backup_file" == *.gz ]]; then
        if gunzip -c "$backup_file" | docker-compose exec -T postgres psql -U $DB_USER -d $DB_NAME; then
            print_success "Backup restaurado com sucesso!"
        else
            print_error "Falha ao restaurar backup!"
            exit 1
        fi
    else
        if docker-compose exec -T postgres psql -U $DB_USER -d $DB_NAME < "$backup_file"; then
            print_success "Backup restaurado com sucesso!"
        else
            print_error "Falha ao restaurar backup!"
            exit 1
        fi
    fi
    
    echo ""
    print_step "Verificando integridade do banco..."
    docker-compose exec -T postgres psql -U $DB_USER -d $DB_NAME -c "SELECT 'OK' as status;"
}

export_schema() {
    print_header "Exportar Schema"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local schema_file="$BACKUP_DIR/schema_${DB_NAME}_${timestamp}.sql"
    
    mkdir -p "$BACKUP_DIR"
    
    print_step "Exportando schema para: $schema_file"
    
    # Apenas schema, sem dados
    if docker-compose exec -T postgres pg_dump -U $DB_USER --schema-only $DB_NAME > "$schema_file"; then
        print_success "Schema exportado"
        wc -l "$schema_file"
    else
        print_error "Falha ao exportar schema!"
        exit 1
    fi
}

backup_to_remote() {
    local remote_host=$1
    local remote_path=$2
    
    if [ -z "$remote_host" ] || [ -z "$remote_path" ]; then
        print_error "Uso: $0 remote-backup REMOTE_HOST REMOTE_PATH"
        echo "  Exemplo: ./db-backup.sh remote-backup user@192.168.1.10 /backups/dom360"
        exit 1
    fi
    
    print_header "Backup para Servidor Remoto"
    
    # Criar backup local
    create_backup
    
    # Obter nome do último backup
    local latest_backup=$(ls -t "$BACKUP_DIR"/backup_${DB_NAME}_*.sql.gz | head -1)
    
    if [ -z "$latest_backup" ]; then
        print_error "Nenhum backup encontrado!"
        exit 1
    fi
    
    print_step "Enviando para $remote_host:$remote_path..."
    
    if scp "$latest_backup" "$remote_host:$remote_path/"; then
        print_success "Backup enviado para servidor remoto"
    else
        print_error "Falha ao enviar backup para servidor remoto!"
        exit 1
    fi
}

schedule_backup() {
    print_header "Agendar Backup Automático"
    
    local backup_script=$(readlink -f "$0")
    
    print_step "Adicionando ao crontab..."
    
    (crontab -l 2>/dev/null || echo "") | grep -v "db-backup.sh" | crontab - 2>/dev/null || true
    
    echo "0 2 * * * $backup_script create > /tmp/backup_cron.log 2>&1" | crontab -
    
    print_success "Backup agendado para 2:00 da manhã todos os dias"
    echo ""
    echo "Crontab:"
    crontab -l
}

print_help() {
    cat << EOF
${CYAN}DOM360 Database Backup & Restore${NC}

${BLUE}Uso:${NC}
  $0 [comando] [opções]

${BLUE}Comandos:${NC}
  create           Criar novo backup
  list             Listar backups disponíveis
  restore [FILE]   Restaurar de um backup
  schema           Exportar apenas schema
  remote-backup    Enviar backup para servidor remoto
  schedule         Agendar backup automático
  help             Mostrar esta mensagem

${BLUE}Exemplos:${NC}
  $0 create
  $0 list
  $0 restore ./backups/backup_dom360_db_sdk_20240101_120000.sql.gz
  $0 schema
  $0 remote-backup user@vps.com /backups/dom360
  $0 schedule

${BLUE}Configuração:${NC}
  DB_NAME=${DB_NAME}
  DB_USER=${DB_USER}
  BACKUP_DIR=${BACKUP_DIR}

EOF
}

# ==============================================================================
# Main
# ==============================================================================

case "${1:-help}" in
    create)
        create_backup
        ;;
    list)
        list_backups
        ;;
    restore)
        restore_backup "$2"
        ;;
    schema)
        export_schema
        ;;
    remote-backup)
        backup_to_remote "$2" "$3"
        ;;
    schedule)
        schedule_backup
        ;;
    help|--help|-h)
        print_help
        ;;
    *)
        print_error "Comando desconhecido: $1"
        echo ""
        print_help
        exit 1
        ;;
esac
