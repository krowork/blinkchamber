#!/bin/bash

# scripts/lib/common.sh - Funciones comunes para scripts de blinkchamber

# Configurar colores
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# Variables globales
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export CONFIG_FILE="$PROJECT_ROOT/config/blinkchamber.yaml"

# Función para logs con timestamp
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Función para mensajes de éxito
success() {
    echo -e "${GREEN}✅${NC} $1"
}

# Función para mensajes de error
error() {
    echo -e "${RED}❌${NC} $1"
}

# Función para warnings
warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

# Función para información
info() {
    echo -e "${CYAN}ℹ️${NC} $1"
}

# Función para debug (solo si DEBUG=true)
debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${PURPLE}🐛${NC} $1"
    fi
}

# Función para mostrar progress
progress() {
    echo -e "${BLUE}🔄${NC} $1"
}

# Función para mostrar ayuda genérica
show_help() {
    local script_name=$(basename "$0")
    cat << EOF
🚀 blinkchamber - Sistema de gestión de identidad y secretos autocontenido

Uso: $script_name [opciones]

Opciones comunes:
  -h, --help     Mostrar esta ayuda
  -v, --verbose  Modo verbose
  -d, --debug    Modo debug
  --dry-run      Simular sin ejecutar cambios

Variables de entorno:
  VERBOSE=true   Habilitar modo verbose
  DEBUG=true     Habilitar modo debug
  DRY_RUN=true   Simular sin ejecutar

EOF
}

# Función para verificar si el comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para verificar requisitos básicos
check_basic_requirements() {
    log "🔍 Verificando requisitos básicos..."
    
    local missing=0
    local required_tools=("docker" "kubectl" "kind" "terraform" "helm" "jq")
    
    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            error "Falta herramienta requerida: $tool"
            missing=$((missing + 1))
        else
            debug "$tool encontrado: $(command -v "$tool")"
        fi
    done
    
    # Verificar Docker daemon
    if ! docker info >/dev/null 2>&1; then
        error "Docker daemon no está ejecutándose"
        missing=$((missing + 1))
    fi
    
    if [[ $missing -eq 0 ]]; then
        success "Requisitos básicos verificados"
        return 0
    else
        error "Faltan $missing requisitos básicos"
        return 1
    fi
}

# Función para verificar puertos
check_port() {
    local port=$1
    local host=${2:-localhost}
    
    if command_exists nc; then
        nc -z "$host" "$port" >/dev/null 2>&1
    elif command_exists telnet; then
        timeout 5 telnet "$host" "$port" >/dev/null 2>&1
    else
        # Fallback usando /dev/tcp
        timeout 5 bash -c "echo >/dev/tcp/$host/$port" >/dev/null 2>&1
    fi
}

# Función para esperar que un puerto esté disponible
wait_for_port() {
    local port=$1
    local host=${2:-localhost}
    local timeout=${3:-300}
    local interval=${4:-5}
    
    progress "Esperando puerto $port en $host..."
    
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if check_port "$port" "$host"; then
            success "Puerto $port está disponible"
            return 0
        fi
        
        debug "Puerto $port no disponible, reintentando en ${interval}s..."
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    
    error "Timeout esperando puerto $port después de ${timeout}s"
    return 1
}

# Función para verificar variable de entorno
check_env_var() {
    local var_name=$1
    local default_value=$2
    
    if [[ -z "${!var_name:-}" ]]; then
        if [[ -n "$default_value" ]]; then
            debug "Variable $var_name no definida, usando valor por defecto: $default_value"
            export "$var_name"="$default_value"
        else
            error "Variable de entorno requerida no definida: $var_name"
            return 1
        fi
    else
        debug "Variable $var_name definida: ${!var_name}"
    fi
    return 0
}

# Función para verificar archivo
check_file() {
    local file_path=$1
    local description=${2:-"archivo"}
    
    if [[ ! -f "$file_path" ]]; then
        error "$description no encontrado: $file_path"
        return 1
    else
        debug "$description encontrado: $file_path"
        return 0
    fi
}

# Función para verificar directorio
check_directory() {
    local dir_path=$1
    local description=${2:-"directorio"}
    
    if [[ ! -d "$dir_path" ]]; then
        error "$description no encontrado: $dir_path"
        return 1
    else
        debug "$description encontrado: $dir_path"
        return 0
    fi
}

# Función para ejecutar comando con manejo de errores
run_command() {
    local command="$1"
    local description="$2"
    local ignore_errors=${3:-false}
    
    debug "Ejecutando: $command"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        info "[DRY RUN] $description: $command"
        return 0
    fi
    
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        progress "$description..."
        eval "$command"
    else
        eval "$command" >/dev/null 2>&1
    fi
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        success "$description completado"
        return 0
    else
        if [[ "$ignore_errors" == "true" ]]; then
            warning "$description falló (ignorado): código $exit_code"
            return 0
        else
            error "$description falló: código $exit_code"
            return $exit_code
        fi
    fi
}

# Función para limpiar recursos
cleanup() {
    debug "Ejecutando limpieza..."
    
    # Detener port-forwards
    pkill -f "kubectl port-forward" 2>/dev/null || true
    
    # Limpiar variables temporales
    unset TEMP_FILES 2>/dev/null || true
}

# Función para manejo de señales
setup_signal_handlers() {
    trap cleanup EXIT
    trap 'error "Script interrumpido"; exit 130' INT
    trap 'error "Script terminado"; exit 143' TERM
}

# Función para parsear argumentos comunes
parse_common_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                export VERBOSE=true
                debug "Modo verbose habilitado"
                shift
                ;;
            -d|--debug)
                export DEBUG=true
                debug "Modo debug habilitado"
                shift
                ;;
            --dry-run)
                export DRY_RUN=true
                info "Modo dry-run habilitado"
                shift
                ;;
            *)
                # Argumento no reconocido, devolver para procesamiento específico
                break
                ;;
        esac
    done
    
    # Devolver argumentos restantes
    echo "$@"
}

# Función para cargar configuración desde YAML
load_config() {
    local config_file="${1:-$CONFIG_FILE}"
    
    if [[ -f "$config_file" ]] && command_exists yq; then
        debug "Cargando configuración desde: $config_file"
        
        # Exportar variables clave desde la configuración solo si no están ya definidas
        export PROJECT_NAME="${PROJECT_NAME:-$(yq eval '.project.name' "$config_file" 2>/dev/null || echo "blinkchamber")}"
        export CLUSTER_NAME="${CLUSTER_NAME:-$(yq eval '.cluster.name' "$config_file" 2>/dev/null || echo "blinkchamber")}"
        export ENVIRONMENT="${ENVIRONMENT:-$(yq eval '.environment.name' "$config_file" 2>/dev/null || echo "local")}"
        
        success "Configuración cargada desde $config_file"
    else
        warning "No se pudo cargar configuración desde $config_file"
        
        # Valores por defecto solo si las variables no están ya definidas
        export PROJECT_NAME="${PROJECT_NAME:-blinkchamber}"
        export CLUSTER_NAME="${CLUSTER_NAME:-blinkchamber}"
        export ENVIRONMENT="${ENVIRONMENT:-local}"
    fi
}

# Inicialización automática
setup_signal_handlers
load_config

debug "Biblioteca common.sh cargada" 