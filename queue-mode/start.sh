#!/bin/bash

# =============================================================================
# N8N QUEUE MODE STARTUP SCRIPT
# =============================================================================
# Script para inicialização completa do n8n em modo fila com Traefik
# Projeto: n8n Queue Mode com Traefik Reverse Proxy
# Compatível: WSL2/Ubuntu/Debian/CentOS
# Versão: 2.0
# =============================================================================

set -e  # Parar execução em caso de erro

# =============================================================================
# CONFIGURAÇÕES E CORES
# =============================================================================

# Cores para output formatado
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Configurações do script
readonly SCRIPT_NAME="N8N Queue Mode Startup"
readonly SCRIPT_VERSION="2.0"
readonly PROJECT_NAME="n8n-queue-mode"

# Arquivos necessários
readonly REQUIRED_FILES=("docker-compose.yml" ".env" "dynamic_conf.yml")
readonly EXAMPLE_FILES=(".env.example" "dynamic_conf.yml.example")

# =============================================================================
# FUNÇÕES UTILITÁRIAS
# =============================================================================

# Função para logging com timestamp
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Função para mensagens de sucesso
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Função para avisos
warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Função para erros (sem exit)
error_msg() {
    echo -e "${RED}❌ $1${NC}"
}

# Função para erros fatais (com exit)
fatal_error() {
    echo -e "${RED}💥 ERRO FATAL: $1${NC}"
    echo -e "${RED}Execução interrompida.${NC}"
    exit 1
}

# Função para títulos de seção
section() {
    echo
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE} $1${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo
}

# Função para perguntar confirmação
confirm() {
    read -p "$(echo -e "${YELLOW}$1 (y/N): ${NC}")" -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Função para verificar se comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Função para aguardar com spinner
wait_with_spinner() {
    local pid=$1
    local message=$2
    local spin='-\|/'
    local i=0
    
    echo -n "$message "
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r$message ${spin:$i:1}"
        sleep 0.1
    done
    printf "\r$message ✅\n"
}

# =============================================================================
# BANNER E INFORMAÇÕES
# =============================================================================

show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
 ╔═══════════════════════════════════════════════════════════════╗
 ║                                                               ║
 ║                🚀 N8N QUEUE MODE STARTUP 🚀                  ║
 ║                                                               ║
 ║               Traefik + n8n + PostgreSQL + Redis             ║
 ║                     Produção & Desenvolvimento               ║
 ║                                                               ║
 ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo -e "${WHITE}Versão:${NC} $SCRIPT_VERSION"
    echo -e "${WHITE}Projeto:${NC} $PROJECT_NAME" 
    echo -e "${WHITE}Compatibilidade:${NC} WSL2, Ubuntu, Debian, CentOS"
    echo -e "${WHITE}Data:${NC} $(date +'%d/%m/%Y %H:%M:%S')"
    echo
}

# Função para mostrar ajuda
show_help() {
    echo -e "${WHITE}Uso:${NC} $0 [OPÇÕES]"
    echo
    echo -e "${WHITE}Opções:${NC}"
    echo -e "  ${GREEN}--help, -h${NC}          Mostra esta ajuda"
    echo -e "  ${GREEN}--clean, -c${NC}         Inicialização limpa (remove containers/volumes)"
    echo -e "  ${GREEN}--monitor, -m${NC}       Inicia com monitoramento de logs em tempo real"
    echo -e "  ${GREEN}--quick, -q${NC}         Inicialização rápida (pula algumas verificações)"
    echo -e "  ${GREEN}--setup${NC}             Modo setup inicial (cria arquivos exemplo)"
    echo -e "  ${GREEN}--health${NC}            Verificação de saúde completa"
    echo -e "  ${GREEN}--logs [serviço]${NC}    Mostra logs de um serviço específico"
    echo
    echo -e "${WHITE}Exemplos:${NC}"
    echo -e "  $0                     # Inicialização normal"
    echo -e "  $0 --clean             # Inicialização limpa"
    echo -e "  $0 --setup             # Configuração inicial"
    echo -e "  $0 --health            # Verificação de saúde"
    echo -e "  $0 --logs traefik      # Logs do Traefik"
    echo
    exit 0
}

