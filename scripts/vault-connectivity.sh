#!/bin/bash

# scripts/vault-connectivity.sh - Gestión robusta de conectividad con Vault

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Funciones de logging
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*"; }
error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2; }
success() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $*"; }

# Variables
VAULT_PORT=8201
PF_PID_FILE="/tmp/vault-pf-blinkchamber.pid"
VAULT_DATA_DIR="$PROJECT_ROOT/data/vault"

# Función para matar port-forwards existentes
kill_existing_port_forwards() {
    log "Terminando port-forwards existentes..."
    
    # Matar port-forwards por PID guardado
    if [ -f "$PF_PID_FILE" ]; then
        local pid=$(cat "$PF_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "$PF_PID_FILE"
    fi
    
    # Matar procesos que usan el puerto
    local processes=$(lsof -ti :$VAULT_PORT 2>/dev/null || true)
    if [ -n "$processes" ]; then
        echo "$processes" | xargs -r kill -9 2>/dev/null || true
    fi
    
    # Matar port-forwards específicos de kubectl
    pkill -f "kubectl.*port-forward.*vault.*$VAULT_PORT" 2>/dev/null || true
    
    sleep 2
}

# Función para establecer port-forward
setup_port_forward() {
    log "Configurando port-forward a Vault..."
    
    # Verificar que Vault esté funcionando
    if ! kubectl get pod vault-0 -n vault --no-headers 2>/dev/null | grep -q "Running"; then
        error "Vault pod no está ejecutándose"
        return 1
    fi
    
    # Crear port-forward
    kubectl port-forward svc/vault -n vault $VAULT_PORT:$VAULT_PORT >/dev/null 2>&1 &
    local pf_pid=$!
    echo $pf_pid > "$PF_PID_FILE"
    
    # Verificar que el port-forward funciona
    local retries=0
    while [ $retries -lt 15 ]; do
        if curl -s "http://localhost:$VAULT_PORT/v1/sys/health" >/dev/null 2>&1; then
            success "Port-forward establecido exitosamente (PID: $pf_pid)"
            return 0
        fi
        sleep 1
        retries=$((retries + 1))
    done
    
    error "Port-forward no responde después de 15 intentos"
    kill "$pf_pid" 2>/dev/null || true
    rm -f "$PF_PID_FILE"
    return 1
}

# Función para verificar conectividad
check_connectivity() {
    if [ ! -f "$PF_PID_FILE" ]; then
        return 1
    fi
    
    local pid=$(cat "$PF_PID_FILE")
    if ! kill -0 "$pid" 2>/dev/null; then
        return 1
    fi
    
    if ! curl -s "http://localhost:$VAULT_PORT/v1/sys/health" >/dev/null 2>&1; then
        return 1
    fi
    
    return 0
}

# Función para configurar variables de entorno
setup_vault_env() {
    log "Configurando variables de entorno..."
    
    export VAULT_ADDR="http://localhost:$VAULT_PORT"
    
    # Obtener token si existe
    if [ -f "$VAULT_DATA_DIR/vault-env.sh" ]; then
        source "$VAULT_DATA_DIR/vault-env.sh"
    elif [ -f "$VAULT_DATA_DIR/vault-init.json" ]; then
        local root_token=$(jq -r '.root_token' "$VAULT_DATA_DIR/vault-init.json")
        export VAULT_TOKEN="$root_token"
    fi
    
    # Verificar que tenemos token
    if [ -z "$VAULT_TOKEN" ]; then
        error "No se encontró token de Vault"
        return 1
    fi
    
    log "VAULT_ADDR=$VAULT_ADDR"
    log "VAULT_TOKEN configurado"
}

# Función para establecer conectividad robusta
establish_connectivity() {
    log "Estableciendo conectividad robusta con Vault..."
    
    # Limpiar conexiones existentes
    kill_existing_port_forwards
    
    # Establecer nuevo port-forward
    if setup_port_forward; then
        setup_vault_env
        success "Conectividad establecida"
        return 0
    else
        error "No se pudo establecer conectividad"
        return 1
    fi
}

# Función para mantener conectividad
maintain_connectivity() {
    log "Manteniendo conectividad con Vault..."
    
    while true; do
        if ! check_connectivity; then
            log "Conectividad perdida, reestableciendo..."
            establish_connectivity
        fi
        sleep 5
    done
}

# Función para cleanup
cleanup() {
    log "Limpiando recursos..."
    kill_existing_port_forwards
    success "Limpieza completada"
}

# Función principal
main() {
    case ${1:-"start"} in
        "start")
            establish_connectivity
            ;;
        "maintain")
            maintain_connectivity
            ;;
        "check")
            if check_connectivity; then
                success "Conectividad OK"
                exit 0
            else
                error "Sin conectividad"
                exit 1
            fi
            ;;
        "cleanup")
            cleanup
            ;;
        "env")
            setup_vault_env
            echo "export VAULT_ADDR=$VAULT_ADDR"
            echo "export VAULT_TOKEN=$VAULT_TOKEN"
            ;;
        *)
            echo "Uso: $0 {start|maintain|check|cleanup|env}"
            exit 1
            ;;
    esac
}

main "$@" 