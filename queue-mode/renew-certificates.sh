#!/bin/bash

# Script de Renovação de Certificados Let's Encrypt
# Para uso com n8n queue-mode + Traefik

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔄 Iniciando renovação de certificados Let's Encrypt..."

# Parar Traefik temporariamente
echo "⏸️  Parando Traefik..."
docker-compose stop traefik

# Aguardar liberação das portas
sleep 3

# Renovar certificados
echo "🔐 Renovando certificados..."
sudo certbot renew --quiet

# Reiniciar Traefik
echo "🚀 Reiniciando Traefik..."
docker-compose up -d traefik

# Aguardar inicialização
sleep 5

echo "✅ Renovação concluída!"

# Verificar certificados
echo "📋 Status dos certificados:"
sudo certbot certificates
