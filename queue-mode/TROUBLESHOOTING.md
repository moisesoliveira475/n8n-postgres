# 🚨 Guia de Troubleshooting - n8n Queue Mode

> **Soluções rápidas para os problemas mais comuns encontrados durante setup e uso**

## 📋 Índice de Problemas

- [🔴 Problemas de Conectividade](#-problemas-de-conectividade)
- [🔴 Problemas de Certificados SSL](#-problemas-de-certificados-ssl)
- [🔴 Problemas de DNS e Hosts](#-problemas-de-dns-e-hosts)
- [🔴 Problemas com Containers](#-problemas-com-containers)
- [🔴 Problemas do n8n](#-problemas-do-n8n)
- [🔴 Problemas do Traefik](#-problemas-do-traefik)
- [🔧 Comandos de Diagnóstico](#-comandos-de-diagnóstico)

---

## 🔴 Problemas de Conectividade

### ❌ `ERR_CONNECTION_REFUSED` no navegador

**Sintomas**: Navegador não consegue acessar `https://traefik.meudominio.com`

**Causa**: Diferença entre resolução DNS do WSL vs Windows

**Solução**:
```bash
# 1. Verificar IP do WSL
hostname -I | awk '{print $1}'

# 2. Editar hosts do Windows (como Administrador)
# Arquivo: C:\Windows\System32\drivers\etc\hosts
# Adicionar:
172.21.55.73 traefik.meudominio.com
172.21.55.73 n8n.meudominio.com

# 3. Limpar cache DNS do Windows
ipconfig /flushdns

# 4. Reiniciar navegador
```

### ❌ `curl: (7) Failed to connect`

**Sintomas**: Curl falha ao conectar em domínios

**Diagnóstico**:
```bash
# Testar conectividade básica
nc -zv localhost 443
nc -zv localhost 80

# Verificar resolução DNS
ping traefik.meudominio.com

# Verificar entrada hosts
grep meudominio.com /etc/hosts
```

**Solução**:
```bash
# Se ping falha, adicionar ao hosts do WSL
echo "$(hostname -I | awk '{print $1}') traefik.meudominio.com" | sudo tee -a /etc/hosts
echo "$(hostname -I | awk '{print $1}') n8n.meudominio.com" | sudo tee -a /etc/hosts
```

---

## 🔴 Problemas de Certificados SSL

### ❌ `SSL: CERTIFICATE_VERIFY_FAILED`

**Sintomas**: Erro de certificado SSL inválido

**Diagnóstico**:
```bash
# Verificar se certificados existem
sudo ls -la /etc/letsencrypt/live/traefik.meudominio.com/
sudo ls -la /etc/letsencrypt/live/n8n.meudominio.com/

# Verificar validade
openssl x509 -in /etc/letsencrypt/live/traefik.meudominio.com/fullchain.pem -text -noout | grep "Not After"
```

**Solução**:
```bash
# Regenerar certificados
sudo certbot certonly --standalone --force-renewal -d traefik.meudominio.com
sudo certbot certonly --standalone --force-renewal -d n8n.meudominio.com

# Reiniciar Traefik
docker-compose restart traefik
```

### ❌ `Permission denied` ao acessar certificados

**Sintomas**: Traefik não consegue ler certificados

**Solução**:
```bash
# Corrigir permissões
sudo chown -R root:root /etc/letsencrypt/
sudo chmod -R 755 /etc/letsencrypt/live/
sudo chmod -R 755 /etc/letsencrypt/archive/

# Verificar se docker tem acesso
sudo ls -la /etc/letsencrypt/live/traefik.meudominio.com/
```

---

## 🔴 Problemas de DNS e Hosts

### ❌ DNS resolve para IP errado

**Sintomas**: `ping traefik.meudominio.com` retorna IP público ao invés do local

**Diagnóstico**:
```bash
# Verificar qual IP está sendo resolvido
ping -c 1 traefik.meudominio.com

# Verificar arquivo hosts
cat /etc/hosts | grep meudominio
```

**Solução**:
```bash
# Remover entradas antigas
sudo sed -i '/traefik.meudominio.com/d' /etc/hosts
sudo sed -i '/n8n.meudominio.com/d' /etc/hosts

# Adicionar IP correto
IP_WSL=$(hostname -I | awk '{print $1}')
echo "$IP_WSL traefik.meudominio.com" | sudo tee -a /etc/hosts
echo "$IP_WSL n8n.meudominio.com" | sudo tee -a /etc/hosts
```

### ❌ IP do WSL mudou após reinicializar

**Sintomas**: Funcionava antes, mas após reiniciar Windows não funciona mais

**Solução**:
```bash
# Script para atualizar hosts automaticamente
#!/bin/bash
NEW_IP=$(hostname -I | awk '{print $1}')
echo "Novo IP do WSL: $NEW_IP"

# Atualizar hosts do WSL
sudo sed -i '/traefik.meudominio.com/d' /etc/hosts
sudo sed -i '/n8n.meudominio.com/d' /etc/hosts
echo "$NEW_IP traefik.meudominio.com" | sudo tee -a /etc/hosts
echo "$NEW_IP n8n.meudominio.com" | sudo tee -a /etc/hosts

echo "⚠️  IMPORTANTE: Atualize também o hosts do Windows!"
echo "Arquivo: C:\\Windows\\System32\\drivers\\etc\\hosts"
echo "Substitua IP antigo por: $NEW_IP"
```

---

## 🔴 Problemas com Containers

### ❌ PostgreSQL não inicia

**Sintomas**: Container postgres falha ou fica unhealthy

**Diagnóstico**:
```bash
# Ver logs específicos
docker-compose logs postgres

# Verificar status
docker-compose ps postgres

# Testar conexão
docker-compose exec postgres pg_isready -U n8n_user
```

**Soluções**:

1. **Problema de permissões**:
```bash
# Remover volumes e recriar
docker-compose down -v
docker volume rm queue-mode_postgres_data
docker-compose up -d postgres
```

2. **Problema de senha**:
```bash
# Verificar variáveis de ambiente
docker-compose exec postgres env | grep POSTGRES
```

3. **Problema de espaço em disco**:
```bash
# Verificar espaço
df -h
docker system df
```

### ❌ Redis connection failed

**Sintomas**: n8n não consegue conectar ao Redis

**Diagnóstico**:
```bash
# Testar Redis
docker-compose exec redis redis-cli ping

# Testar com senha
docker-compose exec redis redis-cli -a sua_senha ping

# Verificar logs
docker-compose logs redis
```

**Solução**:
```bash
# Verificar senha no .env
grep QUEUE_BULL_REDIS_PASSWORD .env

# Reiniciar Redis
docker-compose restart redis

# Testar conexão do n8n
docker-compose logs n8n-main | grep -i redis
```

### ❌ Container fica em estado "Restarting"

**Sintomas**: Container reinicia continuamente

**Diagnóstico**:
```bash
# Ver logs detalhados
docker-compose logs --tail=50 nome_do_container

# Ver últimos eventos
docker events --filter container=queue-mode_nome_1

# Verificar recursos
docker stats
```

**Soluções**:

1. **Problema de memória**:
```bash
# Verificar uso de RAM
free -h
# Aumentar swap se necessário
```

2. **Problema de configuração**:
```bash
# Validar docker-compose
docker-compose config

# Recriar container
docker-compose up -d --force-recreate nome_do_container
```

---

## 🔴 Problemas do n8n

### ❌ n8n retorna 404

**Sintomas**: Traefik está funcionando, mas n8n retorna "404 page not found"

**Diagnóstico**:
```bash
# Verificar se rota está sendo detectada
curl -s http://localhost:8080/api/http/routers | grep n8n

# Verificar serviços
curl -s http://localhost:8080/api/http/services | grep n8n

# Testar n8n internamente
docker-compose exec n8n-main wget -qO- http://localhost:5678/
```

**Solução**:
```bash
# Verificar labels no docker-compose.yml
# Deve ter esta linha obrigatória:
# - "traefik.http.routers.n8n.service=n8n"

# Reiniciar n8n
docker-compose restart n8n-main
```

### ❌ n8n workflows não executam

**Sintomas**: Workflows ficam "pendentes" ou falham

**Diagnóstico**:
```bash
# Verificar workers
docker-compose ps | grep worker

# Ver logs dos workers  
docker-compose logs n8n-worker
docker-compose logs n8n-webhook

# Verificar Redis
docker-compose exec redis redis-cli info
```

**Solução**:
```bash
# Reiniciar todos os componentes n8n
docker-compose restart n8n-main n8n-worker n8n-webhook redis

# Verificar variável EXECUTIONS_MODE
grep EXECUTIONS_MODE .env
# Deve ser: EXECUTIONS_MODE=queue
```

---

## 🔴 Problemas do Traefik

### ❌ Traefik dashboard não carrega

**Sintomas**: Porta 8080 não responde ou retorna erro

**Diagnóstico**:
```bash
# Verificar se porta está aberta
nc -zv localhost 8080

# Verificar logs do Traefik
docker-compose logs traefik

# Verificar configuração
docker-compose exec traefik cat /etc/traefik/traefik.yml 2>/dev/null || echo "Sem arquivo de config"
```

**Solução**:
```bash
# Verificar se API insecure está habilitada no docker-compose.yml:
# - "--api.insecure=true"
# - "8080:8080"

# Reiniciar Traefik
docker-compose restart traefik
```

### ❌ Traefik não detecta serviços

**Sintomas**: API mostra poucos ou nenhum router

**Diagnóstico**:
```bash
# Verificar rede Docker
docker network ls
docker network inspect queue-mode_n8n-network

# Verificar se containers estão na mesma rede
docker-compose ps
```

**Solução**:
```bash
# Recriar rede
docker-compose down
docker-compose up -d

# Verificar labels nos containers
docker inspect queue-mode_n8n-main-1 | grep -A 10 Labels
```

---

## 🔧 Comandos de Diagnóstico

### 📊 Scripts de Verificação Rápida

```bash
#!/bin/bash
# diagnose-quick.sh - Diagnóstico rápido

echo "=== VERIFICAÇÃO RÁPIDA ==="

echo "1. Containers rodando:"
docker-compose ps --format "table {{.Name}}\t{{.Status}}"

echo -e "\n2. Portas abertas:"
nc -zv localhost 80 443 8080 2>&1 | grep -E "(succeeded|failed)"

echo -e "\n3. Resolução DNS:"
ping -c 1 traefik.$(grep DOMAIN_NAME .env | cut -d= -f2) 2>/dev/null && echo "✅ DNS OK" || echo "❌ DNS Falhou"

echo -e "\n4. Certificados:"
sudo ls /etc/letsencrypt/live/ 2>/dev/null | wc -l | xargs echo "Certificados encontrados:"

echo -e "\n5. Traefik API:"
curl -s http://localhost:8080/api/http/routers 2>/dev/null | grep -o '"name":"[^"]*"' | wc -l | xargs echo "Routers detectados:"

echo -e "\n6. Espaço em disco:"
df -h | grep -E "(Use%|/dev)"

echo -e "\nPara diagnóstico completo: ./start.sh"
```

### 📊 Log Collector

```bash
#!/bin/bash
# collect-logs.sh - Coletar logs para suporte

LOG_DIR="logs_$(date +%Y%m%d_%H%M%S)"
mkdir -p $LOG_DIR

echo "Coletando logs em $LOG_DIR..."

# Logs dos containers
docker-compose logs --no-color > $LOG_DIR/all_containers.log
docker-compose logs --no-color traefik > $LOG_DIR/traefik.log
docker-compose logs --no-color n8n-main > $LOG_DIR/n8n-main.log

# Status dos containers
docker-compose ps > $LOG_DIR/containers_status.txt

# Configuração (sem senhas)
cp docker-compose.yml $LOG_DIR/
cp .env $LOG_DIR/env_example.txt

# Informações do sistema
hostname -I > $LOG_DIR/system_ip.txt
cat /etc/hosts | grep -v "^#" > $LOG_DIR/hosts_file.txt

echo "Logs coletados em: $LOG_DIR"
echo "Compactar com: tar czf logs.tar.gz $LOG_DIR"
```

### 📊 Health Check Completo

```bash
#!/bin/bash  
# health-check.sh - Verificação completa de saúde

echo "🏥 HEALTH CHECK COMPLETO"
echo "========================"

# Função para status colorido
status() {
    if [ $1 -eq 0 ]; then
        echo "✅ $2"
    else
        echo "❌ $2"
    fi
}

# Verificar Docker
docker info >/dev/null 2>&1
status $? "Docker funcionando"

# Verificar arquivo .env
[ -f .env ]
status $? "Arquivo .env presente"

# Verificar containers
CONTAINERS_UP=$(docker-compose ps --services --filter "status=running" | wc -l)
CONTAINERS_TOTAL=$(docker-compose ps --services | wc -l)
[ $CONTAINERS_UP -eq $CONTAINERS_TOTAL ]
status $? "Todos containers rodando ($CONTAINERS_UP/$CONTAINERS_TOTAL)"

# Verificar portas
for port in 80 443 8080; do
    nc -zv localhost $port >/dev/null 2>&1
    status $? "Porta $port acessível"
done

# Verificar Traefik API
curl -s http://localhost:8080/api/rawdata >/dev/null 2>&1
status $? "Traefik API respondendo"

# Verificar certificados
DOMAIN=$(grep DOMAIN_NAME .env | cut -d= -f2)
[ -d "/etc/letsencrypt/live/traefik.$DOMAIN" ]
status $? "Certificado Traefik presente"

[ -d "/etc/letsencrypt/live/n8n.$DOMAIN" ] || [ -d "/etc/letsencrypt/live/$(grep SUBDOMAIN .env | cut -d= -f2).$DOMAIN" ]
status $? "Certificado n8n presente"

# Verificar conectividade HTTPS
curl -k -s https://traefik.$DOMAIN/api/rawdata >/dev/null 2>&1
status $? "HTTPS Traefik funcionando"

curl -k -s https://n8n.$DOMAIN/ >/dev/null 2>&1
status $? "HTTPS n8n funcionando"

echo "========================"
echo "Health check concluído!"
```

---

## 🆘 Quando Buscar Ajuda

Se mesmo após seguir este guia você ainda tiver problemas:

### 📋 Informações para incluir ao reportar problemas:

1. **Sistema operacional**: Windows 10/11 + WSL2 + Ubuntu version
2. **Versões**: `docker --version` e `docker-compose --version`
3. **Logs**: Execute `./start.sh` e copie toda a saída
4. **Configuração**: Arquivo docker-compose.yml (sem senhas!)
5. **Erro específico**: Comando executado e erro exato
6. **Logs dos containers**: `docker-compose logs serviço_com_problema`

### 📞 Onde buscar ajuda:

- 🐛 **GitHub Issues** do projeto
- 💬 **Comunidade n8n** (Discord/Forum)  
- 📖 **Documentação oficial** do Traefik
- 🔍 **Stack Overflow** com tags específicas

---

**💡 Dica**: Mantenha este arquivo sempre atualizado com novos problemas e soluções encontradas!
