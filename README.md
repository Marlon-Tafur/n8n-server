# n8n Self-Hosted

n8n con PostgreSQL, Caddy y Cloudflare Tunnel. Corre en laptop, migra a VPS sin reescribir nada.
Seguro por defecto: 8 capas de protección, secretos en archivos, IA integrada con Ollama o Claude.

## Quick Start

```bash
make setup                   # Genera secretos + crea .env
# Editá .env con tus dominios reales
bash scripts/setup-cloudflare.sh  # Configura el tunnel
make up                      # Levanta todo
make health                  # Verificá que funciona
```

Primer acceso en `https://n8n.marlonai.net.pe` (Cloudflare Access te pedirá login).

---

## Documentación

| Doc | Contenido |
|-----|-----------|
| [01-QUICKSTART.md](docs/01-QUICKSTART.md) | Setup completo paso a paso |
| [02-CLOUDFLARE.md](docs/02-CLOUDFLARE.md) | Tunnel, Access, WAF, SSL |
| [03-SECURITY.md](docs/03-SECURITY.md) | Las 8 capas de seguridad, rotación de secrets |
| [04-AI-SETUP.md](docs/04-AI-SETUP.md) | Ollama local, Claude API, workflow creator |
| [05-BACKUPS.md](docs/05-BACKUPS.md) | Backup/restore, cron en VPS |
| [06-MIGRATION.md](docs/06-MIGRATION.md) | Migrar de laptop a VPS |

---

## Comandos disponibles

```bash
make help          # Ver todos los comandos
```

| Comando | Descripción |
|---------|-------------|
| `make up` | Levanta n8n en modo laptop |
| `make up-ai` | Levanta n8n + Ollama + Qdrant |
| `make up-queue` | Levanta n8n + Redis + Worker |
| `make up-full` | Levanta todo |
| `make down` | Detiene todos los servicios |
| `make logs-n8n` | Logs de n8n en tiempo real |
| `make status` | Estado de los contenedores |
| `make backup` | Backup manual |
| `make restore` | Restaurar desde backup |
| `make health` | Health check completo |
| `make security-check` | Auditoría de seguridad |
| `make shell-n8n` | Shell dentro del contenedor n8n |
| `make shell-db` | psql en PostgreSQL |

---

## Arquitectura

```
Internet → Cloudflare Edge (WAF + DDoS)
         → Cloudflare Access (auth para editor)
         → Tunnel encriptado (zero ports abiertos)
         → Caddy :80 (security headers)
         → n8n :5678
         → PostgreSQL (red internal, sin internet)
```

---

## Checklist post-instalación

```
Servicios:
  [ ] make health → n8n, postgres, caddy: healthy
  [ ] make security-check → sin errores críticos
  [ ] https://n8n.marlonai.net.pe → accesible

Cloudflare:
  [ ] SSL/TLS → Full (strict)
  [ ] WAF → Managed Rules habilitado
  [ ] Access → n8n.marlonai.net.pe protegido
  [ ] hooks.marlonai.net.pe sin Access (público)

n8n:
  [ ] MFA activo (Settings → Security)
  [ ] API Key creada y guardada en secrets/n8n_api_key.txt
  [ ] Primer backup hecho (make backup)
```
