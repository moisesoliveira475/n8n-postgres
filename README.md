# n8n-postgres com Cloudflare Tunnel

Setup completo e seguro do n8n com PostgreSQL, usando Docker Compose e otimizado para desenvolvimento local com um domínio público e permanente via **Cloudflare Tunnel**.

Este projeto foi atualizado para usar Cloudflare Tunnel como o método padrão e recomendado para expor sua instância n8n local à internet, oferecendo uma solução gratuita, segura e com domínio personalizado.

## 🚀 Início Rápido (Recomendado)

Este script automatiza todo o processo, desde a configuração do túnel até o início dos serviços do n8n.

### Pré-requisitos

1.  **Docker e Docker Compose** instalados.
2.  **Cloudflare Tunnel (`cloudflared`)** instalado e configurado. Siga o guia detalhado no arquivo `cloudflare-guide.md`.
3.  **Um domínio sob gestão da Cloudflare**: Para que o túnel funcione, seu domínio precisa usar os nameservers da Cloudflare. Isso permite que a Cloudflare gerencie os registros DNS e direcione o tráfego para o túnel. Se ainda não o fez, siga o [guia oficial da Cloudflare para configurar seu domínio](https://developers.cloudflare.com/dns/zone-setups/full-setup/setup/).

### Execução

O script `start.sh` inicia o Cloudflare Tunnel e os containers do n8n.

```bash
# Uso padrão com Cloudflare Tunnel
./start.sh n8n.seudominio.com
```

O script irá:
- ✅ Iniciar o **Cloudflare Tunnel** para expor `localhost:5678`.
- ✅ Atualizar o arquivo `.env` com a URL do seu domínio.
- ✅ Iniciar os containers Docker (`n8n` e `postgres`).
- ✅ Fornecer o link de acesso público e seguro.

Para parar todos os serviços (túnel e containers), simplesmente pressione `Ctrl+C` no terminal onde o script está rodando.

## 🌐 Acessos

- **Interface n8n**: `https://n8n.seudominio.com`
- **PostgreSQL (local)**: `localhost:5432`

## 🔧 Alternativa: Usando ngrok

Se você prefere usar ngrok, o script ainda oferece essa opção através da flag `--ngrok`.

### Pré-requisitos (ngrok)

- **ngrok** instalado e com `authtoken` configurado.

### Execução com ngrok

```bash
# Usar subdomínio específico (requer conta ngrok paga)
./start.sh --ngrok meu-n8n

# Ou usar subdomínio aleatório (conta gratuita)
./start.sh --ngrok
```

O script irá:
- ✅ Iniciar o **ngrok**.
- ✅ Obter a URL do túnel automaticamente.
- ✅ Atualizar o arquivo `.env`.
- ✅ Iniciar os containers Docker.
- ✅ Fornecer os links de acesso, incluindo o dashboard do ngrok (`http://localhost:4040`).

## 📁 Estrutura do Projeto

```
├── docker-compose.yml    # Configuração principal do Docker Compose
├── start.sh              # Script de automação (Cloudflare ou ngrok)
├── tasks.md              # GUIA: Como configurar o Cloudflare Tunnel
├── init-data.sh          # Script de inicialização do PostgreSQL
├── .env                  # Variáveis de ambiente (criado a partir do .env.example)
├── .env.example          # Exemplo de configuração
└── README.md             # Esta documentação
```

## 🛡️ Segurança

- **Cloudflare Tunnel é o padrão por ser mais seguro** e robusto que o ngrok para exposição contínua.
- O script `init-data.sh` cria um usuário não-root no PostgreSQL para a aplicação n8n, seguindo as boas práticas de segurança.
- Lembre-se de configurar autenticação nos seus webhooks sempre que possível.

## 🛠️ Comandos Úteis

### Docker Compose
```bash
# Iniciar serviços em background
docker-compose up -d

# Ver logs em tempo real
docker-compose logs -f n8n

# Parar serviços
docker-compose down

# Reiniciar n8n (útil após alterar .env manualmente)
docker-compose restart n8n
```

### Cloudflare Tunnel
```bash
# Verificar status do cloudflared
cloudflared tunnel list

# Iniciar túnel manualmente (se não usar o script)
cloudflared tunnel run <nome-do-tunel>
```

## 🔄 Atualização do n8n

Para atualizar sua instância do n8n para a versão mais recente, puxe a nova imagem e reinicie os containers:

```bash
docker-compose pull n8n
docker-compose up -d --force-recreate
```

## 📚 Recursos e Documentação

- [Guia de Configuração do Tunnel](./cloudflare-guide.md)
- [Documentação oficial n8n](https://docs.n8n.io/)
- [Documentação do Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [n8n Configuration Options](https://docs.n8n.io/hosting/configuration/)