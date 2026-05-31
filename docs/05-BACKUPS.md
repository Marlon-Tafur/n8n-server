# Backups — Estrategia y Procedimientos

## Qué se respalda

| Componente | Qué contiene | Archivo en backup |
|------------|-------------|-------------------|
| PostgreSQL | Workflows, credenciales cifradas, ejecuciones | `database.dump` |
| `secrets/` | Encryption key, passwords, API key | `secrets.tar.gz` |
| `files/` | Archivos binarios procesados por workflows | `files.tar.gz` |
| Config | Compose files, Caddyfile, `.env` | `config.tar.gz` |
| Checksums | SHA256 de todos los archivos | `checksums.sha256` |

> 🔑 El archivo más crítico es `secrets/n8n_encryption_key.txt` — sin él las credenciales son irrecuperables.

---

## Hacer un backup

```bash
make backup
# o directamente:
bash scripts/backup.sh
```

El backup se guarda en `backups/n8n_backup_YYYYMMDD_HHMMSS.tar.gz`.

---

## Restaurar desde backup

```bash
# Restaurar el más reciente:
make restore

# Restaurar un backup específico:
bash scripts/restore.sh backups/n8n_backup_20250520_143000.tar.gz
```

El script:
1. Pide confirmación antes de tocar nada
2. Verifica checksums SHA256 (aborta si hay corrupción)
3. Detiene n8n (no la DB)
4. Restaura secrets, files y PostgreSQL
5. Reinicia los servicios

---

## Frecuencia recomendada

| Entorno | Frecuencia | Cómo |
|---------|-----------|------|
| **Laptop** (desarrollo) | Semanal o antes de cambios importantes | `make backup` manual |
| **VPS** (producción) | Diario a las 3am | Cron job (ver abajo) |

---

## Configurar cron en VPS

```bash
crontab -e

# Agregar esta línea:
0 3 * * * cd /opt/n8n-server && bash scripts/backup.sh >> /var/log/n8n-backup.log 2>&1
```

Para verificar que el cron corre:
```bash
grep n8n-backup /var/log/syslog | tail -5
```

---

## Verificar un backup (la regla de oro)

> **"Un backup no probado no es un backup."**

Cada vez que hagas un cambio importante (migración, actualización de n8n, cambio de credenciales), verificá que el backup funciona:

```bash
# 1. Hacer backup
make backup

# 2. En un entorno limpio (otra VM, otro directorio):
mkdir /tmp/n8n-test && cd /tmp/n8n-test
# Copiar el backup
bash scripts/restore.sh /ruta/al/backup.tar.gz

# 3. Verificar que n8n arranca y los workflows están intactos
make health
```

---

## Retención de backups

Por defecto se conservan **30 días** de backups. Configurar en `.env`:

```env
BACKUP_RETENTION_DAYS=30
```

Los backups más viejos se eliminan automáticamente al hacer un nuevo backup.

---

## Copiar backups a un lugar externo

El backup local protege contra corrupción de datos pero no contra fallo del disco. Copiar periódicamente a un lugar externo:

```bash
# A Google Drive (con rclone):
rclone copy backups/ gdrive:n8n-backups/

# A otro servidor:
scp backups/n8n_backup_*.tar.gz usuario@otro-servidor:/backups/
```
