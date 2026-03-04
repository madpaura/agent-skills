#!/bin/bash
set -e

# ============================================================================
# Claude Code Environment - Entrypoint Script
# ============================================================================

echo "============================================"
echo "  Claude Code Development Environment"
echo "============================================"
echo ""

# ---- Anthropic API Key ----
if [ -n "${ANTHROPIC_API_KEY}" ]; then
    echo "✓ ANTHROPIC_API_KEY is set"
    export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY}"
else
    echo "⚠ ANTHROPIC_API_KEY is not set."
    echo "  Set it via: docker run -e ANTHROPIC_API_KEY=sk-ant-... "
    echo "  Claude Code CLI will not work without it."
fi

# ---- Git Configuration (if provided) ----
# Only write git config if .gitconfig is writable (not read-only bind mount)
if [ -n "${GIT_USER_NAME}" ]; then
    if git config --global user.name "${GIT_USER_NAME}" 2>/dev/null; then
        echo "✓ Git user.name set to: ${GIT_USER_NAME}"
    else
        echo "ℹ Git user.name skipped (.gitconfig is read-only from host)"
    fi
fi

if [ -n "${GIT_USER_EMAIL}" ]; then
    if git config --global user.email "${GIT_USER_EMAIL}" 2>/dev/null; then
        echo "✓ Git user.email set to: ${GIT_USER_EMAIL}"
    else
        echo "ℹ Git user.email skipped (.gitconfig is read-only from host)"
    fi
fi

# ---- Password Configuration ----
AUTH_MODE="password"
if [ "${CODE_SERVER_AUTH}" = "none" ]; then
    AUTH_MODE="none"
    echo "✓ code-server authentication disabled"
else
    # code-server reads $PASSWORD env var directly
    export PASSWORD="${CODE_SERVER_PASSWORD:-claude-dev}"
    echo "✓ code-server password configured"
fi

# ---- Docker Socket Permissions ----
if [ -S /var/run/docker.sock ]; then
    DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
    if ! getent group docker > /dev/null 2>&1; then
        sudo groupadd -g "${DOCKER_GID}" docker 2>/dev/null || true
    fi
    sudo usermod -aG docker developer 2>/dev/null || true
    echo "✓ Docker socket detected and permissions configured"
fi

# ---- SSH Key Permissions ----
if [ -d "/home/developer/.ssh" ]; then
    chmod 700 /home/developer/.ssh
    chmod 600 /home/developer/.ssh/* 2>/dev/null || true
    chmod 644 /home/developer/.ssh/*.pub 2>/dev/null || true
    echo "✓ SSH directory permissions configured"
fi

# ---- System Info ----
echo ""
echo "Environment Details:"
echo "  Node.js:       $(node --version)"
echo "  npm:           $(npm --version)"
echo "  Claude Code:   $(claude --version 2>/dev/null || echo 'not available')"
echo "  code-server:   $(code-server --version 2>/dev/null | head -1)"
echo "  Python:        $(python3 --version)"
echo "  Git:           $(git --version)"
echo ""
echo "Access VS Code at: http://localhost:8080"
if [ "${AUTH_MODE}" = "none" ]; then
    echo "Authentication:  disabled"
else
    echo "Password:        (set via CODE_SERVER_PASSWORD env)"
fi
echo ""
echo "============================================"
echo ""

# ---- Start code-server ----
exec code-server \
    --bind-addr 0.0.0.0:8080 \
    --auth "${AUTH_MODE}" \
    --disable-telemetry \
    /home/developer/workspace
