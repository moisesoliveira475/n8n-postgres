# n8n-postgres

Setup completo do n8n com PostgreSQL usando Docker Compose, otimizado para desenvolvimento local com webhooks externos via ngrok.

## 🚀 Início Rápido

### Método 1: Automático com `start-n8n-ngrok.sh`

Este script automatiza todo o processo, desde a configuração do ngrok até o início dos serviços.

```bash
# Usar subdomínio específico (requer conta ngrok paga)
./start-n8n-ngrok.sh meu-n8n

# Ou usar subdomínio aleatório (conta gratuita)
./start-n8n-ngrok.sh
```

O script irá:
- ✅ Iniciar o ngrok
- ✅ Obter a URL do tunnel automaticamente
- ✅ Atualizar o arquivo `.env` com as configurações corretas
- ✅ Iniciar os containers Docker
- ✅ Fornecer todos os links de acesso

### Método 2: Manual

1. **Configurar ambiente:**
   ```bash
   cp .env.example .env
   # Edite o .env com suas configurações
   ```

2. **Para acesso local apenas:**
   ```bash
   # Configure no .env:
   N8N_PROTOCOL=http
   N8N_HOST=localhost:5678
   WEBHOOK_URL=http://localhost:5678/
   
   # Iniciar containers
   docker-compose up -d
   ```
   Acesse: http://localhost:5678

3. **Para acesso externo com ngrok:**
   ```bash
   # Iniciar ngrok
   ngrok http 5678
   
   # Atualizar .env com a URL do ngrok:
   N8N_PROTOCOL=https
   N8N_HOST=sua-url-ngrok.ngrok-free.app
   WEBHOOK_URL=https://sua-url-ngrok.ngrok-free.app/
   N8N_EDITOR_BASE_URL=https://sua-url-ngrok.ngrok-free.app
   
   # Iniciar containers
   docker-compose up -d
   ```

## 🌐 Acessos

Após iniciar com o script automático:
- **n8n Interface**: `https://sua-url-ngrok.ngrok-free.app`
- **ngrok Dashboard**: `http://localhost:4040`
- **PostgreSQL**: `localhost:5432`

## 📋 Pré-requisitos

