#!/bin/bash

# =============================================================================
# N8N QUEUE MODE - SCRIPT SIMPLIFICADO
# =============================================================================
# Versão simplificada para inicialização rápida do n8n em modo fila
# Foco: Docker e inicialização dos serviços
# =============================================================================

set -e

# Cores para output
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Funções básicas
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Verificar se comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Banner simples
show_banner() {
    echo -e "${BLUE}"
    echo "=========================================="
    echo "    🚀 N8N Queue Mode - Start Simple"
    echo "=========================================="
    echo -e "${NC}"
}

# Verificações básicas do Docker
check_docker() {
    log "Verificando Docker..."
    
    if ! command_exists docker; then
        error "Docker não está instalado"
    fi
    
    if ! docker info >/dev/null 2>&1; then
        error "Docker não está rodando"
    fi
    
    if ! command_exists docker-compose; then
        error "Docker Compose não está instalado"
    fi
    
    success "Docker OK"
}

# Verificar arquivos necessários
check_files() {
    log "Verificando arquivos..."
    
    if [[ ! -f "docker-compose.yml" ]]; then
        error "docker-compose.yml não encontrado"
    fi
    
    if [[ ! -f ".env" ]]; then
        if [[ -f ".env.example" ]]; then
            warning "Arquivo .env não encontrado, criando a partir do exemplo"
            cp ".env.example" ".env"
            warning "IMPORTANTE: Configure o arquivo .env antes de continuar!"
            exit 1
        else
            error "Arquivo .env não encontrado"
        fi
    fi
    
    success "Arquivos OK"
}

# Verificar configuração básica
check_config() {
    log "Verificando configuração básica..."
    
    source .env
    
    if [[ -z "$EXECUTIONS_MODE" ]]; then
        error "EXECUTIONS_MODE não definido no .env"
    fi
    
    if [[ "$EXECUTIONS_MODE" != "queue" ]]; then
        warning "EXECUTIONS_MODE não está definido como 'queue' (atual: $EXECUTIONS_MODE)"
    fi
    
    success "Configuração básica OK"
}

# Inicializar serviços
start_services() {
    local clean_start=${1:-false}
    
    log "Iniciando serviços..."
    
    # Limpeza se solicitada
    if [[ "$clean_start" == "true" ]]; then
        log "Parando containers existentes..."
        docker-compose down --remove-orphans >/dev/null 2>&1 || true
        success "Containers parados"
    fi
    
    # Verificar se já está rodando
    if docker-compose ps -q 2>/dev/null | grep -q .; then
        warning "Containers já estão rodando"
        read -p "Reiniciar serviços? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker-compose down >/dev/null 2>&1
        else
            log "Mantendo containers existentes"
            return 0
        fi
    fi
    
    # Iniciar infraestrutura primeiro
    log "Iniciando infraestrutura (PostgreSQL, Redis, Traefik)..."
    docker-compose up -d postgres redis traefik cloudflare-ddns
    
    # Aguardar PostgreSQL
    log "Aguardando PostgreSQL (30s)..."
    sleep 30
    
    # Iniciar n8n
    log "Iniciando serviços n8n..."
    docker-compose up -d n8n-main n8n-worker n8n-webhook
    
    success "Serviços iniciados!"
}

# Verificação rápida pós-inicialização
quick_check() {
    log "Verificação rápida..."
    
    # Aguardar um pouco
    sleep 10
    
    # Verificar containers
    local containers=("traefik" "postgres" "redis" "n8n-main" "n8n-worker" "n8n-webhook")
    local failed=0
    
    for container in "${containers[@]}"; do
        if docker-compose ps "$container" 2>/dev/null | grep -q "Up"; then
            success "$container rodando"
        else
            warning "$container não está rodando"
            ((failed++))
        fi
    done
    
    # Verificar portas básicas
    if command_exists nc; then
        if nc -z localhost 80 2>/dev/null; then
            success "Porta 80 acessível"
        else
            warning "Porta 80 não acessível"
        fi
        
        if nc -z localhost 443 2>/dev/null; then
            success "Porta 443 acessível"
        else
            warning "Porta 443 não acessível"
        fi
    fi
    
    if [[ $failed -gt 0 ]]; then
        warning "$failed container(s) com problemas"
    else
        success "Todos os containers OK!"
    fi
}

# Mostrar informações finais
show_info() {
    source .env 2>/dev/null || true
    
    echo
    echo -e "${GREEN}🎉 N8N Queue Mode iniciado!${NC}"
    echo
    echo -e "${YELLOW}URLs de acesso:${NC}"
    echo -e "  n8n:      https://${SUBDOMAIN:-n8n}.${DOMAIN_NAME:-seudominio.com}"
    echo -e "  Traefik:  https://traefik.${DOMAIN_NAME:-seudominio.com}/dashboard/"
    echo -e "  API:      http://localhost:8080/dashboard/ (desenvolvimento)"
    echo
    echo -e "${YELLOW}Comandos úteis:${NC}"
    echo -e "  Ver logs:     docker-compose logs -f [serviço]"
    echo -e "  Parar tudo:   docker-compose down"
    echo -e "  Status:       docker-compose ps"
    echo
}

# Função principal
main() {
    local clean_start=false
    
    # Processar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean|-c)
                clean_start=true
                shift
                ;;
            --help|-h)
                echo "Uso: $0 [--clean|-c] [--help|-h]"
                echo "  --clean  Reinicialização limpa"
                echo "  --help   Mostra esta ajuda"
                exit 0
                ;;
            *)
                warning "Opção desconhecida: $1"
                exit 1
                ;;
        esac
    done
    
    # Executar sequência
    show_banner
    check_docker
    check_files
    check_config
    start_services "$clean_start"
    quick_check
    show_info
}

# Interceptar Ctrl+C
trap 'echo -e "\n${YELLOW}Script interrompido${NC}"; exit 130' INT TERM

# Executar
main "$@"
