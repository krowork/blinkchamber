#!/bin/bash

# Script para configurar acceso a servicios por entorno
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
Uso: $0 [OPCIONES]

Configura el acceso a servicios basado en el entorno:
- Zitadel: Siempre público (Ingress)
- Otros servicios: Solo en desarrollo/testing (Port-forward)

OPCIONES:
    -e, --environment ENV    Entorno (dev, test, prod) [default: dev]
    -p, --port-forward       Habilitar port-forward para servicios internos
    -i, --ingress-only       Solo configurar Ingress (sin port-forward)
    -h, --help              Mostrar esta ayuda

EJEMPLOS:
    $0 --environment dev --port-forward    # Desarrollo con port-forward
    $0 --environment prod --ingress-only   # Producción solo con Ingress
    $0 --environment test                  # Testing (port-forward por defecto)

EOF
}

# Variables por defecto
ENVIRONMENT="dev"
ENABLE_PORT_FORWARD=true
INGRESS_ONLY=false

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -p|--port-forward)
            ENABLE_PORT_FORWARD=true
            INGRESS_ONLY=false
            shift
            ;;
        -i|--ingress-only)
            INGRESS_ONLY=true
            ENABLE_PORT_FORWARD=false
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            error "Opción desconocida: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validar entorno
case $ENVIRONMENT in
    dev|test|prod)
        ;;
    *)
        error "Entorno inválido: $ENVIRONMENT. Usar: dev, test, prod"
        exit 1
        ;;
esac

log "Configurando acceso para entorno: $ENVIRONMENT"

# Función para verificar que kubectl está disponible
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        error "kubectl no está instalado o no está en PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        error "No se puede conectar al cluster de Kubernetes"
        exit 1
    fi
}

# Función para verificar que los servicios están corriendo
check_services() {
    log "Verificando servicios..."
    
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
}

# Función para configurar port-forward
setup_port_forward() {
    local service=$1
    local namespace=$2
    local local_port=$3
    local remote_port=$4
    
    # Detener port-forward existente
    pkill -f "kubectl port-forward.*$service.*$namespace" 2>/dev/null || true
    sleep 2
    
    log "Configurando port-forward: $service/$namespace $local_port:$remote_port"
    
    kubectl port-forward "svc/$service" -n "$namespace" \
        "$local_port:$remote_port" >/dev/null 2>&1 &
    
    local pf_pid=$!
    sleep 3
    
    if kill -0 "$pf_pid" 2>/dev/null; then
        success "Port-forward configurado (PID: $pf_pid)"
        echo "$pf_pid" >> /tmp/blinkchamber-port-forwards.pid
    else
        error "Port-forward falló"
        return 1
    fi
}

# Función para configurar port-forwards para servicios internos
setup_internal_port_forwards() {
    if [[ "$ENABLE_PORT_FORWARD" == "false" ]]; then
        log "Port-forward deshabilitado para este entorno"
        return 0
    fi
    
    log "Configurando port-forwards para servicios internos..."
    
    # Limpiar archivo de PIDs
    rm -f /tmp/blinkchamber-port-forwards.pid
    
    # Servicios internos (solo en dev/test)
    local internal_services=(
        "vault:8200:8200"
        "postgres:5432:5432"
        "grafana:3000:3000"
    )
    
    for service_config in "${internal_services[@]}"; do
        IFS=':' read -r service local_port remote_port <<< "$service_config"
        
        case $service in
            vault)
                if kubectl get svc vault -n vault &> /dev/null; then
                    setup_port_forward "vault" "vault" "$local_port" "$remote_port"
                fi
                ;;
            postgres)
                if kubectl get svc postgres -n database &> /dev/null; then
                    setup_port_forward "postgres" "database" "$local_port" "$remote_port"
                fi
                ;;
            grafana)
                if kubectl get svc grafana -n monitoring &> /dev/null; then
                    setup_port_forward "grafana" "monitoring" "$local_port" "$remote_port"
                fi
                ;;
        esac
    done
}

# Función para verificar Ingress
check_ingress() {
    log "Verificando configuración de Ingress..."
    
    # Zitadel siempre debe tener Ingress
    if kubectl get ingress zitadel -n identity &> /dev/null; then
        success "Ingress de Zitadel configurado"
    else
        error "Ingress de Zitadel no encontrado"
    fi
    
    # Grafana solo en dev/test
    if [[ "$ENVIRONMENT" != "prod" ]]; then
        if kubectl get ingress grafana -n monitoring &> /dev/null; then
            success "Ingress de Grafana configurado"
        else
            warning "Ingress de Grafana no encontrado (esperado en $ENVIRONMENT)"
        fi
    else
        log "Grafana no expuesto públicamente en producción"
    fi
}

# Función para mostrar URLs de acceso
show_access_urls() {
    echo
    log "URLs de acceso configuradas:"
    echo "=================================="
    
    # Zitadel siempre público
    echo "🌐 Zitadel (Público):"
    echo "   https://zitadel.blinkchamber.local"
    echo "   kubectl port-forward svc/zitadel -n identity 8080:8080"
    echo
    
    if [[ "$ENVIRONMENT" != "prod" ]]; then
        echo "📊 Grafana (Público en $ENVIRONMENT):"
        echo "   https://grafana.blinkchamber.local"
        echo "   kubectl port-forward svc/grafana -n monitoring 3000:3000"
        echo
    fi
    
    if [[ "$ENABLE_PORT_FORWARD" == "true" ]]; then
        echo "🔧 Servicios Internos (Port-forward):"
        echo "   Vault:     http://localhost:8200"
        echo "   PostgreSQL: localhost:5432"
        if [[ "$ENVIRONMENT" != "prod" ]]; then
            echo "   Grafana:   http://localhost:3000"
        fi
        echo
    fi
    
    echo "📋 Comandos útiles:"
    echo "   Ver port-forwards activos: ps aux | grep 'kubectl port-forward'"
    echo "   Detener port-forwards: pkill -f 'kubectl port-forward'"
    echo "   Ver pods: kubectl get pods --all-namespaces"
    echo
}

# Función para limpiar port-forwards
cleanup_port_forwards() {
    if [[ -f /tmp/blinkchamber-port-forwards.pid ]]; then
        log "Deteniendo port-forwards..."
        while read -r pid; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
                success "Port-forward detenido (PID: $pid)"
            fi
        done < /tmp/blinkchamber-port-forwards.pid
        rm -f /tmp/blinkchamber-port-forwards.pid
    fi
    
    # También detener cualquier port-forward manual
    pkill -f "kubectl port-forward" 2>/dev/null || true
}

# Función principal
main() {
    log "Iniciando configuración de acceso para entorno: $ENVIRONMENT"
    
    # Verificar prerrequisitos
    check_kubectl
    
    # Verificar servicios
    check_services
    
    # Configurar port-forwards si está habilitado
    if [[ "$ENABLE_PORT_FORWARD" == "true" ]]; then
        setup_internal_port_forwards
    fi
    
    # Verificar Ingress
    check_ingress
    
    # Mostrar URLs de acceso
    show_access_urls
    
    success "Configuración completada para entorno: $ENVIRONMENT"
}

# Trap para limpiar al salir
trap cleanup_port_forwards EXIT

# Ejecutar función principal
main "$@" 