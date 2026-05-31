# Quick Start — n8n Self-Hosted

## Prerrequisitos

- **Docker Desktop** (incluye Docker Compose v2) — [descargar](https://www.docker.com/products/docker-desktop/)
- **Cuenta Cloudflare** (gratis) con tu dominio usando Cloudflare DNS
- **Git** instalado
- Un dominio con DNS en Cloudflare (el tuyo es `marlonai.net.pe`)

## 7 pasos para empezar

### Paso 1 — Setup inicial
```bash
make setup
```
Esto:
- Crea `.env` desde `.env.example`
- Genera secretos aleatorios en `secrets/` (postgres, encryption key, redis)
- Da instrucciones para el siguiente paso

### Paso 2 — Configurar dominios en `.env`
```bash
# Editar .env y cambiar:
N8N_EDITOR_HOST=n8n.marlonai.net.pe
N8N_WEBHOOK_HOST=hooks.marlonai.net.pe
N8N_EDITOR_BASE_URL=https://n8n.marlonai.net.pe
WEBHOOK_URL=https://hooks.marlonai.net.pe/
```

### Paso 3 — Configurar Cloudflare Tunnel
```bash
bash scripts/setup-cloudflare.sh
```
El script te guía para crear el tunnel y pegar el token en `.env`.
Ver [02-CLOUDFLARE.md](02-CLOUDFLARE.md) para instrucciones detalladas.

### Paso 4 — Levantar los servicios
```bash
make up
```
Levanta PostgreSQL, n8n, Caddy y Cloudflare Tunnel.

### Paso 5 — Verificar que todo funciona
```bash
make health          # Estado de contenedores + HTTP check
make security-check  # Auditoría de secretos y seguridad
```

### Paso 6 — Primer acceso
1. Abrí `https://n8n.marlonai.net.pe` (pasarás por Cloudflare Access)
2. Creá tu cuenta de administrador
3. Activá MFA: Settings → Security → Two-factor authentication
4. Creá API Key: Settings → API → Create API Key
5. Guardá la API Key:
```bash
echo "tu-api-key" > secrets/n8n_api_key.txt
```

### Paso 7 — Primer backup
```bash
make backup
```

---

## Activar IA local (opcional)

```bash
make up-ai
# Esperar a que Ollama esté corriendo, luego descargar un modelo:
docker exec -it n8n-ollama ollama pull llama3.1:8b
```

Ver [04-AI-SETUP.md](04-AI-SETUP.md) para configuración completa.

---

## Activar Queue Mode (opcional)

Activar cuando tengas 20+ workflows activos o necesites ejecuciones persistentes.

```bash
# Agregar REDIS_PASSWORD al .env:
echo "REDIS_PASSWORD=$(cat secrets/redis_password.txt)" >> .env

make up-queue
```

---

## Comandos del día a día

```bash
make status      # ¿Qué está corriendo?
make logs-n8n    # Ver logs de n8n
make restart     # Reiniciar n8n
make down        # Detener todo
make update      # Actualizar n8n a última versión
```
