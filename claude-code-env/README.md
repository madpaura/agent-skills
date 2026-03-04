# 🤖 Claude Code Development Environment

A Docker-based development environment featuring **Claude Code CLI**, **VS Code** (via code-server), and the **Claude extension** — all accessible through your browser.

## ✨ What's Included

| Component | Description |
|-----------|-------------|
| **code-server** | VS Code in the browser (v4.109.2) |
| **Claude Code CLI** | `@anthropic-ai/claude-code` via npm |
| **Claude Extension** | `anthropic.claude-code` for VS Code |
| **Node.js 22** | LTS with npm |
| **Python 3** | With pip and venv |
| **Git + Git LFS** | Version control |
| **Docker CLI** | For Docker-in-Docker workflows |
| **Dev Tools** | build-essential, cmake, curl, jq, tmux, htop, etc. |

### Pre-installed VS Code Extensions
- 🧠 Claude Code (`anthropic.claude-code`)
- 🐍 Python (`ms-python.python`)
- 🎨 Prettier (`esbenp.prettier-vscode`)
- 🔍 ESLint (`dbaeumer.vscode-eslint`)
- 📊 GitLens (`eamodio.gitlens`)
- 📁 Material Icon Theme (`pkief.material-icon-theme`)

---

## 🚀 Quick Start

### 1. Setup
```bash
cd claude-code-env

# Create .env from template
cp .env.example .env

# Edit .env — set your ANTHROPIC_API_KEY
nano .env
```

### 2. Build & Run
```bash
# Using Make (recommended)
make build
make run

# Or using Docker Compose directly
docker compose build
docker compose up -d
```

### 3. Access
- **VS Code**: Open [http://localhost:8080](http://localhost:8080) in your browser
- **Password**: `claude-dev` (or whatever you set in `.env`)
- **Claude CLI**: Open a terminal in VS Code and run `claude`

---

## ⚙️ Configuration

### Environment Variables (`.env`)

| Variable | Default | Description |
|----------|---------|-------------|
| `ANTHROPIC_API_KEY` | *(required)* | Your Anthropic API key for Claude |
| `CODE_SERVER_PASSWORD` | `claude-dev` | Password for VS Code web UI |
| `CODE_SERVER_AUTH` | `password` | Set to `none` to disable auth |
| `GIT_USER_NAME` | *(optional)* | Git commit author name |
| `GIT_USER_EMAIL` | *(optional)* | Git commit author email |
| `WORKSPACE_PATH` | `./workspace` | Host path to mount as workspace |
| `TZ` | `Asia/Kolkata` | Timezone |

### Volume Mounts

The `docker-compose.yml` includes several volume mounts. Uncomment as needed:

| Mount | Purpose |
|-------|---------|
| `WORKSPACE_PATH → /home/developer/workspace` | Your project files |
| `~/.gitconfig` | Reuse host git configuration |
| `~/.ssh` | SSH keys for git (uncomment in compose) |
| `/var/run/docker.sock` | Docker-in-Docker (uncomment in compose) |

### Network Access

By default, `network_mode: host` is used for **full network access**. This means:
- All container ports are directly available on the host
- The container can access all host network services
- No port mapping needed

To switch to isolated networking, edit `docker-compose.yml`:
```yaml
# Comment out this line:
# network_mode: host

# Uncomment the ports section:
ports:
  - "8080:8080"
  - "3000:3000"
  # ... etc
```

---

## 📋 Common Commands

```bash
make help       # Show all available commands
make setup      # Initial setup (create .env, workspace dir)
make build      # Build the Docker image
make run        # Start the environment
make stop       # Stop the environment
make restart    # Restart the environment
make logs       # View container logs
make shell      # Open bash inside the container
make claude     # Launch Claude Code CLI inside the container
make status     # Check container status
make clean      # Remove everything (container, image, volumes)
make rebuild    # Full clean rebuild
```

### Direct Docker Commands
```bash
# Build
docker compose build

# Start
docker compose up -d

# Stop
docker compose down

# Shell access
docker exec -it claude-code-env bash

# Run Claude CLI
docker exec -it claude-code-env claude

# View logs
docker compose logs -f
```

---

## 🔧 Advanced Usage

### Docker-in-Docker

To use Docker inside the container, mount the Docker socket:

1. Uncomment in `docker-compose.yml`:
   ```yaml
   - /var/run/docker.sock:/var/run/docker.sock
   ```

2. Rebuild and restart:
   ```bash
   make rebuild
   ```

### SSH Key Access

To use SSH keys for Git (e.g., GitHub, Bitbucket):

1. Uncomment in `docker-compose.yml`:
   ```yaml
   - ${HOME}/.ssh:/home/developer/.ssh:ro
   ```

2. Restart:
   ```bash
   make restart
   ```

### Custom Extensions

Add more VS Code extensions by editing the Dockerfile:
```dockerfile
RUN code-server --install-extension <publisher>.<extension-name>
```

### Persistent Data

Named volumes ensure your data persists across container restarts:
- `claude-code-extensions` — VS Code extensions & settings
- `claude-code-config` — Claude Code CLI configuration
- `claude-code-npm-cache` — npm package cache
- `claude-code-bash-history` — Shell history

To reset everything: `make clean`

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│              Docker Host                │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │      claude-code-env container   │   │
│  │                                  │   │
│  │  ┌────────────────────────────┐  │   │
│  │  │  code-server (:8080)       │  │   │
│  │  │  └─ Claude Extension       │  │   │
│  │  │  └─ Python, ESLint, etc.   │  │   │
│  │  └────────────────────────────┘  │   │
│  │                                  │   │
│  │  ┌────────────────────────────┐  │   │
│  │  │  Claude Code CLI           │  │   │
│  │  │  (via terminal / ssh)      │  │   │
│  │  └────────────────────────────┘  │   │
│  │                                  │   │
│  │  /home/developer/workspace ◄─────┼───┼── Host volume
│  └──────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
```

---

## 🐛 Troubleshooting

### Claude extension not showing up
The Claude extension may require the Microsoft VS Code marketplace. If `code-server` defaults to Open-VSX:
```bash
# Inside the container, manually install
code-server --install-extension anthropic.claude-code
```

### Permission denied on workspace files
Ensure the host directory has matching UID/GID (default: 1000):
```bash
sudo chown -R 1000:1000 ./workspace
```

### Container runs out of memory
Increase the memory limit in `docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      memory: 16G
```

---

## 📄 License

MIT
