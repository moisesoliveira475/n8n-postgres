#!/bin/bash

# --- Configurações ---
TUNNEL_NAME="n8n-tunnel"
CLOUDFLARED_LOG="cloudflared.log"

# --- Funções ---

# Função para verificar se um comando existe
command_exists() {
    command -v "$1" &> /dev/null
}

# Função para realizar o cleanup e parar todos os serviços
cleanup() {
    echo ""
    echo "🛑 Parando serviços..."
    
    # Parar containers Docker
    docker-compose down
    
    # Parar o processo do túnel Cloudflare
    if [ -n "$TUNNEL_PID" ]; then
        echo "🔌 Desligando o Cloudflare Tunnel..."
        kill $TUNNEL_PID
        wait $TUNNEL_PID 2>/dev/null
    fi
    
    rm -f $CLOUDFLARED_LOG
    echo "✅ Cleanup concluído."
    exit 0
}

# --- Lógica Principal ---

# Captura de sinais para executar a função de cleanup
trap cleanup SIGINT SIGTERM

# 1. Verificar se o cloudflared está instalado
if ! command_exists cloudflared; then
    echo "❌ 'cloudflared' não está instalado. Siga o guia em 'cloudflare-guide.md'."
    exit 1
fi

# 2. Iniciar o Cloudflare Tunnel em background
echo "🚀 Iniciando Cloudflare Tunnel '$TUNNEL_NAME'..."
cloudflared tunnel run $TUNNEL_NAME > $CLOUDFLARED_LOG 2>&1 &
TUNNEL_PID=$!

sleep 4 # Dar um tempo para o túnel iniciar e logar

# Verificar se o túnel iniciou corretamente
if ! kill -0 $TUNNEL_PID 2>/dev/null || grep -q "failed to create tunnel" $CLOUDFLARED_LOG; then
    echo "❌ Cloudflare Tunnel falhou ao iniciar. Verifique sua configuração."
    echo "📋 Log do cloudflared:"
    cat $CLOUDFLARED_LOG
    exit 1
fi
echo "✅ Túnel iniciado com sucesso (PID: $TUNNEL_PID)."

# 3. Iniciar os containers Docker
echo "🐳 Iniciando containers Docker (n8n e postgres)..."
docker-compose up -d

if [ $? -ne 0 ]; then
    echo "❌ Erro ao iniciar containers Docker."
    cleanup
fi
echo "✅ Containers iniciados com sucesso."

# Extrair o host do .env para exibir a URL
PUBLIC_URL=$(grep N8N_HOST .env | cut -d '=' -f2)

echo ""
echo "🎉 Tudo pronto!"
echo "🔗 Acesse seu n8n em: https://$PUBLIC_URL"
echo ""
echo "ℹ️  Pressione Ctrl+C para parar todos os serviços (n8n, postgres e o túnel)."
echo ""

# Monitorar processos e aguardar interrupção
while true; do
    # Verificar se o túnel ainda está rodando
    if ! kill -0 $TUNNEL_PID 2>/dev/null; then
        echo "❌ O processo do Cloudflare Tunnel parou inesperadamente."
        cleanup
    fi
    
    # Verificar se os containers ainda estão rodando
    if ! docker-compose ps | grep -q "Up"; then
        echo "❌ Os containers Docker pararam inesperadamente."
        cleanup
    fi
    
    sleep 15
done