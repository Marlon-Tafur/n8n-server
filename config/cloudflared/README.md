# Cloudflare Tunnel — Setup

## Configuración rápida

Ejecutá el script interactivo que te guía paso a paso:

```bash
bash scripts/setup-cloudflare.sh
```

El script te explica cómo:
1. Crear el tunnel en el Dashboard de Cloudflare Zero Trust
2. Configurar los dos public hostnames (`n8n.*` y `hooks.*`) apuntando a `caddy:80`
3. Proteger el editor con Cloudflare Access (login obligatorio)
4. Guardar el token en `.env`

## Resumen de la arquitectura

```
n8n.marlonai.net.pe   → Cloudflare Access (auth) → Tunnel → Caddy → n8n
hooks.marlonai.net.pe → WAF (sin Access)          → Tunnel → Caddy → n8n
```

- **El editor** está protegido: necesitás pasar login de Cloudflare Access antes de llegar a n8n.
- **Los webhooks** son públicos: Stripe, WhatsApp y otros servicios los llaman directamente.
- **Ambos** pasan por Cloudflare WAF y el tunnel encriptado — cero puertos abiertos en tu máquina.

## Variables requeridas en `.env`

```env
CLOUDFLARE_TUNNEL_TOKEN=eyJ...token-del-dashboard...
```

## Checklist post-configuración (manual en Cloudflare Dashboard)

- [ ] SSL/TLS → Overview → Mode: **Full (strict)**
- [ ] Security → WAF → Managed Rules → **Enable**
- [ ] Security → Bots → Bot Fight Mode → **Enable**
- [ ] Access → Applications → `n8n.marlonai.net.pe` configurado
- [ ] `hooks.marlonai.net.pe` sin Access policy (webhooks deben ser públicos)
- [ ] MFA activo en tu cuenta Cloudflare
- [ ] MFA activo en tu usuario n8n (Settings → Security → MFA)