- Docker e Docker Compose instalados
- ngrok instalado ([Download](https://ngrok.com/download))
- Para webhooks externos: conta ngrok configurada
- `jq` (opcional, para formatação JSON): `sudo apt install jq`

### Configuração do ngrok
```bash
# Instalar ngrok
wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
tar xvzf ngrok-v3-stable-linux-amd64.tgz
sudo mv ngrok /usr/local/bin

# Configurar token (opcional, mas recomendado)
ngrok config add-authtoken SEU_TOKEN_AQUI
```

## 📡 Configuração de Webhooks

### Para serviços externos (GitHub, Stripe, etc.):
- **URL base**: `https://sua-url-ngrok.ngrok-free.app/webhook/`
- **Exemplo completo**: `https://sua-url-ngrok.ngrok-free.app/webhook/github-deploy`

### Teste de webhook:
```bash
curl -X POST https://sua-url-ngrok.ngrok-free.app/webhook/test \
  -H "Content-Type: application/json" \
  -d '{"message": "teste webhook"}'
```

### Configurações importantes para webhooks:
```env
# No arquivo .env
WEBHOOK_URL=https://sua-url-ngrok.ngrok-free.app/
N8N_HOST=sua-url-ngrok.ngrok-free.app
N8N_PROTOCOL=https
N8N_EDITOR_BASE_URL=https://sua-url-ngrok.ngrok-free.app
```

## 🔧 Variáveis de Ambiente

### Database
| Variável | Descrição | Padrão |
|---|---|---|
| `POSTGRES_USER` | Usuário admin do PostgreSQL | `admin` |
| `POSTGRES_PASSWORD` | Senha do admin | `admin` |
| `POSTGRES_DB` | Nome do banco | `n8n` |
| `POSTGRES_NON_ROOT_USER` | Usuário do n8n | `admin` |
| `POSTGRES_NON_ROOT_PASSWORD` | Senha do usuário n8n | `admin` |

### n8n Core
| Variável | Descrição | Exemplo |
|---|---|---|
| `N8N_HOST` | Host público do n8n | `abc123.ngrok-free.app` |
| `N8N_PROTOCOL` | Protocolo (http/https) | `https` |
| `WEBHOOK_URL` | URL base para webhooks | `https://abc123.ngrok-free.app/` |
| `N8N_EDITOR_BASE_URL` | URL do editor | `https://abc123.ngrok-free.app` |
| `N8N_PORT` | Porta interna | `5678` |
| `N8N_LISTEN_ADDRESS` | Endereço de escuta | `0.0.0.0` |

### Configurações Adicionais
| Variável | Descrição | Padrão |
|---|---|---|
| `N8N_PATH` | Caminho base | `/` |
| `N8N_PUSH_BACKEND` | Backend para notificações | `websocket` |

## 📁 Estrutura do Projeto

```
├── docker-compose.yml       # Configuração principal do Docker Compose
├── start-n8n-ngrok.sh      # Script de automação ngrok + n8n
├── init-data.sh            # Script de inicialização do PostgreSQL
├── .env                    # Variáveis de ambiente (configurado automaticamente)
├── .env.example           # Exemplo de configuração
└── README.md              # Documentação completa
```
O script `init-data.sh` é executado na primeira vez que o contêiner do PostgreSQL é iniciado. Ele cria um usuário não-root com as credenciais `POSTGRES_NON_ROOT_USER` e `POSTGRES_NON_ROOT_PASSWORD` e concede a ele todos os privilégios no banco de dados `POSTGRES_DB`. Esta é uma boa prática de segurança para evitar que a aplicação n8n se conecte ao banco de dados com o superusuário do PostgreSQL.

## 🛠️ Comandos Úteis

### Docker Compose
```bash
# Iniciar serviços
docker-compose up -d

# Ver logs em tempo real
docker-compose logs -f

# Ver logs específicos
docker-compose logs -f n8n
docker-compose logs -f postgres

# Parar serviços
docker-compose down

# Restart completo (remove volumes)
docker-compose down -v && docker-compose up -d

# Reiniciar apenas o n8n (útil após alterar .env)
docker-compose restart n8n
```

### ngrok
```bash
# Verificar status do ngrok
curl http://localhost:4040/api/tunnels | jq

# Iniciar ngrok manualmente
ngrok http 5678

# Iniciar com subdomínio específico
ngrok http --subdomain=meu-n8n 5678

# Parar ngrok
pkill ngrok
```

### Backup e Restore
```bash
# Backup do banco de dados
docker-compose exec postgres pg_dump -U admin n8n > backup.sql

# Restaurar backup
docker-compose exec -T postgres psql -U admin n8n < backup.sql

# Backup completo dos volumes
docker run --rm -v n8n-postgres_db_storage:/data -v $(pwd):/backup alpine tar czf /backup/db_backup.tar.gz /data
docker run --rm -v n8n-postgres_n8n_storage:/data -v $(pwd):/backup alpine tar czf /backup/n8n_backup.tar.gz /data
```

## 🛡️ Segurança

- ⚠️ **Desenvolvimento apenas**: Esta configuração é otimizada para desenvolvimento local
- 🔐 **Webhook Security**: Configure autenticação nos webhooks quando possível
- 🔑 **Encryption Key**: Use uma chave de criptografia forte e única
- 📝 **Logs**: Monitore logs para detectar atividades suspeitas
- 🌐 **ngrok**: Em produção, use soluções como Cloudflare Tunnel

## 🐛 Troubleshooting

### ngrok não conecta
```bash
# Verificar se ngrok está rodando
curl http://localhost:4040/api/tunnels

# Verificar configuração
ngrok config check

# Logs do ngrok (se usando script)
cat ngrok.log

# Reiniciar ngrok
pkill ngrok
./start-n8n-ngrok.sh
```

### Containers não iniciam
```bash
# Verificar logs
docker-compose logs

# Verificar status
docker-compose ps

# Restart limpo
docker-compose down -v
docker-compose up -d
```

### Webhooks não funcionam
1. **Verificar URL no serviço externo**: Deve ser `https://sua-url.ngrok-free.app/webhook/nome`
2. **Verificar logs do n8n**: `docker-compose logs -f n8n`
3. **Testar conectividade**: `curl https://sua-url/webhook/test`
4. **Verificar variáveis**: `WEBHOOK_URL` deve terminar com `/`

### Problemas de conectividade
```bash
# Testar conectividade local
curl http://localhost:5678

# Testar conectividade externa (via ngrok)
curl https://sua-url.ngrok-free.app

# Verificar se o tunnel está ativo
curl http://localhost:4040/api/tunnels
```

## 🔄 Atualização do n8n

Para atualizar sua instância do n8n para a versão mais recente, siga estes passos:

1.  **Baixar a imagem mais recente:**
    ```bash
    docker-compose pull
    ```

2.  **Parar e recriar os contêineres:**
    ```bash
    docker-compose down && docker-compose up -d
    ```

Isso irá parar os serviços, baixar a nova imagem e iniciá-los novamente com os dados preservados.

## 🔄 Alternativas ao ngrok

### Para desenvolvimento:
1. **Serveo** (Gratuito): `ssh -R 80:localhost:5678 serveo.net`
2. **LocalTunnel**: `npx localtunnel --port 5678`
3. **Cloudflare Tunnel**: Solução mais robusta para produção

### Para produção:
1. **Cloudflare Tunnel** (Recomendado)
2. **VPS com domínio próprio**
3. **Reverse proxy interno**

## 📚 Recursos e Documentação

- [Documentação oficial n8n](https://docs.n8n.io/)
- [ngrok Documentation](https://ngrok.com/docs)
- [Webhook Examples](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/)
- [n8n Configuration Options](https://docs.n8n.io/hosting/configuration/)
- [Docker Compose Reference](https://docs.docker.com/compose/)

---

**Desenvolvimento automatizado com n8n + ngrok! 🚀**
