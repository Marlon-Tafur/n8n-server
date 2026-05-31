# Cloudflare Tunnel + Access — Setup Completo

## Arquitectura

```
n8n.marlonai.net.pe   → Cloudflare Access (login) → Tunnel → Caddy :80 → n8n :5678
hooks.marlonai.net.pe → WAF (sin login)            → Tunnel → Caddy :80 → n8n :5678
```

El tunnel hace conexión **saliente** desde tu máquina hacia Cloudflare — cero puertos abiertos.

---

## Parte 1 — Crear el Tunnel

1. Ir a [https://one.dash.cloudflare.com/](https://one.dash.cloudflare.com/)
2. Menú lateral → **Networks → Tunnels → Create a tunnel**
3. Seleccionar **Cloudflared** como tipo de conector
4. Nombre del tunnel: `n8n-server`
5. En la pantalla del conector, seleccionar **Docker** y copiar **solo el token** (la cadena larga después de `--token`)
6. Pegar el token en `.env`:
```env
CLOUDFLARE_TUNNEL_TOKEN=eyJ...token...
```

---

## Parte 2 — Configurar Public Hostnames

En la configuración del tunnel, sección **Public Hostnames**, agregar DOS entradas:

### Entrada 1 — Editor (protegido)
| Campo | Valor |
|-------|-------|
| Subdomain | `n8n` |
| Domain | `marlonai.net.pe` |
| Type | `HTTP` |
| URL | `caddy:80` |

### Entrada 2 — Webhooks (público)
| Campo | Valor |
|-------|-------|
| Subdomain | `hooks` |
| Domain | `marlonai.net.pe` |
| Type | `HTTP` |
| URL | `caddy:80` |

> ⚠️ La URL debe ser `caddy:80` (nombre del servicio Docker en la red `public`).
> NO uses `localhost` ni `127.0.0.1` — cloudflared y caddy se comunican por nombre dentro de Docker.

---

## Parte 3 — Cloudflare Access para el Editor

1. Zero Trust Dashboard → **Access → Applications → Add an Application**
2. Tipo: **Self-hosted**
3. **Application domain**: `n8n.marlonai.net.pe`
4. **Policy name**: `n8n-editor-access`
5. **Action**: Allow
6. **Include**: Emails → agregar `tu@email.com`
7. Guardar

> ⚠️ **NO** crear Access policy para `hooks.marlonai.net.pe` — los webhooks necesitan ser accesibles por Stripe, WhatsApp, Telegram, etc. sin autenticación.

---

## Parte 4 — WAF para Webhooks

1. Cloudflare Dashboard → tu dominio → **Security → WAF**
2. **Managed Rules** → Enable
3. **Custom Rules** (opcional): rate limiting por IP para `/webhook/*`

---

## Parte 5 — Configuración SSL y Seguridad

En el Cloudflare Dashboard de tu dominio:

| Sección | Configuración |
|---------|--------------|
| SSL/TLS → Overview | Mode: **Full (strict)** |
| Security → WAF | Managed Rules: **Enabled** |
| Security → Bots | Bot Fight Mode: **On** |
| Security → Settings | Challenge Passage: **30 minutos** |

---

## Verificación

Después de configurar todo y ejecutar `make up`:

```bash
# Verificar que el tunnel está activo
docker logs n8n-tunnel 2>&1 | grep -i "connection"

# Acceder al editor
curl -I https://n8n.marlonai.net.pe
# Debe redirigir a Cloudflare Access login

# Probar webhook (debe responder 404 si no hay workflow)
curl -X POST https://hooks.marlonai.net.pe/webhook/test
```
