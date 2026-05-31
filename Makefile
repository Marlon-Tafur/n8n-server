# ============================================================
# n8n Server — Comandos del Día a Día
# ============================================================

.PHONY: help setup up down restart logs logs-n8n status backup restore
.PHONY: up-ai up-queue up-full up-vps update security-check health shell-n8n shell-db

# Archivos compose base
LOCAL  := -f compose.yml -f compose.local.yml
VPS    := -f compose.yml -f compose.vps.yml
AI     := -f compose.ai.yml --profile ai
QUEUE  := -f compose.queue.yml --profile queue

help: ## Muestra esta ayuda
	@echo "n8n Server — Comandos disponibles:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

setup: ## Configuración inicial (ejecutar 1 vez)
	@cp -n .env.example .env 2>/dev/null || true
	@chmod +x scripts/*.sh
	@./scripts/init-secrets.sh
	@echo ""
	@echo "Siguiente paso: edita .env con tus dominios reales"

up: ## Levanta n8n (modo laptop)
	docker compose $(LOCAL) up -d
	@$(MAKE) status

up-ai: ## Levanta n8n + IA local (Ollama + Qdrant)
	docker compose $(LOCAL) $(AI) up -d
	@echo ""
	@echo "Descarga un modelo: docker exec -it n8n-ollama ollama pull llama3.1:8b"

up-queue: ## Levanta n8n + Redis + Worker
	docker compose $(LOCAL) $(QUEUE) up -d

up-full: ## Levanta todo (n8n + IA + Queue)
	docker compose $(LOCAL) $(AI) $(QUEUE) up -d

up-vps: ## Levanta n8n en modo VPS
	docker compose $(VPS) up -d

down: ## Detiene todos los servicios
	docker compose $(LOCAL) $(AI) $(QUEUE) down 2>/dev/null || true

restart: ## Reinicia n8n
	docker compose $(LOCAL) restart n8n

logs: ## Logs en tiempo real (todos los servicios)
	docker compose $(LOCAL) logs -f --tail=100

logs-n8n: ## Logs solo de n8n
	docker compose $(LOCAL) logs -f --tail=100 n8n

status: ## Estado de los servicios
	@docker compose $(LOCAL) ps 2>/dev/null || docker compose $(VPS) ps

backup: ## Backup manual
	@bash scripts/backup.sh

restore: ## Restaurar desde backup
	@bash scripts/restore.sh

update: ## Actualiza n8n a última versión
	docker compose $(LOCAL) pull n8n
	docker compose $(LOCAL) up -d n8n
	@echo "n8n actualizado"

security-check: ## Auditoría de seguridad
	@bash scripts/security-check.sh

health: ## Health check de todos los servicios
	@bash scripts/health-check.sh

shell-n8n: ## Shell dentro de n8n
	docker compose $(LOCAL) exec n8n /bin/sh

shell-db: ## Shell de PostgreSQL
	docker compose $(LOCAL) exec postgres psql -U $${POSTGRES_USER:-n8n_user} -d $${POSTGRES_DB:-n8n}
