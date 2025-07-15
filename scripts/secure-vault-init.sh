#!/bin/bash

# Script seguro para inicialización de Vault
# Maneja el token root de forma segura sin almacenarlo en texto plano

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de logging
log() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Variables
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT_KEYS_FILE="$PROJECT_ROOT/data/vault-keys.enc"
VAULT_SECRET_NAME="vault-root-token"

# Función para mostrar información de seguridad
show_security_info() {
    cat << EOF

🔐 INFORMACIÓN DE SEGURIDAD - VAULT ROOT TOKEN

⚠️  ADVERTENCIAS IMPORTANTES:
   • El token root tiene acceso completo a Vault
   • NUNCA lo compartas o lo almacenes en texto plano
   • Guárdalo en un gestor de secretos seguro
   • Rótalo regularmente en producción

📋 PRÓXIMOS PASOS RECOMENDADOS:
   1. Copia el token root mostrado arriba
   2. Guárdalo en un gestor de secretos (1Password, Bitwarden, etc.)
   3. Elimina cualquier archivo temporal que lo contenga
   4. Usa tokens con privilegios limitados para operaciones diarias

🔧 PARA OPERACIONES DIARIAS:
   • Usa autenticación de Kubernetes en lugar del token root
   • Crea tokens específicos para cada aplicación
   • Implementa políticas de acceso granular

EOF
}

# Función para generar un token temporal con privilegios limitados
create_limited_token() {
    local root_token=$1
    
    log "🔑 Creando token temporal con privilegios limitados..."
    
    # Configurar port-forward
    kubectl port-forward svc/vault -n vault 8200:8200 >/dev/null 2>&1 &
    local pf_pid=$!
    sleep 3
    
    # Crear token temporal
    local temp_token
    temp_token=$(VAULT_ADDR="http://localhost:8200" VAULT_TOKEN="$root_token" vault token create \
        -policy="blinkchamber-dev" \
        -ttl="24h" \
        -format=json | jq -r '.auth.client_token')
    
    # Limpiar port-forward
    kill $pf_pid >/dev/null 2>&1 || true
    
    echo "$temp_token"
}

# Función para almacenar token en Kubernetes Secret
store_token_in_k8s_secret() {
    local root_token=$1
    
    log "🔒 Almacenando token root en Kubernetes Secret..."
    
    # Crear secret con el token root
    kubectl create secret generic "$VAULT_SECRET_NAME" \
        --from-literal=root-token="$root_token" \
        -n vault \
        --dry-run=client -o yaml | kubectl apply -f -
    
    success "✅ Token root almacenado en Kubernetes Secret: $VAULT_SECRET_NAME"
}

# Función para recuperar token desde Kubernetes Secret
get_token_from_k8s_secret() {
    kubectl get secret "$VAULT_SECRET_NAME" -n vault -o jsonpath='{.data.root-token}' 2>/dev/null | base64 -d || echo ""
}

# Función para inicializar Vault de forma segura
init_vault_secure() {
    log "🔐 Inicializando Vault de forma segura..."
    
    # Esperar a que el pod esté listo
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=vault -n vault --timeout=300s
    
    # Verificar estado
    local status_output
    status_output=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null || echo "{}")
    
    local initialized=$(echo "$status_output" | jq -r '.initialized // false')
    local sealed=$(echo "$status_output" | jq -r '.sealed // true')
    
    if [ "$initialized" = "false" ]; then
        log "🔧 Inicializando Vault..."
        
        # Inicializar Vault
        local init_result
        init_result=$(kubectl exec -n vault vault-0 -- vault operator init -key-shares=5 -key-threshold=3 -format=json)
        
        if [ $? -eq 0 ]; then
            # Extraer información
            local root_token=$(echo "$init_result" | jq -r '.root_token')
            local unseal_key_1=$(echo "$init_result" | jq -r '.unseal_keys_b64[0]')
            local unseal_key_2=$(echo "$init_result" | jq -r '.unseal_keys_b64[1]')
            local unseal_key_3=$(echo "$init_result" | jq -r '.unseal_keys_b64[2]')
            
            # Mostrar información de forma segura
            echo
            echo "🔐 VAULT INICIALIZADO EXITOSAMENTE"
            echo "=================================="
            echo
            echo "🔑 TOKEN ROOT (COPIA ESTO AHORA):"
            echo "   $root_token"
            echo
            echo "🗝️  CLAVES DE UNSEAL (GUÁRDALAS SEGURAMENTE):"
            echo "   Clave 1: $unseal_key_1"
            echo "   Clave 2: $unseal_key_2"
            echo "   Clave 3: $unseal_key_3"
            echo
            
            # Realizar unseal
            log "🔓 Realizando unseal..."
            kubectl exec -n vault vault-0 -- vault operator unseal "$unseal_key_1"
            kubectl exec -n vault vault-0 -- vault operator unseal "$unseal_key_2"
            kubectl exec -n vault vault-0 -- vault operator unseal "$unseal_key_3"
            
            # Almacenar token en Kubernetes Secret
            store_token_in_k8s_secret "$root_token"
            
            # Crear token temporal
            local temp_token
            temp_token=$(create_limited_token "$root_token")
            
            # Mostrar información de seguridad
            show_security_info
            
            # Crear archivo de entorno solo con token temporal
            mkdir -p "$PROJECT_ROOT/data"
            cat > "$PROJECT_ROOT/data/vault-env.sh" << EOF
