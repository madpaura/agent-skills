# ============================================================================
# Claude Code Environment - Makefile
# ============================================================================

.PHONY: build run stop restart logs shell clean help setup

IMAGE_NAME := claude-code-env
CONTAINER_NAME := claude-code-env

help: ## Show this help message
	@echo "Claude Code Environment - Available Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""

setup: ## Initial setup: create .env and workspace directory
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "✓ Created .env from .env.example"; \
		echo "  → Edit .env and set your ANTHROPIC_API_KEY"; \
	else \
		echo "✓ .env already exists"; \
	fi
	@mkdir -p workspace
	@echo "✓ Workspace directory ready"

build: ## Build the Docker image
	docker compose build

run: setup ## Start the environment (detached)
	docker compose up -d
	@echo ""
	@echo "✓ Claude Code Environment is starting..."
	@echo "  → VS Code:     http://localhost:8080"
	@echo "  → Password:    Check your .env file"
	@echo ""

stop: ## Stop the environment
	docker compose down

restart: ## Restart the environment
	docker compose restart

logs: ## View container logs
	docker compose logs -f

shell: ## Open a bash shell in the container
	docker exec -it $(CONTAINER_NAME) bash

claude: ## Open Claude Code CLI in the container
	docker exec -it $(CONTAINER_NAME) claude

status: ## Check container status
	@docker ps --filter name=$(CONTAINER_NAME) --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

clean: ## Remove container, image, and volumes
	docker compose down -v --rmi local
	@echo "✓ Cleaned up all resources"

rebuild: clean build run ## Full rebuild from scratch
