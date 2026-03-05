#!/bin/bash
# ============================================================================
# Claude Code Environment - Container Runner (no docker-compose required)
# ============================================================================
# Usage:
#   ./run.sh start     Start the container (detached)
#   ./run.sh stop      Stop the container
#   ./run.sh restart   Restart the container
#   ./run.sh status    Show container status
#   ./run.sh logs      Follow container logs
#   ./run.sh shell     Open bash in the container
#   ./run.sh claude    Open Claude Code CLI in the container
#   ./run.sh build     Build the image
#   ./run.sh clean     Stop & remove container + volumes
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---- Configuration (load from .env if available) ----
if [ -f "${SCRIPT_DIR}/.env" ]; then
    set -a
    source "${SCRIPT_DIR}/.env"
    set +a
fi

# Defaults
IMAGE_NAME="${IMAGE_NAME:-claude-code-env}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
IMAGE_FULL="${IMAGE_NAME}:${IMAGE_TAG}"
CONTAINER_NAME="${CONTAINER_NAME:-claude-code-env}"
HOSTNAME_OVERRIDE="${HOSTNAME_OVERRIDE:-claude-dev}"

ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
CODE_SERVER_PASSWORD="${CODE_SERVER_PASSWORD:-claude-dev}"
CODE_SERVER_AUTH="${CODE_SERVER_AUTH:-password}"
GIT_USER_NAME="${GIT_USER_NAME:-}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-}"
WORKSPACE_PATH="${WORKSPACE_PATH:-${SCRIPT_DIR}/workspace}"
TZ="${TZ:-Asia/Kolkata}"

# Network mode: "host" for full access, "bridge" for port mapping
NETWORK_MODE="${NETWORK_MODE:-host}"
VSCODE_PORT="${VSCODE_PORT:-8080}"

# Resource limits
MEMORY_LIMIT="${MEMORY_LIMIT:-8g}"
CPU_LIMIT="${CPU_LIMIT:-4.0}"

# Optional mounts (set to "true" to enable)
MOUNT_DOCKER_SOCKET="${MOUNT_DOCKER_SOCKET:-false}"
MOUNT_SSH_KEYS="${MOUNT_SSH_KEYS:-false}"
MOUNT_GITCONFIG="${MOUNT_GITCONFIG:-true}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  Claude Code Environment${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
}

print_usage() {
    print_header
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo -e "  ${GREEN}start${NC}      Start the container (detached)"
    echo -e "  ${GREEN}stop${NC}       Stop and remove the container"
    echo -e "  ${GREEN}restart${NC}    Restart the container"
    echo -e "  ${GREEN}status${NC}     Show container status"
    echo -e "  ${GREEN}logs${NC}       Follow container logs"
    echo -e "  ${GREEN}shell${NC}      Open bash shell in the container"
    echo -e "  ${GREEN}claude${NC}     Open Claude Code CLI in the container"
    echo -e "  ${GREEN}build${NC}      Build the Docker image"
    echo -e "  ${GREEN}clean${NC}      Stop container & remove named volumes"
    echo ""
    echo "Configuration:"
    echo -e "  Edit ${YELLOW}.env${NC} to configure (copy from .env.example if needed)"
    echo ""
    echo "Environment overrides:"
    echo -e "  ${DIM}NETWORK_MODE=bridge ./run.sh start   # Use port mapping instead of host network${NC}"
    echo -e "  ${DIM}VSCODE_PORT=9090 ./run.sh start      # Change VS Code port (bridge mode)${NC}"
    echo -e "  ${DIM}MOUNT_DOCKER_SOCKET=true ./run.sh start  # Enable Docker-in-Docker${NC}"
    echo -e "  ${DIM}MOUNT_SSH_KEYS=true ./run.sh start        # Mount SSH keys${NC}"
    echo ""
}

is_running() {
    docker ps -q --filter "name=^${CONTAINER_NAME}$" 2>/dev/null | grep -q .
}

container_exists() {
    docker ps -aq --filter "name=^${CONTAINER_NAME}$" 2>/dev/null | grep -q .
}

# ---- BUILD ----
cmd_build() {
    print_header
    echo -e "${CYAN}Building image:${NC} ${IMAGE_FULL}"
    echo ""
    docker build -t "${IMAGE_FULL}" "${SCRIPT_DIR}"
    echo ""
    echo -e "${GREEN}✓ Image built successfully${NC}"
}

