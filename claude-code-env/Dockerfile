# ============================================================================
# Claude Code Development Environment
# ============================================================================
# Provides:
#   - code-server (VS Code in the browser)
#   - Claude Code CLI (@anthropic-ai/claude-code)
#   - Claude extension for VS Code (anthropic.claude-code)
#   - Full network access
#   - Volume mounting support
#   - Common development tools (git, curl, build-essential, python3, etc.)
# ============================================================================

FROM ubuntu:24.04

LABEL maintainer="vishwa"
LABEL description="Claude Code Development Environment with VS Code (code-server)"
LABEL version="1.0"

# ---- Build Arguments ----
ARG CODE_SERVER_VERSION=4.109.2
ARG NODE_MAJOR=22
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=1000

# ---- Environment Variables ----
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV SHELL=/bin/bash
ENV HOME=/home/${USERNAME}
ENV EDITOR=code
ENV VISUAL=code

# ---- Install System Dependencies ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core utilities
    ca-certificates \
    curl \
    wget \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    # Build tools
    build-essential \
    cmake \
    pkg-config \
    # Version control
    git \
    git-lfs \
    # Editors & utilities
    vim \
    nano \
    less \
    jq \
    tree \
    htop \
    tmux \
    unzip \
    zip \
    # Networking tools
    net-tools \
    iputils-ping \
    dnsutils \
    openssh-client \
    # Python
    python3 \
    python3-pip \
    python3-venv \
    # Process management
    sudo \
    locales \
    # Required for code-server
    dumb-init \
    && rm -rf /var/lib/apt/lists/*

# ---- Install Node.js (v22 LTS) ----
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g npm@latest

# ---- Install Docker CLI (for Docker-in-Docker or Docker socket mounting) ----
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
       https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# ---- Create non-root user ----
# Ubuntu 24.04 ships with 'ubuntu' user at UID/GID 1000; remove it first
RUN (userdel -r ubuntu 2>/dev/null; true) \
    && (groupadd --gid ${USER_GID} ${USERNAME} 2>/dev/null; true) \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

# ---- Install code-server ----
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --version=${CODE_SERVER_VERSION} \
    && mkdir -p /home/${USERNAME}/.local/share/code-server \
    && mkdir -p /home/${USERNAME}/.config/code-server

# ---- Install Claude Code CLI ----
RUN npm install -g @anthropic-ai/claude-code

# ---- Fix home directory ownership before switching user ----
RUN chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

# ---- Switch to non-root user for extension installs and config ----
USER ${USERNAME}
WORKDIR /home/${USERNAME}

# ---- Configure code-server to use Microsoft marketplace ----
# This allows installing the official Claude extension
RUN mkdir -p /home/${USERNAME}/.config/code-server \
    && cat > /home/${USERNAME}/.config/code-server/config.yaml <<'EOF'
bind-addr: 0.0.0.0:8080
auth: password
password: claude-dev
cert: false
EOF

# ---- Install VS Code extensions ----
# Claude extension
RUN code-server --install-extension anthropic.claude-code || true

# Other useful extensions
RUN code-server --install-extension ms-python.python || true \
    && code-server --install-extension esbenp.prettier-vscode || true \
    && code-server --install-extension dbaeumer.vscode-eslint || true \
    && code-server --install-extension eamodio.gitlens || true \
    && code-server --install-extension pkief.material-icon-theme || true

# ---- Configure VS Code settings ----
RUN mkdir -p /home/${USERNAME}/.local/share/code-server/User \
    && cat > /home/${USERNAME}/.local/share/code-server/User/settings.json <<'EOF'
{
    "workbench.colorTheme": "Default Dark Modern",
    "workbench.iconTheme": "material-icon-theme",
    "editor.fontSize": 14,
    "editor.fontFamily": "'Fira Code', 'Cascadia Code', 'Droid Sans Mono', monospace",
    "editor.fontLigatures": true,
    "editor.tabSize": 2,
    "editor.formatOnSave": true,
    "editor.minimap.enabled": true,
    "editor.wordWrap": "on",
    "editor.bracketPairColorization.enabled": true,
    "editor.guides.bracketPairs": true,
    "terminal.integrated.defaultProfile.linux": "bash",
    "terminal.integrated.fontSize": 13,
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000,
    "git.autofetch": true,
    "git.enableSmartCommit": true,
    "explorer.confirmDelete": false,
    "explorer.confirmDragAndDrop": false
}
EOF

# ---- Create workspace directory ----
RUN mkdir -p /home/${USERNAME}/workspace

# ---- Fix ownership (switch back to root briefly) ----
USER root
RUN chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

# ---- Copy entrypoint ----
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ---- Switch to non-root user ----
USER ${USERNAME}
WORKDIR /home/${USERNAME}/workspace

# ---- Expose ports ----
# 8080: code-server (VS Code web UI)
# 3000-3999: Common dev server ports
EXPOSE 8080 3000 3001 5173 8000 8443

# ---- Health check ----
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/healthz || exit 1

# ---- Entrypoint ----
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]
