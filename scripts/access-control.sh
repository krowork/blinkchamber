#!/bin/bash

# Script para controlar acceso a servicios por entorno
# Zitadel: Siempre público
# Otros servicios: Solo en desarrollo/testing

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

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Función para mostrar ayuda
show_help() {
    cat << EOF
Uso: $0 [COMANDO] [OPCIONES]

COMANDOS:
    setup ENV          Configurar acceso para entorno (dev/test/prod)
    status             Mostrar estado actual de acceso
    port-forward       Configurar port-forwards para servicios internos
    stop               Detener todos los port-forwards
    help               Mostrar esta ayuda

OPCIONES:
    -e, --environment ENV    Entorno (dev, test, prod) [default: dev]
    -p, --port-forward       Habilitar port-forward para servicios internos
    -i, --ingress-only       Solo configurar Ingress (sin port-forward)

EJEMPLOS:
    $0 setup dev              # Configurar desarrollo
    $0 setup prod             # Configurar producción
    $0 port-forward           # Configurar port-forwards
    $0 status                 # Ver estado actual

EOF
}

# Variables por defecto
ENVIRONMENT="dev"
ENABLE_PORT_FORWARD=true
INGRESS_ONLY=false

# Función para verificar kubectl
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        error "kubectl no está instalado"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        error "No se puede conectar al cluster"
        exit 1
    fi
}

# Función para configurar entorno
setup_environment() {
    local env=$1
    log "Configurando entorno: $env"
    
    # Validar entorno
    case $env in
        dev|test|prod)
            ;;
        *)
            error "Entorno inválido: $env"
            exit 1
            ;;
    esac
    
    # Aplicar configuración de Terraform
    cd terraform/phases/04-applications
    
    if [[ -f "environments/${env}.tfvars" ]]; then
        log "Aplicando configuración para entorno: $env"
        terraform apply -auto-approve -var-file="environments/${env}.tfvars"
    else
        warning "No se encontró configuración específica para $env, usando valores por defecto"
        terraform apply -auto-approve -var="environment=$env"
    fi
    
    success "Entorno $env configurado"
}

# Función para mostrar estado
show_status() {
    log "Estado actual del acceso a servicios:"
    echo "====================================="
    
    # Verificar servicios
    local services=(
        "vault/vault"
        "database/postgres"
        "monitoring/grafana"
        "identity/zitadel"
    )
    
    for service in "${services[@]}"; do
        local namespace=$(echo $service | cut -d'/' -f1)
        local deployment=$(echo $service | cut -d'/' -f2)
        
        if kubectl get deployment "$deployment" -n "$namespace" &> /dev/null; then
            local ready=$(kubectl get deployment "$deployment" -n "$namespace" \
                -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            local desired=$(kubectl get deployment "$deployment" -n "$namespace" \
                -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
            
            if [[ "$ready" == "$desired" ]] && [[ "$ready" -gt 0 ]]; then
                success "$deployment/$namespace: ✅ ($ready/$desired)"
            else
                warning "$deployment/$namespace: ⚠️  ($ready/$desired)"
            fi
        else
            error "$deployment/$namespace: ❌ No encontrado"
        fi
    done
    
    echo
    log "Configuración de Ingress:"
    
    # Zitadel siempre público
    if kubectl get ingress zitadel -n identity &> /dev/null; then
        success "Zitadel: ✅ Público (https://zitadel.blinkchamber.local)"
    else
        error "Zitadel: ❌ No configurado"
    fi
    
    # Grafana condicional
    if kubectl get ingress grafana -n monitoring &> /dev/null; then
        success "Grafana: ✅ Público (https://grafana.blinkchamber.local)"
    else
        warning "Grafana: ⚠️ Solo port-forward (localhost:3000)"
    fi
    
    echo
    log "Port-forwards activos:"
    local active_pfs=$(ps aux | grep "kubectl port-forward" | grep -v grep || true)
    if [[ -n "$active_pfs" ]]; then
        echo "$active_pfs"
    else
        warning "No hay port-forwards activos"
    fi
}

# Función para configurar port-forwards
setup_port_forwards() {
    log "Configurando port-forwards para servicios internos..."
    
    # Detener port-forwards existentes
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 2
    
    # Servicios internos (solo los que no están expuestos públicamente)
    local services=(
        "vault:vault:8200:8200"
        "postgres:database:5432:5432"
    )
    
    # Grafana solo si no está expuesto públicamente
    if ! kubectl get ingress grafana -n monitoring &> /dev/null; then
        services+=("grafana:monitoring:3000:3000")
    fi
    
    for service_config in "${services[@]}"; do
        IFS=':' read -r service namespace local_port remote_port <<< "$service_config"
        
        if kubectl get svc "$service" -n "$namespace" &> /dev/null; then
            log "Configurando port-forward: $service/$namespace $local_port:$remote_port"
            kubectl port-forward "svc/$service" -n "$namespace" \
                "$local_port:$remote_port" >/dev/null 2>&1 &
            
            local pf_pid=$!
            sleep 2
            
            if kill -0 "$pf_pid" 2>/dev/null; then
                success "Port-forward configurado (PID: $pf_pid)"
            else
                error "Port-forward falló para $service"
            fi
        else
            warning "Servicio $service no encontrado en $namespace"
        fi
    done
    
    echo
    log "URLs de acceso:"
    echo "Zitadel: https://zitadel.blinkchamber.local"
    
    # Mostrar URLs según configuración
    if kubectl get ingress grafana -n monitoring &> /dev/null; then
        echo "Grafana: https://grafana.blinkchamber.local"
    else
        echo "Grafana: http://localhost:3000"
    fi
    
    echo "Vault:   http://localhost:8200"
    echo "PostgreSQL: localhost:5432"
}

# Función para detener port-forwards
stop_port_forwards() {
    log "Deteniendo todos los port-forwards..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    success "Port-forwards detenidos"
}

# Función principal
main() {
    local command=${1:-"help"}
    
    case $command in
        setup)
            local env=${2:-"dev"}
            check_kubectl
            setup_environment "$env"
            ;;
        status)
            check_kubectl
            show_status
            ;;
        port-forward)
            check_kubectl
            setup_port_forwards
            ;;
        stop)
            stop_port_forwards
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Comando desconocido: $command"
            show_help
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@" 