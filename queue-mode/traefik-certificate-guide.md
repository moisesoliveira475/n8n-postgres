# Guia de Certificados SSL com Traefik (queue-mode)

Este guia explica como configurar certificados SSL automáticos usando Traefik no modo queue do n8n.

## Pré-requisitos

- Docker e Docker Compose instalados
- Domínio válido apontando para o servidor
- Acesso à pasta `queue-mode/`

## Passos Básicos

1. **Configurar variáveis de ambiente**
   - Edite o arquivo `.env` em `queue-mode/` com seu domínio e email.

2. **Configurar Traefik**
   - Adapte o `docker-compose.yml` para incluir o serviço Traefik.
   - Exemplo de configuração mínima:

```yaml
  traefik:
    image: traefik:v2.10
    command:
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.email=${TRAEFIK_ACME_EMAIL}"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./letsencrypt:/letsencrypt"
    restart: unless-stopped
```

3. **Configurar labels nos serviços**
   - No serviço do n8n, adicione labels para Traefik rotear e gerar certificados:

```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.n8n.rule=Host(`${DOMAIN}`)"
      - "traefik.http.routers.n8n.entrypoints=websecure"
      - "traefik.http.routers.n8n.tls.certresolver=letsencrypt"
```

4. **Subir os containers**

```bash
cd queue-mode
mkdir -p letsencrypt
chmod 600 letsencrypt
# Suba os serviços normalmente

docker compose up -d
```

5. **Acessar o n8n**
   - Acesse via `https://SEU_DOMINIO` com certificado SSL válido.

## Dicas
- O Traefik gerencia e renova os certificados automaticamente.
- O diretório `letsencrypt/` deve ser persistente e seguro.
- Consulte a [documentação oficial do Traefik](https://doc.traefik.io/traefik/) para configurações avançadas.

---

Se precisar de exemplos completos de `docker-compose.yml` ou de labels, consulte a documentação do projeto ou peça exemplos específicos.
