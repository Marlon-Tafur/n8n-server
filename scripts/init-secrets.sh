#!/usr/bin/env bash
# ============================================================
# Genera secretos aleatorios en ./secrets/
# Ejecutar UNA SOLA VEZ al iniciar el proyecto.
# Si el archivo ya existe, NO lo sobreescribe.
# ============================================================
set -euo pipefail

SECRETS_DIR="$(dirname "$0")/../secrets"
mkdir -p "$SECRETS_DIR"

create_secret() {
    local file="$1"
    local length="${2:-48}"
    local filepath="${SECRETS_DIR}/${file}"

    if [ -f "$filepath" ]; then
        echo "  ⏭️  Ya existe: ${file}"
    else
        openssl rand -base64 "$length" | tr -d '\n' > "$filepath"
        chmod 600 "$filepath"
        echo "  ✅ Creado:    ${file} (${length} bytes de entropía)"
    fi
}

echo ""
echo "🔐 Inicializando secretos..."
echo ""

create_secret "postgres_password.txt" 48
create_secret "n8n_encryption_key.txt" 48
create_secret "redis_password.txt" 48

# n8n_api_key se llena manualmente después del primer login
if [ ! -f "${SECRETS_DIR}/n8n_api_key.txt" ]; then
    touch "${SECRETS_DIR}/n8n_api_key.txt"
    chmod 600 "${SECRETS_DIR}/n8n_api_key.txt"
    echo "  📝 Creado:    n8n_api_key.txt (vacío — llenar después del primer login)"
fi

chmod 600 "${SECRETS_DIR}"/*.txt 2>/dev/null || true

echo ""
echo "✅ Secretos inicializados en ./secrets/"
echo ""
echo "⚠️  IMPORTANTE:"
echo "   • Estos archivos NUNCA se suben a Git (.gitignore los excluye)"
echo "   • Guarda una copia de n8n_encryption_key.txt en un lugar seguro"
echo "     (si la pierdes, todas las credenciales cifradas en n8n se pierden)"
echo "   • Llena secrets/n8n_api_key.txt después de crear la API key en n8n"
echo "     (Settings → API → Create API Key)"
echo ""
