#!/bin/bash

# Script de Correção Automática de Certificados SSL
# n8n-postgres queue-mode

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Correção Automática de Certificados SSL - Queue Mode${NC}"
echo "=================================================="

# Verificar se estamos no diretório correto
if [[ ! -f "docker-compose.yml" ]] || [[ ! -f ".env" ]]; then
    echo -e "${RED}❌ Execute este script dentro do diretório queue-mode${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 Verificando configuração atual...${NC}"

# Verificar se o arquivo de configuração automática existe
if [[ ! -f "docker-compose-auto-ssl.yml" ]]; then
    echo -e "${RED}❌ Arquivo docker-compose-auto-ssl.yml não encontrado${NC}"
    echo "Execute o diagnóstico primeiro para gerar os arquivos necessários."
    exit 1
fi

# Função para perguntar ao usuário
ask_user() {
    local question="$1"
    local default="$2"
    echo -n -e "${YELLOW}$question [${default}]: ${NC}"
    read -r answer
    echo "${answer:-$default}"
}

echo ""
echo -e "${BLUE}Escolha a abordagem para certificados SSL:${NC}"
echo "1) Certificados automáticos via Traefik (RECOMENDADO)"
echo "2) Manter certificados externos via certbot"
echo "3) Configuração para teste local (HTTP)"
echo ""

choice=$(ask_user "Sua escolha" "1")

