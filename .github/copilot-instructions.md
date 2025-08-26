# Copilot Instructions for n8n-postgres

This project provides two distinct n8n + PostgreSQL implementations, each optimized for different use cases:

- **Standard Mode** (`/standard/`): Simple setup for personal use and development
- **Queue Mode** (`/queue-mode/`): Enterprise-grade scalable architecture

## Project Structure
```
n8n-postgres/
├── standard/          # Simple setup for personal/dev use
│   ├── docker-compose.yml
│   ├── start.sh
│   ├── cloudflare-guide.md
│   └── README.md
├── queue-mode/        # Enterprise scalable setup
│   ├── docker-compose.yml
│   ├── start.sh
│   ├── dynamic_conf.yml
│   └── README.md
└── README.md          # Main comparison and documentation
```

## Architecture Overview

### Standard Mode Architecture
- **Docker Compose** orchestrates 2-3 services:
  - `n8n`: Single workflow automation instance
  - `postgres`: Database with non-root user via `init-data.sh`
  - `cloudflared`: Optional Cloudflare Tunnel
- **Cloudflare Tunnel** is the default/recommended method for public exposure
- **Environment variables** managed via `.env` (see `.env.example`)

### Queue Mode Architecture  
- **Docker Compose** orchestrates 6+ services:
  - `traefik`: Reverse proxy with automatic SSL
  - `n8n-main`: Main interface and API
  - `n8n-worker`: Dedicated workflow processing workers
  - `n8n-webhook`: Dedicated webhook handlers
  - `redis`: Message queue broker
  - `postgres`: Database backend
  - `cloudflare-ddns`: Dynamic DNS updates

## Key Workflows

### Standard Mode Workflows
- **Start everything (recommended):**
  ```bash
  cd standard/
  ./start.sh n8n.seudominio.com
  ```
  - Starts Cloudflare Tunnel and Docker containers
  - Updates `.env` with your public domain
  - Shows the public access URL
  - Press `Ctrl+C` to stop all services

- **Alternative with ngrok:**
  ```bash
  cd standard/
  ./start.sh --ngrok meu-subdominio
  ```

- **Manual Docker Compose commands:**
  ```bash
  cd standard/
  docker-compose up -d              # Start services in background
  docker-compose logs -f n8n        # View n8n logs
  docker-compose down               # Stop all services
  ```

### Queue Mode Workflows
- **Start everything:**
  ```bash
  cd queue-mode/
  cp .env.example .env              # Configure first
  nano .env                         # Edit configuration
  ./start.sh                        # Start all services
  ```

- **Manual management:**
  ```bash
  cd queue-mode/
  docker-compose up -d              # Start all services
  docker-compose logs -f n8n-main   # View main service logs
  docker-compose logs -f n8n-worker # View worker logs
  docker-compose restart n8n-worker # Restart workers only
  docker-compose down               # Stop all services
  ```

- **Scaling workers:**
  ```bash
  cd queue-mode/
  docker-compose up -d --scale n8n-worker=3  # Scale to 3 workers
  ```

## Project Conventions & Patterns

### Common Patterns (Both Modes)
- **Database user:** Always use the non-root user (`POSTGRES_NON_ROOT_USER`) for n8n DB access. See `init-data.sh`.
- **Public URL:** Always set `N8N_HOST`, `WEBHOOK_URL`, and `N8N_EDITOR_BASE_URL` to your public domain.
- **Secrets:** Never commit `.env` or secrets. Use `.env.example` as a reference.
- **Timezone:** All services default to `America/Sao_Paulo` (see `docker-compose.yml`).
- **API Access:**
  - Generate API keys via the n8n UI (`Settings > API`).
  - Test with `curl` or via Swagger UI at `/api/v1/docs`.

### Standard Mode Specific
- **Single instance:** All n8n functionality in one container
- **Simple networking:** Direct port mapping (5678)
- **Cloudflare Tunnel:** Primary method for public exposure
- **File structure:** Minimal - just `docker-compose.yml`, `start.sh`, and docs

### Queue Mode Specific
- **Execution mode:** Must set `EXECUTIONS_MODE=queue`
- **Redis queue:** All workflows go through Redis queue
- **Traefik labels:** Services use Traefik routing labels
- **SSL certificates:** Two approaches available:
  - **Option 1**: Automatic Let's Encrypt via Traefik (recommended)
  - **Option 2**: External certificates via certbot (current default)
- **Service separation:** Main, worker, and webhook are separate containers
- **Dynamic configuration:** Uses `dynamic_conf.yml` for Traefik (external certs) or built-in config (automatic certs)

## Integration Points

### Standard Mode Integrations
- **Cloudflare Tunnel:**
  - Setup and troubleshooting in `standard/cloudflare-guide.md`
  - Tunnel config in `~/.cloudflared/config.yml` (user-specific)
- **ngrok:** Optional, enabled via `./start.sh --ngrok` (see README for details)

### Queue Mode Integrations
- **Traefik Reverse Proxy:**
  - **Option 1**: Automatic SSL with Let's Encrypt (use `docker-compose-auto-ssl.yml`)
  - **Option 2**: External SSL certificates via dynamic configuration (`dynamic_conf.yml`)
  - Dashboard available at port 8080
