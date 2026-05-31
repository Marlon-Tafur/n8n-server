# Migración a VPS

## Cuándo migrar

Migrá cuando se cumpla **cualquiera** de estas condiciones:

- Tu laptop se apaga frecuentemente (workflows necesitan disponibilidad 24/7)
- Tenés 20+ workflows activos con ejecuciones constantes
- Los webhooks necesitan responder aunque tu laptop esté apagada
- Necesitás backups automáticos con cron
- Querés separar el entorno de desarrollo del de producción

---

## VPS recomendados

| Proveedor | Oferta | RAM | Costo | Notas |
|-----------|--------|-----|-------|-------|
| **Oracle Cloud** | Always Free (ARM) | 24 GB | **Gratis** | Mejor free tier del mercado. Perfecto para n8n + Ollama. |
| Hetzner | CX22 | 4 GB | ~4€/mes | Si necesitás pagar algo, mejor relación calidad/precio. |
| Hetzner | CX32 | 8 GB | ~8€/mes | Si querés Ollama en el VPS (sin GPU). |
| Google Cloud | e2-micro | 1 GB | Gratis (12 meses) | Muy justo, solo para pruebas sin Ollama. |

> Para usar Ollama en el VPS necesitás mínimo 8 GB de RAM. Oracle Cloud Free es la opción correcta.

---

## Proceso de migración

### Desde tu laptop:

```bash
bash scripts/migrate-to-vps.sh ubuntu@IP-DEL-VPS
```

El script:
1. Hace un backup completo de tu estado actual
2. Copia el proyecto con rsync (excluye `.git`, `backups/`, `.env`, `compose.local.yml`)
3. Copia el backup y los secrets vía SCP/rsync

### En el VPS (después del migrate):

```bash
ssh ubuntu@IP-DEL-VPS
cd /opt/n8n-server

# 1. Instalar Docker (si no está)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER && newgrp docker

# 2. Configurar .env
cp .env.example .env
nano .env
# Cambiar: dominios, CLOUDFLARE_TUNNEL_TOKEN (mismo o nuevo)

# 3. Levantar en modo VPS
make up-vps

# 4. Restaurar datos
bash scripts/restore.sh backups/n8n_backup_*.tar.gz

# 5. Verificar
make health
make security-check

# 6. Firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw enable
```

---

## DNS — Tunnel en el VPS

**Opción A: Reusar el mismo tunnel** (más simple)
- El tunnel ya tiene los hostnames configurados
- Solo cambia el `CLOUDFLARE_TUNNEL_TOKEN` en `.env` del VPS por el mismo token
- Cloudflare rutea al nuevo servidor automáticamente

**Opción B: Crear un nuevo tunnel**
- Seguir [02-CLOUDFLARE.md](02-CLOUDFLARE.md) para crear un tunnel nuevo
- Más limpio si el laptop seguirá siendo un entorno de desarrollo separado

---

## Si usás Ollama en el VPS

**Con Oracle Cloud (24 GB RAM):** Ollama corre bien en el mismo servidor.
```bash
make up-ai
docker exec -it n8n-ollama ollama pull llama3.1:8b
```

**Con VPS pequeño (4 GB RAM):** Ollama no cabe. Usar Claude o GPT en producción:
- En el workflow-creator, usar `"model": "claude"` en vez de `"model": "ollama"`
- Configura la API key de Anthropic en el nodo "Call Claude"

---

## Checklist post-migración

```
[ ] make health → todos los servicios healthy
[ ] make security-check → sin errores críticos
[ ] https://n8n.marlonai.net.pe → accesible con Cloudflare Access
[ ] https://hooks.marlonai.net.pe/webhook/test → responde (404 es OK)
[ ] Cron de backup configurado (ver 05-BACKUPS.md)
[ ] UFW activo y solo SSH permitido
[ ] Viejo servidor (laptop) apagado o Docker detenido para evitar conflictos
```
