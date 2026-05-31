#!/usr/bin/env bash
# ============================================================
# Backup: PostgreSQL + secretos + config + archivos
# ============================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${PROJECT_DIR}/.env" 2>/dev/null || true

BACKUP_DIR="${PROJECT_DIR}/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="n8n_backup_${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

mkdir -p "${BACKUP_PATH}"

echo ""
echo "📦 Backup: ${BACKUP_NAME}"
echo ""

# 1. PostgreSQL (formato custom, comprimido)
echo "  💾 PostgreSQL..."
if ! docker compose -f "${PROJECT_DIR}/compose.yml" ps --status running postgres 2>/dev/null | grep -q "postgres"; then
    echo "  ❌ ERROR: El contenedor postgres no está corriendo."
    echo "     Iniciá los servicios primero: make up"
    rm -rf "${BACKUP_PATH}"
    exit 1
fi

docker compose -f "${PROJECT_DIR}/compose.yml" exec -T postgres pg_dump \
    -U "${POSTGRES_USER:-n8n_user}" \
    -d "${POSTGRES_DB:-n8n}" \
    --format=custom \
    --compress=9 \
    > "${BACKUP_PATH}/database.dump"

# 2. Secretos
echo "  🔐 Secretos..."
tar -czf "${BACKUP_PATH}/secrets.tar.gz" \
    -C "${PROJECT_DIR}" secrets/ 2>/dev/null || true

# 3. Archivos binarios de n8n
echo "  📁 Archivos binarios..."
tar -czf "${BACKUP_PATH}/files.tar.gz" \
    -C "${PROJECT_DIR}" files/ 2>/dev/null || true

# 4. Configuración
echo "  ⚙️  Configuración..."
tar -czf "${BACKUP_PATH}/config.tar.gz" \
    -C "${PROJECT_DIR}" \
    compose.yml compose.local.yml compose.vps.yml \
    compose.ai.yml compose.queue.yml \
    config/ .env 2>/dev/null || true

# 5. Checksums de integridad
echo "  🔍 Checksums..."
cd "${BACKUP_PATH}"
sha256sum ./*.dump ./*.tar.gz > checksums.sha256

# 6. Comprimir todo
echo "  📦 Comprimiendo..."
cd "${BACKUP_DIR}"
tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}/"
rm -rf "${BACKUP_NAME}/"

# 7. Limpiar backups antiguos
RETENTION=${BACKUP_RETENTION_DAYS:-30}
find "${BACKUP_DIR}" -name "n8n_backup_*.tar.gz" \
    -mtime +"${RETENTION}" -delete 2>/dev/null || true

BACKUP_SIZE=$(du -sh "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)
echo ""
echo "✅ Backup completado: ${BACKUP_NAME}.tar.gz (${BACKUP_SIZE})"
echo "   Ubicación: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
echo ""
