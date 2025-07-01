#!/bin/bash

# Script para automatizar ngrok com n8n
# Usage: ./start-n8n-ngrok.sh [subdomain]

SUBDOMAIN=${1:-""}
ENV_FILE=".env"
COMPOSE_FILE="docker-compose.yml"

echo "🚀 Iniciando n8n com ngrok..."

# Verificar se ngrok está instalado
if ! command -v ngrok &> /dev/null; then
    echo "❌ ngrok não está instalado. Instale em: https://ngrok.com/download"
    exit 1
fi

# Verificar se ngrok está configurado (tem authtoken)
if ! ngrok config check &> /dev/null; then
    echo "⚠️  ngrok pode não estar configurado corretamente"
    echo "💡 Execute: ngrok config add-authtoken <seu-token>"
    echo "🔗 Obtenha seu token em: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo ""
    echo "🚀 Continuando mesmo assim (modo free)..."
fi

# Iniciar ngrok em background
echo "📡 Iniciando ngrok tunnel..."
if [ -n "$SUBDOMAIN" ]; then
    echo "🏷️  Usando subdomínio: $SUBDOMAIN"
    ngrok http --subdomain="$SUBDOMAIN" 5678 > ngrok.log 2>&1 &
else
    echo "🎲 Usando subdomínio aleatório"
    ngrok http 5678 > ngrok.log 2>&1 &
fi

NGROK_PID=$!
echo "🔗 ngrok PID: $NGROK_PID"

# Verificar se o processo ngrok está rodando
sleep 2
if ! kill -0 $NGROK_PID 2>/dev/null; then
    echo "❌ ngrok falhou ao iniciar"
    echo "📋 Log do ngrok:"
    cat ngrok.log 2>/dev/null || echo "Nenhum log disponível"
    exit 1
fi

# Aguardar ngrok inicializar
sleep 5

# Obter URL do ngrok (sem dependência do jq)
echo "🔍 Obtendo URL do ngrok..."
NGROK_URL=""
for i in {1..10}; do
    RESPONSE=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$RESPONSE" ]; then
        # Extrair URL usando grep e sed (sem jq)
        NGROK_URL=$(echo "$RESPONSE" | grep -o '"public_url":"https://[^"]*' | head -1 | sed 's/"public_url":"https:\/\///' | sed 's/"//')
        if [ -n "$NGROK_URL" ] && [ "$NGROK_URL" != "null" ]; then
            break
        fi
    fi
    echo "⏳ Tentativa $i/10 - aguardando ngrok..."
    sleep 2
done

if [ -z "$NGROK_URL" ] || [ "$NGROK_URL" = "null" ]; then
    echo "❌ Erro ao obter URL do ngrok após 10 tentativas"
    echo "🔧 Verifique se o ngrok está funcionando:"
    echo "   - Acesse: http://localhost:4040"
    echo "   - Ou execute: curl http://localhost:4040/api/tunnels"
    kill $NGROK_PID
    exit 1
fi

echo "🌐 URL do ngrok: https://$NGROK_URL"

# Atualizar arquivo .env
echo "📝 Atualizando arquivo .env..."
sed -i "s/N8N_HOST=.*/N8N_HOST=$NGROK_URL/" "$ENV_FILE"
sed -i "s|WEBHOOK_URL=.*|WEBHOOK_URL=https://$NGROK_URL/|" "$ENV_FILE"
sed -i "s|N8N_EDITOR_BASE_URL=.*|N8N_EDITOR_BASE_URL=https://$NGROK_URL|" "$ENV_FILE"

echo "✅ Arquivo .env atualizado!"

# Função para cleanup
cleanup() {
    echo "🛑 Parando serviços..."
    docker-compose down
    kill $NGROK_PID 2>/dev/null
    rm -f ngrok.log
    echo "✅ Cleanup concluído"
    exit 0
}

# Capturar sinais para cleanup
trap cleanup SIGINT SIGTERM

# Iniciar docker-compose
echo "🐳 Iniciando containers Docker..."
docker-compose up -d

if [ $? -eq 0 ]; then
    echo "✅ n8n iniciado com sucesso!"
    echo "🌐 Acesse: https://$NGROK_URL"
    echo "📊 ngrok dashboard: http://localhost:4040"
    echo ""
    echo "Pressione Ctrl+C para parar todos os serviços"
    
    # Manter script rodando
    while true; do
        sleep 30
        # Verificar se ngrok ainda está rodando
        if ! kill -0 $NGROK_PID 2>/dev/null; then
            echo "❌ ngrok parou de funcionar"
            cleanup
        fi
        
        # Verificar se containers estão rodando
        if ! docker-compose ps | grep -q "Up"; then
            echo "❌ Containers pararam de funcionar"
            cleanup
        fi
    done
else
    echo "❌ Erro ao iniciar containers"
    kill $NGROK_PID
    exit 1
fi
