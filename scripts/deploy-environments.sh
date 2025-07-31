#!/bin/bash

# ========================================
# SCRIPT DE DESPLIEGUE DE ENTORNOS
# ========================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Función de ayuda
show_help() {
    cat << EOF
Uso: $0 [OPCIONES] ENTORNO

ENTORNOS DISPONIBLES:
    test           - Entorno de pruebas
    development    - Entorno de desarrollo
    staging        - Entorno de pre-producción
    production     - Entorno de producción
    all            - Todos los entornos

OPCIONES:
    -h, --help     - Mostrar esta ayuda
    -d, --dry-run  - Ejecutar en modo dry-run
    -f, --force    - Forzar despliegue sin confirmación
    -v, --verbose  - Mostrar logs detallados

EJEMPLOS:
    $0 test                    # Desplegar solo entorno de test
    $0 all --dry-run          # Simular despliegue de todos los entornos
    $0 production --force     # Desplegar producción sin confirmación

EOF
}

# Variables globales
DRY_RUN=false
FORCE=false
VERBOSE=false
ENVIRONMENT=""

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        test|development|staging|production|all)
            ENVIRONMENT="$1"
            shift
            ;;
        *)
            error "Opción desconocida: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validar entorno
if [[ -z "$ENVIRONMENT" ]]; then
    error "Debe especificar un entorno"
    show_help
    exit 1
fi

# Función para verificar prerequisitos
check_prerequisites() {
    log "Verificando prerequisitos..."
    
    # Verificar kubectl
    if ! command -v kubectl &> /dev/null; then
        error "kubectl no está instalado"
        exit 1
    fi
    
    # Verificar helmfile
    if ! command -v helmfile &> /dev/null; then
        error "helmfile no está instalado"
        exit 1
    fi
    
    # Verificar conexión al cluster
    if ! kubectl cluster-info &> /dev/null; then
        error "No se puede conectar al cluster de Kubernetes"
        exit 1
    fi
    
    success "Prerequisitos verificados"
}

# Función para confirmar despliegue
confirm_deployment() {
    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi
    
    echo
    warning "¿Está seguro de que desea desplegar el entorno '$ENVIRONMENT'?"
    read -p "Presione 'y' para continuar o cualquier otra tecla para cancelar: " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Despliegue cancelado"
        exit 0
    fi
}

# Función para desplegar un entorno específico
deploy_environment() {
    local env=$1
    local namespace="blinkchamber-${env}"
    
    log "Desplegando entorno: $env"
    
    # Crear namespace si no existe
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        log "Creando namespace: $namespace"
        kubectl create namespace "$namespace"
    fi
    
    # Desplegar con helmfile
    local helmfile_cmd="helmfile apply --selector environment=$env"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        helmfile_cmd="$helmfile_cmd --dry-run"
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        helmfile_cmd="$helmfile_cmd --debug"
    fi
    
    log "Ejecutando: $helmfile_cmd"
    eval "$helmfile_cmd"
    
    success "Entorno $env desplegado correctamente"
}

# Función para desplegar todos los entornos
deploy_all() {
    log "Desplegando todos los entornos..."
    
    local environments=("test" "development" "staging" "production")
    
    for env in "${environments[@]}"; do
        deploy_environment "$env"
    done
    
    success "Todos los entornos han sido desplegados"
}

# Función para verificar estado
check_status() {
    log "Verificando estado de los despliegues..."
    
    if [[ "$ENVIRONMENT" == "all" ]]; then
        helmfile status
    else
        helmfile status --selector environment="$ENVIRONMENT"
    fi
}

# Función principal
main() {
    log "Iniciando despliegue de entorno: $ENVIRONMENT"
    
    # Verificar prerequisitos
    check_prerequisites
    
    # Confirmar despliegue
    confirm_deployment
    
    # Desplegar según el entorno
    if [[ "$ENVIRONMENT" == "all" ]]; then
        deploy_all
    else
        deploy_environment "$ENVIRONMENT"
    fi
    
    # Verificar estado
    check_status
    
    success "Despliegue completado exitosamente"
}

# Ejecutar función principal
main "$@" 