# ---- START ----
cmd_start() {
    print_header

    # Check if already running
    if is_running; then
        echo -e "${YELLOW}Container '${CONTAINER_NAME}' is already running.${NC}"
        echo "  Use: $0 restart"
        exit 0
    fi

    # Remove stopped container if exists
    if container_exists; then
        echo "Removing stopped container..."
        docker rm "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    fi

    # Check image exists
    if ! docker image inspect "${IMAGE_FULL}" &>/dev/null; then
        echo -e "${YELLOW}Image '${IMAGE_FULL}' not found. Building...${NC}"
        echo ""
        cmd_build
        echo ""
    fi

    # Create workspace directory if it doesn't exist
    mkdir -p "${WORKSPACE_PATH}"

    echo -e "${CYAN}Starting container:${NC} ${CONTAINER_NAME}"
    echo ""

    # ---- Build docker run command ----
    local DOCKER_CMD=(
        docker run -d
        --name "${CONTAINER_NAME}"
        --hostname "${HOSTNAME_OVERRIDE}"
        --restart unless-stopped
        --security-opt seccomp=unconfined
        --cap-add SYS_PTRACE
        --memory "${MEMORY_LIMIT}"
        --cpus "${CPU_LIMIT}"
        --interactive --tty
    )

    # Network
    if [ "${NETWORK_MODE}" = "host" ]; then
        DOCKER_CMD+=(--network host)
    else
        DOCKER_CMD+=(
            -p "${VSCODE_PORT}:8080"
            -p 3000:3000
            -p 3001:3001
            -p 5173:5173
            -p 8000:8000
            -p 8443:8443
        )
    fi

    # Environment variables
    DOCKER_CMD+=(
        -e "TZ=${TZ}"
        -e "CODE_SERVER_PASSWORD=${CODE_SERVER_PASSWORD}"
        -e "CODE_SERVER_AUTH=${CODE_SERVER_AUTH}"
    )

    [ -n "${ANTHROPIC_API_KEY}" ] && DOCKER_CMD+=(-e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}")
    [ -n "${GIT_USER_NAME}" ]     && DOCKER_CMD+=(-e "GIT_USER_NAME=${GIT_USER_NAME}")
    [ -n "${GIT_USER_EMAIL}" ]    && DOCKER_CMD+=(-e "GIT_USER_EMAIL=${GIT_USER_EMAIL}")

    # Volume mounts — workspace
    DOCKER_CMD+=(-v "${WORKSPACE_PATH}:/home/developer/workspace")

    # Named volumes for persistence
    DOCKER_CMD+=(
        -v "claude-code-extensions:/home/developer/.local/share/code-server"
        -v "claude-code-config:/home/developer/.claude"
        -v "claude-code-npm-cache:/home/developer/.npm"
        -v "claude-code-bash-history:/home/developer/.bash_history_dir"
    )

    # Optional: Git config
    if [ "${MOUNT_GITCONFIG}" = "true" ] && [ -f "${HOME}/.gitconfig" ]; then
        DOCKER_CMD+=(-v "${HOME}/.gitconfig:/home/developer/.gitconfig:ro")
    fi

    # Optional: SSH keys
    if [ "${MOUNT_SSH_KEYS}" = "true" ] && [ -d "${HOME}/.ssh" ]; then
        DOCKER_CMD+=(-v "${HOME}/.ssh:/home/developer/.ssh:ro")
    fi

    # Optional: Docker socket
    if [ "${MOUNT_DOCKER_SOCKET}" = "true" ] && [ -S "/var/run/docker.sock" ]; then
        DOCKER_CMD+=(-v "/var/run/docker.sock:/var/run/docker.sock")
    fi

    # Image
    DOCKER_CMD+=("${IMAGE_FULL}")

    # Run
    "${DOCKER_CMD[@]}"

    # Wait a moment for startup
    sleep 2

    # Verify running
    if is_running; then
        echo -e "${GREEN}✓ Container started successfully${NC}"
        echo ""
        echo "  Container:  ${CONTAINER_NAME}"
        echo "  Image:      ${IMAGE_FULL}"
        echo "  Network:    ${NETWORK_MODE}"
        if [ "${NETWORK_MODE}" = "host" ]; then
            echo -e "  VS Code:    ${GREEN}http://localhost:8080${NC}"
        else
            echo -e "  VS Code:    ${GREEN}http://localhost:${VSCODE_PORT}${NC}"
        fi
        echo "  Password:   ${CODE_SERVER_PASSWORD}"
        echo "  Workspace:  ${WORKSPACE_PATH}"
        echo ""
        echo "  Mounted volumes:"
        echo "    workspace          → ${WORKSPACE_PATH}"
        [ "${MOUNT_GITCONFIG}" = "true" ] && [ -f "${HOME}/.gitconfig" ] && \
            echo "    .gitconfig (ro)    → ${HOME}/.gitconfig"
        [ "${MOUNT_SSH_KEYS}" = "true" ] && [ -d "${HOME}/.ssh" ] && \
            echo "    .ssh (ro)          → ${HOME}/.ssh"
        [ "${MOUNT_DOCKER_SOCKET}" = "true" ] && [ -S "/var/run/docker.sock" ] && \
            echo "    docker.sock        → /var/run/docker.sock"
        echo ""
    else
        echo -e "${RED}✗ Container failed to start. Check logs:${NC}"
        docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
        exit 1
    fi
}

