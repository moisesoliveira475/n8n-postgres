# Passo a Passo: Configurando Cloudflare Tunnel para n8n no WSL

**Objetivo:** Fazer com que um subdomínio (ex: `n8n.seudominio.com`) aponte para sua instância n8n local (`localhost:5678`) rodando no WSL, de forma segura e gratuita, usando o Cloudflare Tunnel.

---

### Passo 1: Pré-requisitos

1.  **Conta Cloudflare:** Crie uma conta gratuita no [Cloudflare](https://dash.cloudflare.com/sign-up).
2.  **Domínio na Cloudflare:** Adicione seu domínio do **Name.com** à sua conta Cloudflare.
    *   Durante o processo, a Cloudflare pedirá para você alterar os **Nameservers** do seu domínio.
    *   Vá ao painel de controle do seu domínio no **Name.com**.
    *   Encontre a seção de gerenciamento de DNS ou Nameservers.
    *   Substitua os nameservers existentes pelos dois que a Cloudflare fornecer.
    *   **Atenção:** Essa alteração pode levar de alguns minutos a algumas horas para se propagar.

---

### Passo 2: Instalar o `cloudflared` no WSL

`cloudflared` é a ferramenta de linha de comando que cria a conexão entre sua máquina (WSL) e a rede da Cloudflare.

1.  **Abra seu terminal WSL** (Ubuntu, Debian, etc.).
2.  **Baixe o pacote de instalação `.deb`:**
    ```bash
    wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    ```
3.  **Instale o pacote com `dpkg`:**
    ```bash
    sudo dpkg -i cloudflared-linux-amd64.deb
    ```
4.  **Verifique se a instalação funcionou:**
    ```bash
    cloudflared --version
    ```
    Você deverá ver a versão do `cloudflared` que foi instalada.

---

### Passo 3: Autenticar `cloudflared` com sua Conta Cloudflare

Conecte a ferramenta `cloudflared` à sua conta.

1.  **Execute o comando de login no seu terminal WSL:**
    ```bash
    cloudflared tunnel login
    ```
2.  **Autorize no Navegador:**
    *   O comando exibirá uma URL. Copie essa URL e cole-a em um navegador no seu Windows.
    *   Faça login na sua conta Cloudflare e selecione o domínio que você configurou no Passo 1.
3.  **Confirmação:** Após a autorização, um arquivo de certificado (`cert.pem`) será criado no diretório `~/.cloudflared/` dentro do seu ambiente WSL. Isso autoriza o `cloudflared` a gerenciar túneis para sua conta.

---

### Passo 4: Criar o Túnel

Um "túnel" é uma conexão nomeada e persistente na Cloudflare.

1.  **Execute o comando para criar um túnel:**
    ```bash
    cloudflared tunnel create n8n-tunnel
    ```
    *(Você pode usar o nome que quiser, mas `n8n-tunnel` é um bom padrão).*

2.  **Guarde as Informações:** O comando irá retornar:
    *   Um **ID** único para o túnel (um UUID longo).
    *   O caminho para um **arquivo de credenciais** JSON.
    
    Essas informações são salvas automaticamente, mas é bom saber que elas existem. O arquivo de credenciais ficará em `~/.cloudflared/<TUNNEL_ID>.json`.

---

### Passo 5: Configurar o Túnel para o n8n

A maneira mais robusta de gerenciar o túnel é através de um arquivo de configuração.

1.  **Crie o diretório de configuração se ele não existir:**
    ```bash
    mkdir -p ~/.cloudflared/
    ```
2.  **Crie e edite o arquivo `config.yml`:**
    ```bash
    nano ~/.cloudflared/config.yml
    ```

3.  **Cole o seguinte conteúdo no arquivo:**
    ```yaml
    tunnel: <ID_DO_SEU_TUNNEL>
    credentials-file: /home/SEU_USUARIO_WSL/.cloudflared/<ID_DO_SEU_TUNNEL>.json
    
    ingress:
      # Regra 1: Aponta o tráfego do seu subdomínio para o n8n local
      - hostname: n8n.seudominio.com
        service: http://localhost:5678
      # Regra 2: Bloqueia qualquer outro tráfego que tente usar este túnel
      - service: http_status:404
    ```

4.  **Personalize o arquivo:**
    *   Substitua `<ID_DO_SEU_TUNNEL>` pelo ID que você obteve no Passo 4 (nas duas primeiras linhas).
    *   Substitua `/home/SEU_USUARIO_WSL/` pelo caminho correto do seu diretório home no WSL (você pode descobrir com o comando `echo $HOME`).
    *   Substitua `n8n.seudominio.com` pelo subdomínio real que você deseja usar.
    *   A linha `service: http://localhost:5678` já está correta para a configuração padrão do seu projeto n8n.

5.  **Salve e feche o arquivo** (em `nano`, pressione `Ctrl+X`, depois `Y` e `Enter`).

---

### Passo 6: Apontar seu Domínio para o Túnel (Rota de DNS)

Crie um registro DNS na Cloudflare para que o tráfego do seu subdomínio seja enviado para o túnel.

1.  **Execute o comando de rota de DNS:**
    ```bash
    cloudflared tunnel route dns n8n-tunnel n8n.seudominio.com
    ```
    *(Use os mesmos nomes de túnel e hostname que você definiu nos passos anteriores).*

2.  Isso criará automaticamente um registro do tipo `CNAME` no painel de DNS da Cloudflare para o seu domínio, apontando para o seu túnel.

---

### Passo 7: Iniciar o Túnel

Com tudo configurado, inicie o túnel para colocar seu n8n online.

1.  **Primeiro, inicie seu n8n com Docker Compose (em um terminal):**
    ```bash
    docker-compose up
    ```

2.  **Em um segundo terminal WSL, execute o túnel:**
    ```bash
    cloudflared tunnel run n8n-tunnel
    ```
    *(Use o nome do túnel que você criou).*

O terminal do `cloudflared` mostrará logs confirmando que a conexão foi estabelecida. **Você precisa manter este terminal aberto** para que o túnel continue funcionando.

**Pronto!** Agora você pode acessar `https://n8n.seudominio.com` no seu navegador. O tráfego será roteado de forma segura pela Cloudflare até sua instância n8n rodando no WSL, com um certificado HTTPS válido.
