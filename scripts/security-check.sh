#!/usr/bin/env bash
# ============================================================
# Auditoría de seguridad automatizada
# ============================================================
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0

echo ""
echo "🔒 Auditoría de Seguridad — n8n Server"
echo "========================================"
echo ""

# --- Secretos en .env ---
echo "📋 Secretos:"

if [ -f "${PROJECT_DIR}/.env" ]; then
    for pattern in "POSTGRES_PASSWORD=" "N8N_ENCRYPTION_KEY=" "REDIS_PASSWORD=" "N8N_API_KEY="; do
        if grep -q "^${pattern}" "${PROJECT_DIR}/.env" 2>/dev/null; then
            VALUE=$(grep "^${pattern}" "${PROJECT_DIR}/.env" | head -1 | cut -d= -f2-)
            if [ -n "$VALUE" ] && [ "$VALUE" != "tu-token-del-tunnel-aqui" ]; then
                echo "  ❌ ${pattern%=} está en .env (debe estar en ./secrets/)"
                ERRORS=$((ERRORS + 1))
            fi
        fi
    done
    echo "  ✅ Passwords no detectados en .env"
else
    echo "  ⚠️  .env no existe (ejecutá make setup)"
fi

# --- Archivos de secretos ---
echo ""
echo "📋 Archivos de secretos:"

for SECRET_FILE in postgres_password.txt n8n_encryption_key.txt; do
    FILEPATH="${PROJECT_DIR}/secrets/${SECRET_FILE}"
    if [ ! -f "$FILEPATH" ]; then
        echo "  ❌ Falta: secrets/${SECRET_FILE}"
        ERRORS=$((ERRORS + 1))
    elif [ ! -s "$FILEPATH" ]; then
        echo "  ❌ Vacío: secrets/${SECRET_FILE}"
        ERRORS=$((ERRORS + 1))
    else
        PERMS=$(stat -c %a "$FILEPATH" 2>/dev/null || stat -f %Lp "$FILEPATH" 2>/dev/null || echo "???")
        if [ "$PERMS" = "600" ]; then
            echo "  ✅ secrets/${SECRET_FILE} (permisos: 600)"
        else
            echo "  ⚠️  secrets/${SECRET_FILE} (permisos: ${PERMS}, debería ser 600)"
        fi
    fi
done

# --- Git ---
echo ""
echo "📋 Git:"

if git -C "${PROJECT_DIR}" check-ignore -q secrets/postgres_password.txt 2>/dev/null; then
    echo "  ✅ secrets/ ignorado por Git"
else
    echo "  ❌ secrets/ NO está ignorado por Git"
    ERRORS=$((ERRORS + 1))
fi

if git -C "${PROJECT_DIR}" check-ignore -q .env 2>/dev/null; then
    echo "  ✅ .env ignorado por Git"
else
    echo "  ❌ .env NO está ignorado por Git"
    ERRORS=$((ERRORS + 1))
fi

# --- Contenedores ---
echo ""
echo "📋 Contenedores:"

PG_PORTS=$(docker port n8n-postgres 2>/dev/null || echo "none")
if echo "$PG_PORTS" | grep -q "0.0.0.0"; then
    echo "  ❌ PostgreSQL expuesto a 0.0.0.0 (riesgo: acceso desde cualquier IP)"
    ERRORS=$((ERRORS + 1))
elif echo "$PG_PORTS" | grep -q "127.0.0.1"; then
    echo "  ⚠️  PostgreSQL expuesto en 127.0.0.1 (OK en dev, NO en prod)"
elif echo "$PG_PORTS" | grep -q "none\|^$"; then
    echo "  ✅ PostgreSQL sin puertos publicados (contenedor no corriendo o no expuesto)"
else
    echo "  ✅ PostgreSQL sin puertos públicos"
fi

# --- Resumen ---
echo ""
echo "========================================"
if [ $ERRORS -gt 0 ]; then
    echo "❌ ${ERRORS} problema(s) encontrado(s). Revisar arriba."
    EXIT_CODE=1
else
    echo "✅ Sin problemas críticos detectados."
    EXIT_CODE=0
fi

echo ""
echo "📋 Checklist manual (verificar en Cloudflare Dashboard):"
echo "   • SSL/TLS → Mode: Full (strict)"
echo "   • Security → WAF → Managed Rules → Habilitado"
echo "   • Access → Applications → n8n.tudominio.com configurado"
echo "   • hooks.tudominio.com sin Access (webhooks deben ser públicos)"
echo "   • MFA activo en cuenta Cloudflare"
echo "   • MFA activo en usuario n8n (Settings → Security)"
echo ""

exit $EXIT_CODE