# ---- STOP ----
cmd_stop() {
    print_header
    if is_running; then
        echo "Stopping container '${CONTAINER_NAME}'..."
        docker stop "${CONTAINER_NAME}" >/dev/null 2>&1
        docker rm "${CONTAINER_NAME}" >/dev/null 2>&1 || true
        echo -e "${GREEN}✓ Container stopped and removed${NC}"
    elif container_exists; then
        docker rm "${CONTAINER_NAME}" >/dev/null 2>&1 || true
        echo -e "${GREEN}✓ Stopped container removed${NC}"
    else
        echo -e "${YELLOW}Container '${CONTAINER_NAME}' is not running.${NC}"
    fi
    echo ""
}

# ---- RESTART ----
cmd_restart() {
    cmd_stop
    cmd_start
}

# ---- STATUS ----
cmd_status() {
    print_header
    if is_running; then
        echo -e "Status: ${GREEN}RUNNING${NC}"
        echo ""
        docker ps --filter "name=^${CONTAINER_NAME}$" \
            --format "  Container:  {{.Names}}\n  Image:      {{.Image}}\n  Status:     {{.Status}}\n  Created:    {{.CreatedAt}}"
        echo ""

        # Show resource usage
        echo "Resource Usage:"
        docker stats "${CONTAINER_NAME}" --no-stream \
            --format "  CPU:     {{.CPUPerc}}\n  Memory:  {{.MemUsage}} ({{.MemPerc}})\n  Net I/O: {{.NetIO}}\n  Disk:    {{.BlockIO}}" 2>/dev/null || true
    elif container_exists; then
        echo -e "Status: ${YELLOW}STOPPED${NC}"
        docker ps -a --filter "name=^${CONTAINER_NAME}$" \
            --format "  Container:  {{.Names}}\n  Image:      {{.Image}}\n  Status:     {{.Status}}"
    else
        echo -e "Status: ${RED}NOT FOUND${NC}"
        echo "  Run: $0 start"
    fi
    echo ""
}

# ---- LOGS ----
cmd_logs() {
    if ! container_exists; then
        echo -e "${RED}Container '${CONTAINER_NAME}' not found.${NC}"
        exit 1
    fi
    docker logs -f "${CONTAINER_NAME}"
}

# ---- SHELL ----
cmd_shell() {
    if ! is_running; then
        echo -e "${RED}Container '${CONTAINER_NAME}' is not running.${NC}"
        echo "  Start with: $0 start"
        exit 1
    fi
    docker exec -it "${CONTAINER_NAME}" bash
}

# ---- CLAUDE ----
cmd_claude() {
    if ! is_running; then
        echo -e "${RED}Container '${CONTAINER_NAME}' is not running.${NC}"
        echo "  Start with: $0 start"
        exit 1
    fi
    docker exec -it "${CONTAINER_NAME}" claude
}

# ---- CLEAN ----
cmd_clean() {
    print_header
    echo -e "${YELLOW}This will remove the container AND all persistent data volumes.${NC}"
    echo ""
    read -rp "Are you sure? (y/N) " confirm
    if [[ "${confirm}" =~ ^[Yy]$ ]]; then
        # Stop & remove container
        if is_running || container_exists; then
            docker stop "${CONTAINER_NAME}" >/dev/null 2>&1 || true
            docker rm "${CONTAINER_NAME}" >/dev/null 2>&1 || true
            echo -e "${GREEN}✓ Container removed${NC}"
        fi

        # Remove named volumes
        for vol in claude-code-extensions claude-code-config claude-code-npm-cache claude-code-bash-history; do
            if docker volume inspect "${vol}" &>/dev/null; then
                docker volume rm "${vol}" >/dev/null 2>&1 || true
                echo -e "${GREEN}✓ Volume '${vol}' removed${NC}"
            fi
        done
        echo ""
        echo -e "${GREEN}✓ Cleanup complete${NC}"
    else
        echo "Cancelled."
    fi
    echo ""
}

# ---- Main ----
case "${1:-}" in
    start)    cmd_start   ;;
    stop)     cmd_stop    ;;
    restart)  cmd_restart ;;
    status)   cmd_status  ;;
    logs)     cmd_logs    ;;
    shell)    cmd_shell   ;;
    claude)   cmd_claude  ;;
    build)    cmd_build   ;;
    clean)    cmd_clean   ;;
    *)        print_usage ;;
esac
