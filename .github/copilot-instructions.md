# Copilot Instructions for n8n-postgres

This project provides a secure, automated local n8n + PostgreSQL stack, exposed via a public domain using Cloudflare Tunnel. It is optimized for local development and safe public access.

## Architecture Overview
- **Docker Compose** orchestrates two main services:
  - `n8n`: Workflow automation tool, configured for PostgreSQL and public HTTPS access.
  - `postgres`: Database for n8n, initialized with a non-root user via `init-data.sh`.
- **Cloudflare Tunnel** is the default/recommended method for exposing n8n to the internet. See `cloudflare-guide.md` for setup.
- **Environment variables** are managed via `.env` (see `.env.example` for template).

## Key Workflows
- **Start everything (recommended):**
  ```bash
  ./start.sh n8n.seudominio.com
  ```
  - Starts Cloudflare Tunnel and Docker containers.
  - Updates `.env` with your public domain.
  - Shows the public access URL.
  - Press `Ctrl+C` to stop all services.
- **Manual Docker Compose commands:**
  - `docker-compose up -d` — Start services in background
  - `docker-compose logs -f n8n` — View n8n logs
  - `docker-compose down` — Stop all services
- **Cloudflare Tunnel manual control:**
  - `cloudflared tunnel run n8n-tunnel` — Start tunnel (if not using script)

## Project Conventions & Patterns
- **Database user:** Always use the non-root user (`POSTGRES_NON_ROOT_USER`) for n8n DB access. See `init-data.sh`.
- **Public URL:** Always set `N8N_HOST`, `WEBHOOK_URL`, and `N8N_EDITOR_BASE_URL` to your public domain (Cloudflare or ngrok).
- **Secrets:** Never commit `.env` or secrets. Use `.env.example` as a reference.
- **Timezone:** All services default to `America/Sao_Paulo` (see `docker-compose.yml`).
- **API Access:**
  - Generate API keys via the n8n UI (`Settings > API`).
  - Test with `curl` or via Swagger UI at `/api/v1/docs`.

## Integration Points
- **Cloudflare Tunnel:**
  - Setup and troubleshooting in `cloudflare-guide.md`.
  - Tunnel config in `~/.cloudflared/config.yml` (user-specific).
- **ngrok:** Optional, enabled via `./start.sh --ngrok` (see README for details).

## Examples
- **Start with Cloudflare Tunnel:**
  ```bash
  ./start.sh n8n.seudominio.com
  ```
- **Update n8n version:**
  ```bash
  docker-compose pull n8n
  docker-compose up -d --force-recreate
  ```

## Reference Files
- `README.md`: Main documentation and workflow examples
- `cloudflare-guide.md`: Step-by-step Cloudflare Tunnel setup
- `start.sh`: Main automation script
- `docker-compose.yml`: Service definitions
- `.env.example`: Environment variable template
- `init-data.sh`: Postgres user initialization

---
For any unclear or missing conventions, review `README.md` and `cloudflare-guide.md` for the latest project practices.
