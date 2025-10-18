#!/bin/bash

# ==============================================================================
# DOM360 - Make scripts executable
# Torna todos os scripts Docker executáveis
# ==============================================================================

echo "Tornando scripts executáveis..."

chmod +x docker-dev.sh 2>/dev/null && echo "✓ docker-dev.sh"
chmod +x docker-health.sh 2>/dev/null && echo "✓ docker-health.sh"
chmod +x docker-entrypoint.sh 2>/dev/null && echo "✓ docker-entrypoint.sh"
chmod +x deploy-docker.sh 2>/dev/null && echo "✓ deploy-docker.sh"
chmod +x db-backup.sh 2>/dev/null && echo "✓ db-backup.sh"

echo ""
echo "✓ Todos os scripts estão executáveis!"
echo ""
echo "Próximos passos:"
echo "  - Desenvolvimento local: ./docker-dev.sh up"
echo "  - Deploy em VPS: sudo ./deploy-docker.sh"
echo "  - Ver health: ./docker-health.sh"
echo "  - Backup/Restore: ./db-backup.sh"