# =============================================================================
# VERIFICAÇÕES DE PRÉ-REQUISITOS
# =============================================================================

check_prerequisites() {
    section "VERIFICANDO PRÉ-REQUISITOS"
    
    local errors=0
    
    # Verificar sistema operacional
    log "Verificando sistema operacional..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command_exists lsb_release; then
            local distro=$(lsb_release -si)
            local version=$(lsb_release -sr)
            success "Sistema: $distro $version"
        else
            success "Sistema: Linux (genérico)"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        success "Sistema: macOS"
    else
        warning "Sistema não testado: $OSTYPE"
    fi
    
    # Verificar Docker
    log "Verificando Docker..."
    if command_exists docker; then
        if docker info >/dev/null 2>&1; then
            local docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
            success "Docker $docker_version funcionando"
        else
            error_msg "Docker não está rodando"
            ((errors++))
        fi
    else
        error_msg "Docker não está instalado"
        ((errors++))
    fi
    
    # Verificar Docker Compose
    log "Verificando Docker Compose..."
    if command_exists docker-compose; then
        local compose_version=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
        success "Docker Compose $compose_version disponível"
    else
        error_msg "Docker Compose não está instalado"
        ((errors++))
    fi
    
    # Verificar utilitários essenciais
    log "Verificando utilitários..."
    local utils=("curl" "wget" "nc" "openssl")
    for util in "${utils[@]}"; do
        if command_exists "$util"; then
            success "$util disponível"
        else
            warning "$util não encontrado (recomendado)"
        fi
    done
    
    # Verificar diretório
    log "Verificando diretório do projeto..."
    if [[ -f "docker-compose.yml" ]]; then
        success "Diretório do projeto confirmado"
    else
        fatal_error "docker-compose.yml não encontrado. Execute este script no diretório do projeto."
    fi
    
    if [[ $errors -gt 0 ]]; then
        fatal_error "$errors erro(s) encontrado(s). Corrija antes de continuar."
    fi
}

# =============================================================================
# CONFIGURAÇÃO INICIAL
# =============================================================================

setup_initial_config() {
    section "CONFIGURAÇÃO INICIAL"
    
    log "Criando arquivos de configuração a partir dos exemplos..."
    
    # Copiar .env.example se .env não existir
    if [[ ! -f ".env" ]] && [[ -f ".env.example" ]]; then
        cp ".env.example" ".env"
        success "Arquivo .env criado a partir do exemplo"
        warning "IMPORTANTE: Edite o arquivo .env com suas configurações!"
    fi
    
    # Copiar dynamic_conf.yml.example se não existir
    if [[ ! -f "dynamic_conf.yml" ]] && [[ -f "dynamic_conf.yml.example" ]]; then
        cp "dynamic_conf.yml.example" "dynamic_conf.yml"
        success "Arquivo dynamic_conf.yml criado a partir do exemplo"
        warning "IMPORTANTE: Configure seus domínios no dynamic_conf.yml!"
    fi
    
    echo
    echo -e "${YELLOW}Próximos passos:${NC}"
    echo -e "1. Edite o arquivo ${WHITE}.env${NC} com suas configurações"
    echo -e "2. Configure o arquivo ${WHITE}dynamic_conf.yml${NC} com seus domínios"
    echo -e "3. Execute este script novamente: ${WHITE}./start.sh${NC}"
    echo
    exit 0
}

# =============================================================================
# VERIFICAÇÃO DE CONFIGURAÇÃO
# =============================================================================

