# 07 — AI Chat Widget

## Qué es

Un chat flotante que se inyecta en el editor de n8n via Tampermonkey. Desde ahí podés
describir en lenguaje natural el workflow que necesitás y la IA lo crea directamente
en tu instancia, listo para revisar y activar. No hace falta salir del editor ni abrir
una terminal.

---

## Pre-requisitos

- **Tampermonkey** (Chrome / Edge) o **Violentmonkey** (Firefox) instalado en el navegador
- Workflow **🤖 AI Workflow Creator** importado en n8n y **activo**
- `AI_CREATOR_TOKEN` generado en `.env` y n8n reiniciado para tomarlo
- Al menos un modelo de IA disponible:
  - **Ollama local** → `make up-ai` y un modelo descargado (`ollama pull llama3.1:8b`)
  - **Claude** → API key de Anthropic configurada en el nodo "Call Claude"
  - **GPT** → API key de OpenAI configurada en el nodo "Call OpenAI"

---

## Instalación paso a paso

1. Abrir **Tampermonkey** en la barra del navegador → **Create a new script**
2. Borrar todo el template que aparece por defecto
3. Copiar el contenido completo de `ai-workflows/n8n-ai-chat-widget.user.js`
   y pegarlo en el editor
4. **File → Save** (`Ctrl+S`)
5. Navegar a `https://n8n.marlonai.net.pe` — el botón **🤖** debe aparecer
   en la esquina inferior derecha
6. Click en **🤖** → se abre el chat flotante

> El widget arranca minimizado como FAB. Podés arrastrarlo a cualquier parte
> de la pantalla; recuerda su posición entre sesiones.

---

## Configuración

Todos los parámetros están en el bloque `CONFIG` al inicio del script:

```js
const CONFIG = {
  WEBHOOK_URL:    'https://hooks.marlonai.net.pe/webhook/create-workflow',
  AI_TOKEN:       '<tu-token>',
  N8N_EDITOR_URL: 'https://n8n.marlonai.net.pe',
  MODELS: [ ... ],
};
```

| Qué cambiar | Dónde | Cómo |
|---|---|---|
| Token de autenticación | `AI_TOKEN` | Pegar el valor de `AI_CREATOR_TOKEN` de tu `.env` |
| URL del webhook | `WEBHOOK_URL` | Cambiar si movés el servidor o el path del webhook |
| Modelos del dropdown | `MODELS` | Agregar `{ id: 'gpt4o', name: '🟢 GPT-4o' }` o quitar los que no uses |
| Tecla rápida | Búscar `key === 'A'` en el listener de teclado | Cambiar `'A'` por la letra deseada |

---

## Uso

### Atajos de teclado

| Acción | Atajo |
|---|---|
| Abrir / cerrar widget | `Ctrl+Shift+A` (Windows/Linux) · `Cmd+Shift+A` (Mac) |
| Minimizar | `Escape` |
| Enviar mensaje | `Enter` |
| Nueva línea en el input | `Shift+Enter` |

### Ejemplos de prompts que funcionan bien

```
Crea un workflow con webhook que reciba un JSON con nombre y email,
valide que no estén vacíos, y responda con confirmación.
```

```
Un workflow que cada mañana a las 8am revise Gmail, filtre correos
con 'factura' en el asunto, y me envíe un resumen por Telegram.
```

```
Workflow con cron cada hora que llame a una API de clima
y guarde los datos en Google Sheets.
```

### Después de crear un workflow

Los workflows se crean siempre como **INACTIVOS**. Antes de activar:

1. Abrir el workflow en el editor (el chat muestra el link "Abrir workflow →")
2. Revisar cada nodo — la IA puede equivocarse en nombres de campos o estructuras
3. Configurar las credenciales que el workflow necesite (Gmail, Telegram, Sheets, etc.)
4. Hacer un test manual con "Test workflow"
5. Activar solo si el test pasa correctamente

---

## Troubleshooting

| Síntoma | Causa probable | Solución |
|---|---|---|
| El botón 🤖 no aparece | `@match` del script no coincide con tu dominio | Verificar que `@match` sea exactamente `https://n8n.marlonai.net.pe/*` |
| Indicador 🔴 al abrir | Servidor apagado o sin conexión | Encender la laptop / verificar Docker con `make status` |
| Error **403** | Token no coincide | Verificar que `AI_TOKEN` en el script sea igual a `AI_CREATOR_TOKEN` en `.env` |
| Error **502 / 503** | n8n está caído | Revisar `make logs-n8n`; si está apagado, `make up` |
| Workflow creado con errores internos | La IA no es perfecta | Normal. Revisar nodos, ajustar parámetros, configurar credenciales manualmente |
| El widget no recuerda su posición | `GM_getValue` bloqueado | Verificar que el script tiene los grants `GM_setValue` y `GM_getValue` activos en Tampermonkey |

---

## Seguridad

- El token vive en **dos lugares**: `.env` en el servidor y en el userscript en tu navegador
- `.env` está en `.gitignore` — **nunca se sube a Git**
- El workflow usa `$env.AI_CREATOR_TOKEN` en el nodo IF — el token no aparece si exportás el workflow como JSON
- Si cambiás de navegador o de máquina, necesitás reinstalar el userscript con el token correspondiente
- **Nunca compartas el userscript con el token incluido** — el token da acceso directo a crear workflows en tu n8n

### Rotación de token (cada 90 días)

```bash
# 1. Generar nuevo token
openssl rand -hex 32

# 2. Actualizar .env
# AI_CREATOR_TOKEN=<nuevo-token>

# 3. Reiniciar n8n para que tome el nuevo valor
docker compose -f compose.yml -f compose.local.yml -f compose.queue.yml --profile queue up -d n8n

# 4. Actualizar AI_TOKEN en el userscript de Tampermonkey y guardar
```