- **Redis Queue:**
  - Message broker for workflow execution
  - Credentials managed via environment variables
- **Cloudflare DDNS:**
  - Automatic DNS updates for dynamic IPs
  - Configured via CLOUDFLARE_API_TOKEN
- **SSL Certificate Management:**
  - **Automatic (recommended):** Traefik handles Let's Encrypt automatically
  - **External:** Manual certificate generation with certbot + dynamic configuration

## Mode Selection Guide
- **Use Standard Mode for:**
  - Personal use and development
  - Small teams (1-5 users)
  - Learning and prototyping
  - Limited resources (< 1GB RAM)
  - Simple workflow requirements

- **Use Queue Mode for:**
  - Production environments
  - Enterprise use cases
  - High-volume processing (>1000 executions/day)
  - Teams requiring high availability
  - Complex workflows with heavy processing

## Examples

### Standard Mode Examples
- **Start with Cloudflare Tunnel:**
  ```bash
  cd standard/
  ./start.sh n8n.seudominio.com
  ```
- **Start with ngrok:**
  ```bash
  cd standard/
  ./start.sh --ngrok meu-subdominio
  ```
- **Update n8n version:**
  ```bash
  cd standard/
  docker-compose pull n8n
  docker-compose up -d --force-recreate
  ```

### Queue Mode Examples
- **Initial setup:**
  ```bash
  cd queue-mode/
  cp .env.example .env
  # Edit .env with your configuration
  ./start.sh
  ```
- **Scale workers:**
  ```bash
  cd queue-mode/
  docker-compose up -d --scale n8n-worker=5
  ```
- **View Traefik dashboard:**
  ```bash
  # Access https://traefik.yourdomain.com/dashboard/
  ```
- **Switch to automatic SSL certificates:**
  ```bash
  cd queue-mode/
  cp docker-compose.yml docker-compose.yml.backup
  cp docker-compose-auto-ssl.yml docker-compose.yml
  mv dynamic_conf.yml dynamic_conf.yml.disabled
  docker-compose down && docker-compose up -d
  ```
- **Certificate troubleshooting:**
  ```bash
  cd queue-mode/
  ./fix-certificates.sh  # Interactive certificate fixing tool
  ```

## Reference Files

### Standard Mode Files
- `standard/README.md`: Main documentation for simple setup
- `standard/cloudflare-guide.md`: Step-by-step Cloudflare Tunnel setup
- `standard/start.sh`: Automation script for Cloudflare/ngrok
- `standard/docker-compose.yml`: Simple service definitions
- `standard/init-data.sh`: Postgres user initialization

### Queue Mode Files
- `queue-mode/README.md`: Enterprise setup documentation
- `queue-mode/start.sh`: Queue mode automation script
- `queue-mode/docker-compose.yml`: Complex service orchestration (external certificates)
- `queue-mode/docker-compose-auto-ssl.yml`: Alternative configuration with automatic SSL
- `queue-mode/dynamic_conf.yml`: Traefik dynamic configuration (for external certificates)
- `queue-mode/fix-certificates.sh`: Interactive SSL certificate troubleshooting tool
- `queue-mode/diagnostics.md`: Troubleshooting guide
- `queue-mode/TROUBLESHOOTING.md`: Common issues and solutions

### Root Level Files
- `README.md`: Project overview and mode comparison
- `.github/copilot-instructions.md`: This file - development guidelines

## SSL Certificate Management (Queue Mode)

The queue-mode offers two approaches for SSL certificates:

### Option 1: Automatic SSL (Recommended)
- **Configuration**: Use `docker-compose-auto-ssl.yml`
- **Management**: Traefik handles Let's Encrypt automatically
- **Pros**: Zero maintenance, automatic renewal, simpler setup
- **Cons**: Requires public domain, depends on Let's Encrypt connectivity
- **Best for**: Production environments, development with public domains

### Option 2: External SSL (Current Default)
- **Configuration**: Use `docker-compose.yml` + `dynamic_conf.yml`
- **Management**: Manual certificate generation with certbot
- **Pros**: Full control, works with any CA, certificates persist on host
- **Cons**: Manual renewal required, more complex setup, more failure points
- **Best for**: Corporate environments, custom certificates, air-gapped deployments

### Migration Between Options
- **To Automatic**: `cp docker-compose-auto-ssl.yml docker-compose.yml && mv dynamic_conf.yml dynamic_conf.yml.disabled`
- **To External**: Restore backup and re-enable `dynamic_conf.yml`
- **Troubleshooting**: Use `./fix-certificates.sh` for interactive fixing

### Local Development
- **HTTP Mode**: Disable SSL for local testing
- **Self-signed**: Generate certificates for local HTTPS testing
- **Hosts file**: Add entries for local domain resolution

---
For any unclear or missing conventions, review the appropriate mode's README.md and documentation files for the latest project practices. The main README.md in the root provides a comprehensive comparison to help choose between Standard and Queue modes.