check_configuration() {
    section "VERIFICANDO CONFIGURAÇÃO"
    
    local errors=0
    
    # Verificar arquivos necessários
    log "Verificando arquivos de configuração..."
    for file in "${REQUIRED_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            success "Arquivo $file encontrado"
        else
            error_msg "Arquivo $file não encontrado"
            ((errors++))
        fi
    done
    
    # Verificar .env
    if [[ -f ".env" ]]; then
        log "Verificando variáveis de ambiente..."
        source .env
        
        local required_vars=(
            "DOMAIN_NAME"
            "SUBDOMAIN"
            "POSTGRES_USER"
            "POSTGRES_PASSWORD"
            "POSTGRES_DB"
            "N8N_ENCRYPTION_KEY"
            "QUEUE_BULL_REDIS_PASSWORD"
            "EXECUTIONS_MODE"
        )
        
        for var in "${required_vars[@]}"; do
            if [[ -n "${!var}" ]]; then
                success "Variável $var configurada"
            else
                error_msg "Variável $var não está definida"
                ((errors++))
            fi
        done
        
        # Verificar modo queue
        if [[ "$EXECUTIONS_MODE" == "queue" ]]; then
            success "Modo queue configurado corretamente"
        else
            warning "EXECUTIONS_MODE não está definido como 'queue' (atual: $EXECUTIONS_MODE)"
        fi
        
        # Verificar tamanho da chave de criptografia
        if [[ ${#N8N_ENCRYPTION_KEY} -ge 10 ]]; then
            success "Chave de criptografia tem tamanho adequado"
        else
            error_msg "Chave de criptografia muito curta (mínimo 10 caracteres)"
            ((errors++))
        fi
    else
        fatal_error "Arquivo .env não encontrado. Execute './start.sh --setup' primeiro."
    fi
    
    if [[ $errors -gt 0 ]]; then
        echo
        warning "$errors erro(s) de configuração encontrado(s)."
        if confirm "Deseja continuar mesmo assim?"; then
            warning "Continuando com erros de configuração..."
        else
            fatal_error "Execução cancelada pelo usuário."
        fi
    fi
}

# =============================================================================
# VERIFICAÇÃO DE REDE E CERTIFICADOS
# =============================================================================

check_network_and_certificates() {
    section "VERIFICANDO REDE E CERTIFICADOS"
    
    # Carregar variáveis
    source .env
    
    # Verificar resolução DNS
    log "Verificando resolução DNS..."
    if command_exists ping; then
        if ping -c 1 "traefik.${DOMAIN_NAME}" >/dev/null 2>&1; then
            success "DNS do Traefik resolve: traefik.${DOMAIN_NAME}"
        else
            warning "DNS do Traefik não resolve: traefik.${DOMAIN_NAME}"
        fi
        
        if ping -c 1 "${SUBDOMAIN}.${DOMAIN_NAME}" >/dev/null 2>&1; then
            success "DNS do n8n resolve: ${SUBDOMAIN}.${DOMAIN_NAME}"
        else
            warning "DNS do n8n não resolve: ${SUBDOMAIN}.${DOMAIN_NAME}"
        fi
    else
        warning "Comando ping não disponível - pulando verificação DNS"
    fi
    
    # Verificar /etc/hosts
    log "Verificando arquivo /etc/hosts..."
    if grep -q "traefik.${DOMAIN_NAME}" /etc/hosts 2>/dev/null; then
        success "Entrada no /etc/hosts para Traefik encontrada"
    else
        warning "Entrada no /etc/hosts para Traefik não encontrada"
        local local_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "IP_LOCAL")
        echo -e "   ${CYAN}Sugestão:${NC} echo \"$local_ip traefik.${DOMAIN_NAME}\" | sudo tee -a /etc/hosts"
    fi
    
    if grep -q "${SUBDOMAIN}.${DOMAIN_NAME}" /etc/hosts 2>/dev/null; then
        success "Entrada no /etc/hosts para n8n encontrada"
    else
        warning "Entrada no /etc/hosts para n8n não encontrada"
        local local_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "IP_LOCAL")
        echo -e "   ${CYAN}Sugestão:${NC} echo \"$local_ip ${SUBDOMAIN}.${DOMAIN_NAME}\" | sudo tee -a /etc/hosts"
    fi
    
    # Verificar certificados SSL
    log "Verificando certificados SSL..."
    local cert_traefik="/etc/letsencrypt/live/traefik.${DOMAIN_NAME}"
    local cert_n8n="/etc/letsencrypt/live/${SUBDOMAIN}.${DOMAIN_NAME}"
    
    if [[ -d "$cert_traefik" ]]; then
        success "Certificado do Traefik encontrado"
        if command_exists openssl; then
            local expiry=$(sudo openssl x509 -in "$cert_traefik/fullchain.pem" -noout -enddate 2>/dev/null | cut -d= -f2 || echo "Desconhecido")
            echo -e "   ${CYAN}Expira em:${NC} $expiry"
        fi
    else
        warning "Certificado do Traefik não encontrado em: $cert_traefik"
        echo -e "   ${CYAN}Gerar com:${NC} sudo certbot certonly --standalone -d traefik.${DOMAIN_NAME}"
    fi
    
    if [[ -d "$cert_n8n" ]]; then
        success "Certificado do n8n encontrado"
        if command_exists openssl; then
            local expiry=$(sudo openssl x509 -in "$cert_n8n/fullchain.pem" -noout -enddate 2>/dev/null | cut -d= -f2 || echo "Desconhecido")
            echo -e "   ${CYAN}Expira em:${NC} $expiry"
        fi
    else
        warning "Certificado do n8n não encontrado em: $cert_n8n"
        echo -e "   ${CYAN}Gerar com:${NC} sudo certbot certonly --standalone -d ${SUBDOMAIN}.${DOMAIN_NAME}"
    fi
}

# =============================================================================
# INICIALIZAÇÃO DOS SERVIÇOS
# =============================================================================

start_services() {
    section "INICIALIZANDO SERVIÇOS"
    
    local clean_start=${1:-false}
    
    # Limpeza se solicitada
    if [[ "$clean_start" == "true" ]]; then
        log "Executando limpeza completa..."
        docker-compose down --remove-orphans >/dev/null 2>&1 || true
        if confirm "Remover volumes de dados? (PERDERÁ TODOS OS DADOS)"; then
            docker-compose down -v >/dev/null 2>&1 || true
            docker volume prune -f >/dev/null 2>&1 || true
            success "Volumes removidos"
        fi
        success "Limpeza concluída"
    fi
    
    # Verificar se containers já estão rodando
    if docker-compose ps -q 2>/dev/null | grep -q .; then
        warning "Containers já estão rodando"
        if confirm "Deseja reiniciar os serviços?"; then
            log "Parando containers existentes..."
            docker-compose down >/dev/null 2>&1
            success "Containers parados"
        else
            warning "Mantendo containers existentes"
            return 0
        fi
    fi
    
    # Inicializar infraestrutura primeiro
    log "Iniciando infraestrutura (PostgreSQL, Redis, Traefik)..."
    docker-compose up -d postgres redis traefik cloudflare-ddns
    
    # Aguardar PostgreSQL ficar saudável
    log "Aguardando PostgreSQL ficar saudável..."
    local timeout=60
    local counter=0
    
    while [[ $counter -lt $timeout ]]; do
        if docker-compose ps postgres 2>/dev/null | grep -q "healthy"; then
            success "PostgreSQL está saudável"
            break
        fi
        echo -n "."
        sleep 2
        counter=$((counter + 2))
    done
    
    if [[ $counter -ge $timeout ]]; then
        fatal_error "PostgreSQL não ficou saudável em ${timeout}s"
    fi
    
    # Inicializar serviços n8n
    log "Iniciando serviços n8n..."
    docker-compose up -d n8n-main n8n-worker n8n-webhook
    
    # Aguardar serviços ficarem prontos
    log "Aguardando serviços ficarem prontos..."
    sleep 10
    
    success "Todos os serviços foram iniciados!"
}

# =============================================================================
# VERIFICAÇÕES PÓS-INICIALIZAÇÃO
# =============================================================================

post_startup_checks() {
    section "VERIFICAÇÕES PÓS-INICIALIZAÇÃO"
    
    # Verificar status dos containers
    log "Verificando status dos containers..."
    local containers=("traefik" "postgres" "redis" "n8n-main" "n8n-worker" "n8n-webhook" "cloudflare-ddns")
    local failed_containers=()
    
    for container in "${containers[@]}"; do
        if docker-compose ps "$container" 2>/dev/null | grep -q "Up"; then
            success "Container $container está rodando"
        else
            error_msg "Container $container não está rodando"
            failed_containers+=("$container")
        fi
    done
    
    # Verificar conectividade das portas
    log "Verificando conectividade das portas..."
    local ports=(80 443)
    if command_exists nc; then
        for port in "${ports[@]}"; do
            if nc -z localhost "$port" 2>/dev/null; then
                success "Porta $port acessível"
            else
                error_msg "Porta $port não acessível"
            fi
        done
        
        # Verificar porta 8080 (Traefik API)
        if nc -z localhost 8080 2>/dev/null; then
            success "Porta 8080 (Traefik API) acessível"
        else
            warning "Porta 8080 (Traefik API) não acessível"
        fi
    else
        warning "Comando nc não disponível - pulando verificação de portas"
    fi
    
    # Verificar API do Traefik
    if command_exists curl; then
        log "Verificando API do Traefik..."
        if curl -s http://localhost:8080/api/http/routers >/dev/null 2>&1; then
            local router_count=$(curl -s http://localhost:8080/api/http/routers 2>/dev/null | grep -o '"name":"[^"]*"' | wc -l)
            success "Traefik API acessível - $router_count routers detectados"
            
            if curl -s http://localhost:8080/api/http/routers 2>/dev/null | grep -q "n8n@docker"; then
                success "Rota do n8n detectada pelo Traefik"
            else
                warning "Rota do n8n não detectada pelo Traefik"
            fi
        else
            warning "Traefik API não acessível"
        fi
    fi
    
    # Testes de conectividade HTTPS (se curl disponível)
    if command_exists curl && [[ -f ".env" ]]; then
        source .env
        log "Testando conectividade HTTPS..."
        
        if curl -k -s --max-time 5 "https://traefik.${DOMAIN_NAME}/api/rawdata" >/dev/null 2>&1; then
            success "HTTPS Traefik funcionando"
        else
            warning "HTTPS Traefik não acessível"
        fi
        
        if curl -k -s --max-time 5 "https://${SUBDOMAIN}.${DOMAIN_NAME}/" >/dev/null 2>&1; then
            success "HTTPS n8n funcionando"
        else
            warning "HTTPS n8n não acessível"
        fi
    fi
    
    # Resumo
    if [[ ${#failed_containers[@]} -gt 0 ]]; then
        warning "Alguns containers falharam: ${failed_containers[*]}"
        echo -e "${YELLOW}Execute 'docker-compose logs <container>' para ver os logs${NC}"
    else
        success "Todos os containers estão funcionando!"
    fi
}

# =============================================================================
# RELATÓRIO FINAL
# =============================================================================

show_final_report() {
    section "RELATÓRIO FINAL"
    
    source .env 2>/dev/null || true
    
    echo -e "${GREEN}"
    cat << "EOF"
 ╔═══════════════════════════════════════════════════════════════╗
 ║                     ✅ INICIALIZAÇÃO CONCLUÍDA ✅             ║
 ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo -e "${WHITE}🌐 URLs de Acesso:${NC}"
    echo -e "   📊 Dashboard Traefik: ${GREEN}https://traefik.${DOMAIN_NAME:-SEUDOMINIO.com}/dashboard/${NC}"
    echo -e "   🔧 n8n Interface:     ${GREEN}https://${SUBDOMAIN:-n8n}.${DOMAIN_NAME:-SEUDOMINIO.com}/${NC}"
    echo -e "   🛠️  Traefik API:       ${GREEN}http://localhost:8080/dashboard/${NC} ${YELLOW}(desenvolvimento)${NC}"
    echo
    
    echo -e "${WHITE}🔐 Credenciais:${NC}"
    echo -e "   👤 Traefik Dashboard: ${YELLOW}admin / sua_senha_configurada${NC}"
    echo
    
    echo -e "${WHITE}📊 Status dos Serviços:${NC}"
    if command_exists docker-compose; then
        docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || \
        docker-compose ps 2>/dev/null || \
        echo "   Não foi possível obter status dos containers"
    fi
    echo
    
    echo -e "${WHITE}📝 Comandos Úteis:${NC}"
    echo -e "   📋 Ver logs:           ${YELLOW}docker-compose logs -f [serviço]${NC}"
    echo -e "   🔄 Reiniciar serviço:  ${YELLOW}docker-compose restart [serviço]${NC}"
    echo -e "   ⏹️  Parar tudo:         ${YELLOW}docker-compose down${NC}"
    echo -e "   🔍 Status:             ${YELLOW}docker-compose ps${NC}"
    echo -e "   🏥 Health check:       ${YELLOW}./start.sh --health${NC}"
    echo
    
    echo -e "${WHITE}📚 Documentação:${NC}"
    echo -e "   📖 README completo:    ${YELLOW}cat README.md${NC}"
    echo -e "   🚨 Troubleshooting:    ${YELLOW}cat TROUBLESHOOTING.md${NC}"
    echo -e "   📊 Diagnósticos:       ${YELLOW}cat diagnostics.md${NC} ${YELLOW}(se existir)${NC}"
    echo
    
    if [[ -f "README.md" ]]; then
        success "Para troubleshooting detalhado, consulte README.md e TROUBLESHOOTING.md"
    fi
    
    echo -e "${GREEN}🎉 n8n Queue Mode está pronto para uso!${NC}"
    echo
}

# =============================================================================
# FUNÇÕES ESPECIAIS
# =============================================================================

# Health check completo
health_check() {
    section "VERIFICAÇÃO DE SAÚDE COMPLETA"
    
    local issues=0
    
    # Verificar Docker
    if ! docker info >/dev/null 2>&1; then
        error_msg "Docker não está funcionando"
        ((issues++))
    fi
    
    # Verificar containers
    if command_exists docker-compose; then
        local running=$(docker-compose ps --services --filter "status=running" 2>/dev/null | wc -l)
        local total=$(docker-compose ps --services 2>/dev/null | wc -l)
        
        if [[ $running -eq $total ]] && [[ $total -gt 0 ]]; then
            success "Todos os containers estão rodando ($running/$total)"
        else
            error_msg "Nem todos os containers estão rodando ($running/$total)"
            ((issues++))
        fi
    fi
    
    # Verificar portas
    if command_exists nc; then
        for port in 80 443; do
            if nc -z localhost "$port" 2>/dev/null; then
                success "Porta $port acessível"
            else
                error_msg "Porta $port não acessível"
                ((issues++))
            fi
        done
    fi
    
    # Verificar API Traefik
    if command_exists curl; then
        if curl -s http://localhost:8080/api/rawdata >/dev/null 2>&1; then
            success "API Traefik funcionando"
        else
            error_msg "API Traefik não responde"
            ((issues++))
        fi
    fi
    
    # Verificar espaço em disco
    if command_exists df; then
        local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
        if [[ $disk_usage -lt 90 ]]; then
            success "Espaço em disco OK ($disk_usage% usado)"
        else
            warning "Pouco espaço em disco ($disk_usage% usado)"
        fi
    fi
    
    # Resumo
    echo
    if [[ $issues -eq 0 ]]; then
        success "Health check passou! Sistema funcionando normalmente."
    else
        error_msg "Health check encontrou $issues problema(s)."
        echo -e "${YELLOW}Execute './start.sh --logs' para investigar problemas.${NC}"
    fi
    
    exit $issues
}

# Mostrar logs
show_logs() {
    local service=${1:-""}
    
    if [[ -n "$service" ]]; then
        section "LOGS DO SERVIÇO: $service"
        if docker-compose ps --services 2>/dev/null | grep -q "^$service$"; then
            docker-compose logs -f --tail=50 "$service"
        else
            fatal_error "Serviço '$service' não encontrado"
        fi
    else
        section "LOGS DE TODOS OS SERVIÇOS"
        echo -e "${YELLOW}Pressione Ctrl+C para sair${NC}"
        sleep 2
        docker-compose logs -f --tail=20
    fi
}

# =============================================================================
# PROCESSAMENTO DE ARGUMENTOS
# =============================================================================

parse_arguments() {
    local clean_start=false
    local quick_mode=false
    local monitor_mode=false
    local setup_mode=false
    local health_mode=false
    local logs_service=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                ;;
            --clean|-c)
                clean_start=true
                shift
                ;;
            --quick|-q)
                quick_mode=true
                shift
                ;;
            --monitor|-m)
                monitor_mode=true
                shift
                ;;
            --setup)
                setup_mode=true
                shift
                ;;
            --health)
                health_mode=true
                shift
                ;;
            --logs)
                logs_service=${2:-""}
                shift 2
                ;;
            *)
                warning "Opção desconhecida: $1"
                show_help
                ;;
        esac
    done
    
    # Executar modo especial se solicitado
    if [[ "$setup_mode" == "true" ]]; then
        show_banner
        setup_initial_config
        exit 0
    fi
    
    if [[ "$health_mode" == "true" ]]; then
        show_banner
        health_check
        exit 0
    fi
    
    if [[ -n "$logs_service" ]] || [[ "$monitor_mode" == "true" ]]; then
        show_logs "$logs_service"
        exit 0
    fi
    
    # Executar fluxo principal
    show_banner
    
    # Verificações (pode ser pulada em modo rápido)
    if [[ "$quick_mode" != "true" ]]; then
        check_prerequisites
        check_configuration
        check_network_and_certificates
    else
        log "Modo rápido ativado - pulando verificações detalhadas"
        check_prerequisites
    fi
    
    # Inicializar serviços
    start_services "$clean_start"
    
    # Verificações pós-inicialização
    if [[ "$quick_mode" != "true" ]]; then
        post_startup_checks
    fi
    
    # Relatório final
    show_final_report
    
    # Monitoramento se solicitado
    if [[ "$monitor_mode" == "true" ]]; then
        echo
        log "Iniciando monitoramento em tempo real..."
        echo -e "${YELLOW}Pressione Ctrl+C para sair do monitoramento${NC}"
        sleep 3
        docker-compose logs -f
    fi
}

# =============================================================================
# MAIN - ENTRADA PRINCIPAL
# =============================================================================

main() {
    # Verificar se está executando como root (não recomendado)
    if [[ $EUID -eq 0 ]]; then
        warning "Executando como root não é recomendado para este script"
        if ! confirm "Deseja continuar mesmo assim?"; then
            fatal_error "Execução cancelada"
        fi
    fi
    
    # Processar argumentos e executar
    parse_arguments "$@"
}

# Interceptar sinais para limpeza
trap 'echo -e "\n${YELLOW}Script interrompido pelo usuário${NC}"; exit 130' INT TERM

# Executar função principal
main "$@"