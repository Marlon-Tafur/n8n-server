# Setup de IA — Ollama + Claude + GPT

## Activar IA local (Ollama)

```bash
make up-ai
```

Esto levanta Ollama y Qdrant en la red `internal` (sin acceso a internet).

### Descargar modelos

```bash
# General — buena calidad, 8B parámetros, ~5GB
docker exec -it n8n-ollama ollama pull llama3.1:8b

# Código — optimizado para generar código y JSON
docker exec -it n8n-ollama ollama pull qwen2.5-coder:7b

# Alternativa ligera — más rápido, menor calidad
docker exec -it n8n-ollama ollama pull mistral:7b

# Ver modelos instalados
docker exec -it n8n-ollama ollama list
```

### Recursos necesarios por modelo

| Modelo | RAM requerida | Velocidad | Calidad |
|--------|--------------|-----------|---------|
| `llama3.1:8b` | ~8 GB | Media | Alta |
| `qwen2.5-coder:7b` | ~6 GB | Media | Alta (código) |
| `mistral:7b` | ~6 GB | Rápida | Media |
| `llama3.2:3b` | ~3 GB | Muy rápida | Básica |

---

## Configurar el AI Workflow Creator

### Paso 1 — Importar el workflow

En n8n: **Settings → Import** → subir `ai-workflows/workflow-creator.json`

### Paso 2 — Configurar la API Key de n8n

En el workflow importado, editar el nodo **"Create in n8n"**:
- Header `X-N8N-API-KEY`: reemplazar `CONFIGURAR_CON_API_KEY_DE_N8N` con el valor de `secrets/n8n_api_key.txt`

### Paso 3 — Si usás Claude (opcional)

Editar el nodo **"Call Claude"**:
- Header `x-api-key`: reemplazar `ANTHROPIC_API_KEY_CONFIGURAR` con tu API key de Anthropic

### Paso 4 — Activar el workflow

En el editor de n8n, activar el toggle del workflow "🤖 AI Workflow Creator".

---

## Usar el Workflow Creator

### Con Ollama (gratis, local, privado)

```bash
curl -X POST https://hooks.marlonai.net.pe/webhook/create-workflow \
  -H "Content-Type: application/json" \
  -d '{
    "model": "ollama",
    "description": "Crea un workflow con webhook que reciba nombre y email, valide que no estén vacíos, y responda con un JSON de confirmación"
  }'
```

### Con Claude (pago, mayor calidad)

```bash
curl -X POST https://hooks.marlonai.net.pe/webhook/create-workflow \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude",
    "description": "Un workflow que cada mañana a las 8am revise Gmail, filtre correos con asunto que contenga factura, extraiga los adjuntos PDF, y envíe un resumen por Telegram"
  }'
```

### Respuesta exitosa

```json
{
  "success": true,
  "workflow_id": "abc123",
  "name": "Webhook + Validación",
  "active": false,
  "message": "Workflow creado como INACTIVO. Revisalo y activalo manualmente en el editor."
}
```

El workflow siempre se crea **inactivo** — revisarlo en el editor antes de activar.

---

## Ollama vs Claude vs GPT — Cuándo usar cada uno

| Criterio | Ollama (local) | Claude Sonnet | GPT-4o |
|----------|---------------|---------------|--------|
| Costo | Gratis | ~$3/1M tokens | ~$5/1M tokens |
| Privacidad | Total (local) | Anthropic procesa | OpenAI procesa |
| Calidad workflows | Buena | Excelente | Muy buena |
| Velocidad | Media (CPU) | Rápida (API) | Rápida (API) |
| Sin internet | ✅ | ❌ | ❌ |
| Recomendado para | Datos sensibles, desarrollo, pruebas | Workflows complejos, producción | Alternativa a Claude |

**Regla práctica**: empezar con Ollama. Si la calidad no alcanza para lo que necesitás, cambiar a Claude para ese workflow específico.
