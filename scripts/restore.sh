#!/usr/bin/env bash
# ============================================================
# Restaurar n8n desde backup
# ============================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${PROJECT_DIR}/.env" 2>/dev/null || true

BACKUP_DIR="${PROJECT_DIR}/backups"

# Encontrar backup
if [ -n "${1:-}" ]; then
    BACKUP_FILE="$1"
else
    BACKUP_FILE=$(ls -t "${BACKUP_DIR}"/n8n_backup_*.tar.gz 2>/dev/null | head -1)
fi

if [ -z "${BACKUP_FILE}" ] || [ ! -f "${BACKUP_FILE}" ]; then
    echo "❌ No se encontró backup."
    echo "   Uso: $0 [ruta/al/backup.tar.gz]"
    exit 1
fi

echo ""
echo "⚠️  Esto REEMPLAZARÁ todos los datos actuales con:"
echo "   ${BACKUP_FILE}"
echo ""
read -p "¿Continuar? [y/N] " confirm
[ "${confirm}" != "y" ] && echo "Cancelado." && exit 0

TEMP_DIR=$(mktemp -d)

echo ""
echo "📦 Extrayendo backup..."
tar -xzf "${BACKUP_FILE}" -C "${TEMP_DIR}"
BACKUP_NAME=$(ls "${TEMP_DIR}")

# Verificar integridad
echo "🔍 Verificando checksums..."
cd "${TEMP_DIR}/${BACKUP_NAME}"
if sha256sum -c checksums.sha256; then
    echo "  ✅ Integridad verificada"
else
    echo "  ❌ Checksums no coinciden. Backup corrupto."
    rm -rf "${TEMP_DIR}"
    exit 1
fi

# Detener n8n (no PostgreSQL — necesitamos la DB para el restore)
echo "⏹️  Deteniendo n8n..."
cd "${PROJECT_DIR}"
docker compose -f compose.yml stop n8n 2>/dev/null || true

# Restaurar secretos
echo "🔐 Restaurando secretos..."
tar -xzf "${TEMP_DIR}/${BACKUP_NAME}/secrets.tar.gz" -C "${PROJECT_DIR}/" 2>/dev/null || true

# Restaurar archivos
echo "📁 Restaurando archivos..."
tar -xzf "${TEMP_DIR}/${BACKUP_NAME}/files.tar.gz" -C "${PROJECT_DIR}/" 2>/dev/null || true

# Restaurar PostgreSQL
echo "💾 Restaurando base de datos..."
docker compose -f compose.yml exec -T postgres pg_restore \
    -U "${POSTGRES_USER:-n8n_user}" \
    -d "${POSTGRES_DB:-n8n}" \
    --clean --if-exists \
    < "${TEMP_DIR}/${BACKUP_NAME}/database.dump" || true

# Reiniciar
echo "🚀 Reiniciando servicios..."
docker compose -f compose.yml -f compose.local.yml up -d

rm -rf "${TEMP_DIR}"

echo ""
echo "✅ Restauración completada."
echo "   Verifica: make health"
echo ""
