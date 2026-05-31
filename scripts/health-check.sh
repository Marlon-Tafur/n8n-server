#!/usr/bin/env bash
# ============================================================
# Health check de todos los servicios
# ============================================================
set -uo pipefail

echo ""
echo "🏥 Health Check — n8n Server"
echo "=============================="
echo ""

check_service() {
    local name=$1
    local container=$2
    local status

    status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "missing")

    case "$status" in
        healthy)
            echo "  ✅ ${name}: healthy"
            ;;
        unhealthy)
            echo "  ❌ ${name}: unhealthy"
            ;;
        starting)
            echo "  🟡 ${name}: starting (healthcheck en progreso)"
            ;;
        missing)
            echo "  ⬚  ${name}: no existe o no está corriendo"
            ;;
        *)
            local running
            running=$(docker inspect --format='{{.State.Running}}' "$container" 2>/dev/null || echo "false")
            if [ "$running" = "true" ]; then
                echo "  🟡 ${name}: running (sin healthcheck definido)"
            else
                echo "  ⬚  ${name}: detenido"
            fi
            ;;
    esac
}

echo "Core:"
check_service "PostgreSQL" "n8n-postgres"
check_service "n8n" "n8n-app"
check_service "Caddy" "n8n-caddy"

echo ""
echo "Exposición:"
check_service "Cloudflare Tunnel" "n8n-tunnel"

echo ""
echo "Opcionales:"
check_service "Redis" "n8n-redis"
check_service "n8n Worker" "n8n-worker"
check_service "Ollama" "n8n-ollama"
check_service "Qdrant" "n8n-qdrant"

# HTTP check a Caddy
echo ""
echo "HTTP:"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 5 http://127.0.0.1:8080/caddy-health 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" = "200" ]; then
    echo "  ✅ Caddy responde: HTTP ${HTTP_STATUS} en /caddy-health"
else
    echo "  ❌ Caddy no responde en 127.0.0.1:8080/caddy-health (HTTP ${HTTP_STATUS})"
fi

# Disco
echo ""
echo "Disco:"
DOCKER_USAGE=$(docker system df --format 'table {{.Type}}\t{{.Size}}' 2>/dev/null || echo "Docker no disponible")
echo "${DOCKER_USAGE}" | while IFS= read -r line; do
    echo "  ${line}"
done
echo ""
