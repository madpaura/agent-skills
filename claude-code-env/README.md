# 🤖 Claude Code Development Environment

A Docker-based development environment featuring **Claude Code CLI**, **VS Code** (via code-server), and the **Claude extension** — all accessible through your browser.

## ✨ What's Included

| Component            | Description                                        |
| -------------------- | -------------------------------------------------- |
| **code-server**      | VS Code in the browser (v4.109.2)                  |
| **Claude Code CLI**  | `@anthropic-ai/claude-code` via npm                |
| **Claude Extension** | `anthropic.claude-code` for VS Code                |
| **Node.js 22**       | LTS with npm                                       |
| **Python 3**         | With pip and venv                                  |
| **Git + Git LFS**    | Version control                                    |
| **Docker CLI**       | For Docker-in-Docker workflows                     |
| **Dev Tools**        | build-essential, cmake, curl, jq, tmux, htop, etc. |

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
# Using run.sh (recommended, no docker-compose needed)
./run.sh build
./run.sh start

# Or using Make
make build
make run

# Or using Docker Compose
docker-compose up -d
```

### 3. Access
- **VS Code**: Open [http://localhost:8080](http://localhost:8080) in your browser
- **Password**: `claude-dev` (or whatever you set in `.env`)
- **Claude CLI**: Open a terminal in VS Code and run `claude`

---

## 📋 Scripts

### `run.sh` — Container Runner (no docker-compose needed)

Standalone script to manage the container using plain `docker run`:

```bash
./run.sh start      # Start the container (detached)
./run.sh stop       # Stop and remove the container
./run.sh restart    # Restart the container
./run.sh status     # Show container status & resource usage
./run.sh logs       # Follow container logs
./run.sh shell      # Open bash shell in the container
./run.sh claude     # Open Claude Code CLI in the container
./run.sh build      # Build the Docker image
./run.sh clean      # Stop container & remove all volumes
```

Override options at runtime:
```bash
# Use bridge networking instead of host
NETWORK_MODE=bridge ./run.sh start

# Change VS Code port (bridge mode only)
NETWORK_MODE=bridge VSCODE_PORT=9090 ./run.sh start

# Enable Docker-in-Docker
MOUNT_DOCKER_SOCKET=true ./run.sh start

# Enable SSH key mounting
MOUNT_SSH_KEYS=true ./run.sh start
```

### `save-image.sh` — Save / Load Docker Image

Export the image to a file for transfer to another machine:

```bash
# Save image (auto-generates filename with timestamp)
./save-image.sh save

# Save to a specific file
./save-image.sh save my_backup.tar.gz

# Load image on another machine
./save-image.sh load my_backup.tar.gz

# Show image info
./save-image.sh info
./save-image.sh info my_backup.tar.gz
```

**Typical workflow for sharing:**
```bash
# On source machine
./save-image.sh save claude-code-env_backup.tar.gz
scp claude-code-env_backup.tar.gz user@remote:/path/

# On target machine
./save-image.sh load claude-code-env_backup.tar.gz
./run.sh start
```

---

## ⚙️ Configuration

### Environment Variables (`.env`)

| Variable               | Default        | Description                                       |
| ---------------------- | -------------- | ------------------------------------------------- |
| `ANTHROPIC_API_KEY`    | *(required)*   | Your Anthropic API key for Claude                 |
| `CODE_SERVER_PASSWORD` | `claude-dev`   | Password for VS Code web UI                       |
| `CODE_SERVER_AUTH`     | `password`     | Set to `none` to disable auth                     |
| `GIT_USER_NAME`        | *(optional)*   | Git commit author name                            |
| `GIT_USER_EMAIL`       | *(optional)*   | Git commit author email                           |
| `WORKSPACE_PATH`       | `./workspace`  | Host path to mount as workspace                   |
| `TZ`                   | `Asia/Kolkata` | Timezone                                          |
| `NETWORK_MODE`         | `host`         | `host` for full access, `bridge` for port mapping |
| `VSCODE_PORT`          | `8080`         | VS Code port (bridge mode only)                   |
| `MEMORY_LIMIT`         | `8g`           | Container memory limit                            |
| `CPU_LIMIT`            | `4.0`          | Container CPU limit                               |
| `MOUNT_DOCKER_SOCKET`  | `false`        | Mount Docker socket for DinD                      |
| `MOUNT_SSH_KEYS`       | `false`        | Mount `~/.ssh` into container                     |
| `MOUNT_GITCONFIG`      | `true`         | Mount `~/.gitconfig` (read-only)                  |

### Volume Mounts

| Mount                                        | Controlled by              | Purpose                      |
| -------------------------------------------- | -------------------------- | ---------------------------- |
| `WORKSPACE_PATH → /home/developer/workspace` | always on                  | Your project files           |
| `~/.gitconfig`                               | `MOUNT_GITCONFIG=true`     | Reuse host git configuration |
| `~/.ssh`                                     | `MOUNT_SSH_KEYS=true`      | SSH keys for git             |
| `/var/run/docker.sock`                       | `MOUNT_DOCKER_SOCKET=true` | Docker-in-Docker             |

### Network Access

By default, `NETWORK_MODE=host` for **full network access**:
- All container ports are directly available on the host
- The container can access all host network services
- No port mapping needed

To switch to isolated networking:
```bash
# In .env:
NETWORK_MODE=bridge
VSCODE_PORT=8080
```

---

## 🔧 Advanced Usage

### Docker-in-Docker
```bash
MOUNT_DOCKER_SOCKET=true ./run.sh start
# Or set MOUNT_DOCKER_SOCKET=true in .env
```

### SSH Key Access
```bash
MOUNT_SSH_KEYS=true ./run.sh start
# Or set MOUNT_SSH_KEYS=true in .env
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

To reset everything: `./run.sh clean`

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

## 📁 File Structure

```
claude-code-env/
├── Dockerfile           # Image definition
├── docker-compose.yml   # Compose config (alternative to run.sh)
├── entrypoint.sh        # Container startup script
├── run.sh               # Container runner (standalone, no compose)
├── save-image.sh        # Save/load Docker image to/from file
├── Makefile             # Convenience targets
├── .env.example         # Configuration template
├── .dockerignore        # Build context exclusions
├── README.md            # This file
└── workspace/           # Default workspace directory
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
Increase the memory limit in `.env`:
```bash
MEMORY_LIMIT=16g
```

---

## 📄 License

MIT
