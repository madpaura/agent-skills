# ============================================================================
# Claude Code Environment - Makefile
# ============================================================================

.PHONY: build run stop restart logs shell clean help setup save load status claude

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
	./run.sh build

run: setup ## Start the environment (detached)
	./run.sh start

stop: ## Stop the environment
	./run.sh stop

restart: ## Restart the environment
	./run.sh restart

logs: ## View container logs
	./run.sh logs

shell: ## Open a bash shell in the container
	./run.sh shell

claude: ## Open Claude Code CLI in the container
	./run.sh claude

status: ## Check container status
	./run.sh status

save: ## Save Docker image to file
	./save-image.sh save

load: ## Load Docker image from file (usage: make load FILE=image.tar.gz)
	./save-image.sh load $(FILE)

clean: ## Remove container, volumes, and data
	./run.sh clean

rebuild: clean build run ## Full rebuild from scratch