# Variables de entorno para Vault (TOKEN TEMPORAL)
export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="$temp_token"
# NOTA: Este es un token temporal con privilegios limitados
# Para operaciones administrativas, usa el token root desde el gestor de secretos
EOF
            chmod 600 "$PROJECT_ROOT/data/vault-env.sh"
            
            success "✅ Vault inicializado y configurado de forma segura"
            warning "⚠️  IMPORTANTE: Guarda el token root en un gestor de secretos seguro"
            
            return 0
        else
            error "❌ Error al inicializar Vault"
            return 1
        fi
    else
        log "✅ Vault ya está inicializado"
        
        if [ "$sealed" = "true" ]; then
            log "🔓 Vault está sellado, intentando unseal..."
            
            # Intentar obtener token desde secret
            local root_token
            root_token=$(get_token_from_k8s_secret)
            
            if [ -n "$root_token" ]; then
                # Usar claves de unseal almacenadas (si existen)
                if [ -f "$VAULT_KEYS_FILE" ]; then
                    # Aquí podrías implementar descifrado de claves
                    warning "⚠️  Claves de unseal encontradas, pero se requiere descifrado"
                else
                    warning "⚠️  Vault está sellado y no se encontraron claves de unseal"
                    warning "   Usa el token root para realizar unseal manualmente"
                fi
            else
                warning "⚠️  No se encontró token root en Kubernetes Secret"
                warning "   Necesitas el token root para continuar"
            fi
        fi
        
        return 0
    fi
}

# Función para configurar autenticación de Kubernetes
configure_kubernetes_auth() {
    log "🔧 Configurando autenticación de Kubernetes..."
    
    # Obtener token root desde secret
    local root_token
    root_token=$(get_token_from_k8s_secret)
    
    if [ -z "$root_token" ]; then
        error "❌ No se encontró token root en Kubernetes Secret"
        return 1
    fi
    
    # Configurar port-forward
    kubectl port-forward svc/vault -n vault 8200:8200 >/dev/null 2>&1 &
    local pf_pid=$!
    sleep 3
    
    # Habilitar auth kubernetes
    log "🔐 Habilitando autenticación de Kubernetes..."
    VAULT_ADDR="http://localhost:8200" VAULT_TOKEN="$root_token" vault auth enable kubernetes 2>/dev/null || log "Auth kubernetes ya habilitado"
    
    # Configurar kubernetes auth
    log "⚙️ Configurando kubernetes auth..."
    kubectl exec vault-0 -n vault -- vault write auth/kubernetes/config \
        token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token \
        kubernetes_host="https://kubernetes.default.svc.cluster.local:443" \
        kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt 2>/dev/null || \
        log "Configuración de kubernetes auth completada desde el exterior"
    
    # Crear políticas básicas
    log "📋 Creando políticas básicas..."
    
    VAULT_ADDR="http://localhost:8200" VAULT_TOKEN="$root_token" vault policy write blinkchamber-dev - <<EOF
path "secret/data/database/*" {
  capabilities = ["read"]
}
path "secret/data/identity/*" {
  capabilities = ["read"]
}
path "secret/data/storage/*" {
  capabilities = ["read"]
}
path "secret/data/monitoring/*" {
  capabilities = ["read"]
}
EOF
    
    VAULT_ADDR="http://localhost:8200" VAULT_TOKEN="$root_token" vault policy write blinkchamber-admin - <<EOF
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "sys/policies/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOF
    
    # Limpiar port-forward
    kill $pf_pid >/dev/null 2>&1 || true
    
    success "✅ Autenticación de Kubernetes configurada"
}

# Función para mostrar estado actual
show_status() {
    log "📊 Estado actual de Vault:"
    
    # Verificar pod
    if kubectl get pods -n vault vault-0 --no-headers | grep -q Running; then
        log "✅ Pod de Vault: Running"
    else
        log "❌ Pod de Vault: No está ejecutándose"
        return 1
    fi
    
    # Verificar estado de Vault
    local status_output
    status_output=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null || echo "{}")
    
    local initialized=$(echo "$status_output" | jq -r '.initialized // false')
    local sealed=$(echo "$status_output" | jq -r '.sealed // true')
    
    log "   Inicializado: $initialized"
    log "   Sellado: $sealed"
    
    # Verificar secret
    if kubectl get secret "$VAULT_SECRET_NAME" -n vault >/dev/null 2>&1; then
        log "✅ Token root: Almacenado en Kubernetes Secret"
    else
        log "❌ Token root: No encontrado en Kubernetes Secret"
    fi
    
    # Verificar archivo de entorno
    if [ -f "$PROJECT_ROOT/data/vault-env.sh" ]; then
        log "✅ Archivo de entorno: $PROJECT_ROOT/data/vault-env.sh"
    else
        log "❌ Archivo de entorno: No encontrado"
    fi
}

# Función principal
main() {
    log "🔐 Iniciando inicialización segura de Vault..."
    
    # Verificar prerequisitos
    command -v kubectl >/dev/null 2>&1 || { error "kubectl no encontrado"; exit 1; }
    command -v jq >/dev/null 2>&1 || { error "jq no encontrado"; exit 1; }
    
    case "${1:-init}" in
        "init")
            init_vault_secure
            configure_kubernetes_auth
            ;;
        "status")
            show_status
            ;;
        "configure-auth")
            configure_kubernetes_auth
            ;;
        *)
            echo "Uso: $0 [init|status|configure-auth]"
            echo "  init           - Inicializar Vault de forma segura"
            echo "  status         - Mostrar estado actual"
            echo "  configure-auth - Configurar autenticación de Kubernetes"
            exit 1
            ;;
    esac
    
    success "🎉 Operación completada"
}

# Ejecutar función principal
main "$@" 