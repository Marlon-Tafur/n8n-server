# Seguridad — Capas de Protección

## Las 8 capas de seguridad

### Capa 1 — Cloudflare Edge
- IP real del servidor **oculta** (nadie sabe dónde corre n8n)
- Protección **DDoS** automática
- **WAF** (Web Application Firewall) con reglas administradas
- **SSL/TLS** automático (Full strict)
- Zero puertos abiertos en tu máquina

### Capa 2 — Cloudflare Access (Zero Trust)
- Login **obligatorio** para el editor (`n8n.marlonai.net.pe`)
- Webhooks **públicos separados** (`hooks.marlonai.net.pe`)
- Soporte **MFA** via Cloudflare
- Incluso si alguien sabe la URL, necesita pasar Access

### Capa 3 — Cloudflare Tunnel
- Conexión **saliente** (tu máquina llama a Cloudflare, no al revés)
- Tráfico **encriptado** end-to-end
- Sin firewall rules complejas — simplemente no hay puertos abiertos

### Capa 4 — Caddy (Reverse Proxy)
- Headers de seguridad: `X-Frame-Options`, `X-Content-Type-Options`, `X-XSS-Protection`
- `Referrer-Policy` y `Permissions-Policy` (deshabilita cámara, micrófono, geolocalización)
- Sin exposición de versión del servidor (`-Server`)
- Rate limiting configurable

### Capa 5 — Docker Networks
- Red `internal` (`internal: true`): PostgreSQL, Redis, Qdrant, Ollama — **sin acceso a internet**
- Red `public`: Caddy, cloudflared, n8n — acceso a internet para APIs externas
- Si PostgreSQL se compromete, **no puede exfiltrar datos** (sin salida a internet)
- Aislamiento total entre contenedores

### Capa 6 — n8n Hardening
| Variable | Efecto |
|----------|--------|
| `N8N_BLOCK_ENV_ACCESS_IN_NODE=true` | Nodos Code no pueden leer variables de entorno |
| `NODES_EXCLUDE` | Bloquea executeCommand, readWriteFile, localFileTrigger |
| `N8N_RESTRICT_FILE_ACCESS_TO=/files` | Acceso a filesystem solo en `/files` |
| `N8N_SECURE_COOKIE=true` | Cookies con flag Secure |
| `EXECUTIONS_DATA_PRUNE=true` | DB no crece indefinidamente |

### Capa 7 — Secretos
- Passwords en archivos `./secrets/*.txt` con `chmod 600`
- NUNCA en `.env` (que podría commitearse)
- `.gitignore` excluye `secrets/` y `.env`
- `N8N_ENCRYPTION_KEY` protege todas las credenciales cifradas en PostgreSQL

### Capa 8 — IA
- Workflows creados por IA siempre como `active: false`
- IA no puede activar workflows ni crear credenciales
- Nodos peligrosos bloqueados en el system prompt del arquitecto
- Ollama corre en red `internal` — modelos y datos nunca salen de tu máquina

---

## Checklist post-instalación (Cloudflare Dashboard)

```
Cloudflare Dashboard — tu dominio:
  [ ] SSL/TLS → Overview → Mode: Full (strict)
  [ ] Security → WAF → Managed Rules → Enable
  [ ] Security → Bots → Bot Fight Mode → Enable
  [ ] Security → Settings → Challenge Passage: 30 min

Zero Trust Dashboard:
  [ ] Access → Applications → n8n.marlonai.net.pe configurado
  [ ] hooks.marlonai.net.pe SIN Access policy
  [ ] MFA obligatorio en Settings → Authentication

n8n (después del primer login):
  [ ] MFA activado en Settings → Security
  [ ] API Key creada y guardada en secrets/n8n_api_key.txt
```

---

## Firewall del VPS

Si migrás a un VPS, configurar UFW **antes** de cualquier otra cosa:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
# NO abrir 80 ni 443 si usás Cloudflare Tunnel
sudo ufw enable
sudo ufw status verbose
```

> ⚠️ Si usás Caddy con SSL directo (sin Tunnel), también agregar:
> `sudo ufw allow 80` y `sudo ufw allow 443`

---

## Rotación de passwords (cada 90 días)

```bash
# 1. Detener n8n (no la DB)
docker compose -f compose.yml stop n8n

# 2. Generar nueva password
NEW_PASS=$(openssl rand -base64 48 | tr -d '\n')
echo "$NEW_PASS" > secrets/postgres_password.txt

# 3. Actualizar en PostgreSQL
docker compose -f compose.yml exec postgres psql \
  -U n8n_user -c "ALTER USER n8n_user PASSWORD '${NEW_PASS}';"

# 4. Reiniciar n8n
docker compose -f compose.yml -f compose.local.yml up -d n8n
```

Para rotar `n8n_encryption_key.txt` **no es posible** sin re-cifrar todas las credenciales — ver sección siguiente.

---

## Qué hacer si perdés n8n_encryption_key.txt

Si perdés la encryption key, todas las credenciales guardadas en n8n quedan **inutilizables** (no borradas, solo indescifrables).

**Opciones:**

1. **Restaurar desde backup** — la key estaba incluida en `secrets.tar.gz` del backup.
   ```bash
   make restore
   ```

2. **Reconfigurar credenciales manualmente** — si no tenés backup:
   - Generar nueva key: `openssl rand -base64 48 > secrets/n8n_encryption_key.txt`
   - Reiniciar n8n
   - Reconfigurar todas las credenciales en n8n (Gmail, Telegram, etc.) desde cero

> 🔑 **Regla de oro**: guardá una copia de `secrets/n8n_encryption_key.txt` en un password manager (Bitwarden, 1Password). Es el secreto más crítico del proyecto.