case $choice in
    1)
        echo -e "${GREEN}✅ Configurando certificados automáticos...${NC}"
        
        # Backup dos arquivos atuais
        echo "📦 Fazendo backup dos arquivos atuais..."
        cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)
        
        if [[ -f "dynamic_conf.yml" ]]; then
            mv dynamic_conf.yml dynamic_conf.yml.disabled
            echo "   • dynamic_conf.yml → dynamic_conf.yml.disabled"
        fi
        
        # Aplicar nova configuração
        cp docker-compose-auto-ssl.yml docker-compose.yml
        echo "   • docker-compose-auto-ssl.yml → docker-compose.yml"
        
        echo "🔄 Reiniciando serviços..."
        docker-compose down
        sleep 2
        docker-compose up -d
        
        echo -e "${GREEN}✅ Configuração aplicada com sucesso!${NC}"
        echo ""
        echo -e "${BLUE}🔍 Verificando certificados automáticos...${NC}"
        sleep 5
        
        echo "📋 Logs do Traefik (últimas 20 linhas):"
        docker-compose logs --tail=20 traefik
        
        echo ""
        echo -e "${GREEN}🌐 URLs disponíveis:${NC}"
        source .env
        echo "   • n8n: https://${SUBDOMAIN}.${DOMAIN_NAME}"
        echo "   • Traefik Dashboard: https://traefik.${DOMAIN_NAME}"
        ;;
        
    2)
        echo -e "${YELLOW}⚠️  Mantendo configuração atual de certificados externos${NC}"
        
        # Verificar se é ambiente local ou produção
        source .env
        echo ""
        echo -e "${BLUE}Verificando ambiente...${NC}"
        
        # Test if domain resolves publicly
        if nslookup "${SUBDOMAIN}.${DOMAIN_NAME}" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Domínio resolve publicamente${NC}"
            echo ""
            echo -e "${YELLOW}Para gerar certificados reais:${NC}"
            echo "docker-compose stop traefik"
            echo "sudo certbot certonly --standalone -d traefik.${DOMAIN_NAME}"
            echo "sudo certbot certonly --standalone -d ${SUBDOMAIN}.${DOMAIN_NAME}"
            echo "docker-compose up -d"
        else
            echo -e "${YELLOW}⚠️  Domínio não resolve publicamente (ambiente local)${NC}"
            echo ""
            echo -e "${BLUE}Para teste local, você pode:${NC}"
            echo "1) Gerar certificados auto-assinados"
            echo "2) Usar HTTP (sem SSL)"
            echo ""
            
            local_choice=$(ask_user "Gerar certificados auto-assinados? (s/n)" "s")
            if [[ "$local_choice" =~ ^[Ss]$ ]]; then
                echo "🔧 Gerando certificados auto-assinados..."
                
                sudo mkdir -p "/etc/letsencrypt/live/traefik.${DOMAIN_NAME}"
                sudo mkdir -p "/etc/letsencrypt/live/${SUBDOMAIN}.${DOMAIN_NAME}"
                
                # Gerar certificado para Traefik
                sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                  -keyout "/etc/letsencrypt/live/traefik.${DOMAIN_NAME}/privkey.pem" \
                  -out "/etc/letsencrypt/live/traefik.${DOMAIN_NAME}/fullchain.pem" \
                  -subj "/CN=traefik.${DOMAIN_NAME}" >/dev/null 2>&1
                
                # Gerar certificado para n8n
                sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                  -keyout "/etc/letsencrypt/live/${SUBDOMAIN}.${DOMAIN_NAME}/privkey.pem" \
                  -out "/etc/letsencrypt/live/${SUBDOMAIN}.${DOMAIN_NAME}/fullchain.pem" \
                  -subj "/CN=${SUBDOMAIN}.${DOMAIN_NAME}" >/dev/null 2>&1
                
                echo -e "${GREEN}✅ Certificados auto-assinados gerados${NC}"
                
                # Adicionar entradas no /etc/hosts se não existirem
                local_ip=$(hostname -I | awk '{print $1}')
                if ! grep -q "traefik.${DOMAIN_NAME}" /etc/hosts 2>/dev/null; then
                    echo "🔧 Adicionando entradas no /etc/hosts..."
                    echo "${local_ip} traefik.${DOMAIN_NAME}" | sudo tee -a /etc/hosts >/dev/null
                    echo "${local_ip} ${SUBDOMAIN}.${DOMAIN_NAME}" | sudo tee -a /etc/hosts >/dev/null
                    echo -e "${GREEN}✅ Entradas adicionadas ao /etc/hosts${NC}"
                fi
                
                echo "🔄 Reiniciando serviços..."
                docker-compose down
                sleep 2
                docker-compose up -d
            fi
        fi
        ;;
        
    3)
        echo -e "${YELLOW}🔧 Configurando para teste local (HTTP)...${NC}"
        
        # Modificar .env para HTTP
        sed -i.backup 's/N8N_PROTOCOL=https/N8N_PROTOCOL=http/' .env
        sed -i 's|WEBHOOK_URL=https://|WEBHOOK_URL=http://|' .env
        
        # Usar configuração local
        if [[ -f "docker-compose-local.yml" ]]; then
            cp docker-compose-local.yml docker-compose.yml
        else
            # Criar configuração HTTP on-the-fly
            sed 's/443:443/#443:443/' docker-compose.yml > docker-compose-http.yml
            sed -i 's/websecure/web/' docker-compose-http.yml
            sed -i '/tls\./d' docker-compose-http.yml
            cp docker-compose-http.yml docker-compose.yml
        fi
        
        echo "🔄 Reiniciando serviços..."
        docker-compose down
        sleep 2
        docker-compose up -d
        
        source .env
        echo -e "${GREEN}✅ Configuração HTTP aplicada${NC}"
        echo ""
        echo -e "${GREEN}🌐 URLs disponíveis (HTTP):${NC}"
        echo "   • n8n: http://${SUBDOMAIN}.${DOMAIN_NAME}"
        echo "   • Traefik Dashboard: http://traefik.${DOMAIN_NAME}:8080"
        ;;
        
    *)
        echo -e "${RED}❌ Opção inválida${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}🔍 Status dos serviços:${NC}"
docker-compose ps

echo ""
echo -e "${GREEN}✅ Correção concluída!${NC}"
echo ""
echo -e "${YELLOW}💡 Dicas:${NC}"
echo "   • Use 'docker-compose logs -f traefik' para monitorar certificados"
echo "   • Use 'docker-compose logs -f n8n-main' para logs do n8n"
echo "   • Execute './start.sh' para diagnósticos completos"
