#!/usr/bin/env bash
# ============================================================
# Migración de Laptop a VPS
# ============================================================
# Uso: ./scripts/migrate-to-vps.sh usuario@ip-del-vps
# ============================================================
set -euo pipefail

VPS_HOST=${1:-""}
REMOTE_DIR="/opt/n8n-server"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "$VPS_HOST" ]; then
    echo ""
    echo "Uso: $0 usuario@ip-del-vps"
    echo ""
    echo "Ejemplo: $0 ubuntu@203.0.113.10"
    echo ""
    exit 1
fi

echo ""
echo "🚀 Migración a VPS: ${VPS_HOST}"
echo "==================================="

# 1. Backup
echo ""
echo "Paso 1/3: Generando backup local..."
bash "${PROJECT_DIR}/scripts/backup.sh"
LATEST_BACKUP=$(ls -t "${PROJECT_DIR}"/backups/n8n_backup_*.tar.gz 2>/dev/null | head -1)

if [ -z "$LATEST_BACKUP" ]; then
    echo "❌ No se encontró backup generado. Abortando."
    exit 1
fi

# 2. Copiar proyecto (sin datos volátiles)
echo ""
echo "Paso 2/3: Copiando proyecto al VPS..."
rsync -avz --progress \
    --exclude '.git/' \
    --exclude 'volumes/' \
    --exclude 'backups/' \
    --exclude '.env' \
    --exclude 'compose.local.yml' \
    "${PROJECT_DIR}/" "${VPS_HOST}:${REMOTE_DIR}/"

# 3. Copiar backup y secretos por separado (datos sensibles)
echo ""
echo "Paso 3/3: Copiando backup y secretos..."
scp "${LATEST_BACKUP}" "${VPS_HOST}:${REMOTE_DIR}/backups/"
rsync -avz "${PROJECT_DIR}/secrets/" "${VPS_HOST}:${REMOTE_DIR}/secrets/"
ssh "${VPS_HOST}" "chmod 600 ${REMOTE_DIR}/secrets/*.txt 2>/dev/null || true"

echo ""
echo "==================================="
echo "✅ Archivos copiados al VPS."
echo ""
echo "Conectate al VPS y ejecutá estos comandos:"
echo ""
echo "  ssh ${VPS_HOST}"
echo "  cd ${REMOTE_DIR}"
echo ""
echo "  # 1. Instalar Docker (si no está)"
echo "  curl -fsSL https://get.docker.com | sh"
echo "  sudo usermod -aG docker \$USER && newgrp docker"
echo ""
echo "  # 2. Configurar .env"
echo "  cp .env.example .env"
echo "  nano .env   # ajustar dominios y CLOUDFLARE_TUNNEL_TOKEN"
echo ""
echo "  # 3. Levantar en modo VPS"
echo "  make up-vps"
echo ""
echo "  # 4. Restaurar datos"
echo "  bash scripts/restore.sh backups/$(basename "${LATEST_BACKUP}")"
echo ""
echo "  # 5. Verificar"
echo "  make health"
echo "  make security-check"
echo ""
echo "  # 6. Firewall (UFW)"
echo "  sudo ufw default deny incoming"
echo "  sudo ufw default allow outgoing"
echo "  sudo ufw allow ssh"
echo "  sudo ufw enable"
echo "  # NO abrir 80/443 si usás Cloudflare Tunnel"
echo ""
