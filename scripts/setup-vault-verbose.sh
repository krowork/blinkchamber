#!/bin/bash

# setup-vault-verbose.sh - Configuración verbosa de Vault con verificaciones detalladas

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para logging verboso
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

log_verify() {
    echo -e "${CYAN}[VERIFY]${NC} $1"
}

# Función para verificar prerequisitos
check_prerequisites() {
    log_step "Verificando prerequisitos..."
    
    # Verificar que kubectl esté disponible
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl no está instalado"
        exit 1
    fi
    log_success "kubectl está disponible"
    
    # Verificar que jq esté disponible
    if ! command -v jq &> /dev/null; then
        log_error "jq no está instalado"
        exit 1
    fi
    log_success "jq está disponible"
    
    # Verificar que vault esté disponible
    if ! command -v vault &> /dev/null; then
        log_error "vault CLI no está instalado"
        exit 1
    fi
    log_success "vault CLI está disponible"
    
    # Verificar conexión al cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "No se puede conectar al cluster Kubernetes"
        exit 1
    fi
    log_success "Conexión al cluster verificada"
}

# Función para verificar estado de Vault
check_vault_status() {
    log_step "Verificando estado de Vault..."
    
    # Verificar que el pod de Vault esté corriendo
    if ! kubectl get pod vault-0 -n vault &> /dev/null; then
        log_error "Pod vault-0 no encontrado en namespace vault"
        exit 1
    fi
    
    local vault_status=$(kubectl get pod vault-0 -n vault -o jsonpath='{.status.phase}')
    if [[ "$vault_status" != "Running" ]]; then
        log_error "Pod vault-0 no está corriendo (status: $vault_status)"
        kubectl describe pod vault-0 -n vault
        exit 1
    fi
    log_success "Pod vault-0 está corriendo"
    
    # Verificar estado interno de Vault
    if ! kubectl exec -it vault-0 -n vault -- vault status &> /dev/null; then
        log_error "No se puede obtener estado interno de Vault"
        exit 1
    fi
    
    local initialized=$(kubectl exec -it vault-0 -n vault -- vault status -format=json | jq -r '.initialized')
    local sealed=$(kubectl exec -it vault-0 -n vault -- vault status -format=json | jq -r '.sealed')
    
    if [[ "$initialized" != "true" ]]; then
        log_error "Vault no está inicializado"
        exit 1
    fi
    log_success "Vault está inicializado"
    
    if [[ "$sealed" != "false" ]]; then
        log_error "Vault está sellado"
        exit 1
    fi
    log_success "Vault está dessellado"
}

# Función para obtener token root
get_root_token() {
    log_step "Obteniendo token root..."
    
    # Verificar que existe el secret
    if ! kubectl get secret vault-root-token -n vault &> /dev/null; then
        log_error "Secret vault-root-token no encontrado"
        exit 1
    fi
    log_success "Secret vault-root-token encontrado"
    
    # Obtener token
    export VAULT_TOKEN=$(kubectl get secret vault-root-token -n vault -o jsonpath='{.data.root-token}' | base64 -d)
    
    if [[ -z "$VAULT_TOKEN" ]]; then
        log_error "No se pudo obtener el token root"
        exit 1
    fi
    log_success "Token root obtenido: ${VAULT_TOKEN:0:20}..."
    
    # Verificar que el token funciona
    export VAULT_ADDR="http://localhost:8201"
    if ! vault token lookup &> /dev/null; then
        log_error "Token root no es válido"
        exit 1
    fi
    log_success "Token root verificado"
}

# Función para configurar autenticación de Kubernetes
configure_kubernetes_auth() {
    log_step "Configurando autenticación de Kubernetes..."
    
    # Verificar si ya está habilitado
    if vault auth list | grep -q "kubernetes/"; then
        log_warning "Auth kubernetes ya está habilitado"
    else
        log_info "Habilitando auth kubernetes..."
        if ! vault auth enable kubernetes; then
            log_error "No se pudo habilitar auth kubernetes"
            exit 1
        fi
        log_success "Auth kubernetes habilitado"
    fi
    
    # Configurar kubernetes auth
    log_info "Configurando kubernetes auth..."
    if ! kubectl exec vault-0 -n vault -- vault write auth/kubernetes/config \
        token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token \
        kubernetes_host="https://kubernetes.default.svc.cluster.local:443" \
        kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt; then
        log_error "No se pudo configurar kubernetes auth"
        exit 1
    fi
    log_success "Kubernetes auth configurado"
    
    # Verificar configuración
    log_verify "Verificando configuración de kubernetes auth..."
    if ! vault read auth/kubernetes/config; then
        log_error "No se puede leer configuración de kubernetes auth"
        exit 1
    fi
    log_success "Configuración de kubernetes auth verificada"
}

# Función para crear políticas
create_policies() {
    log_step "Creando políticas de Vault..."
    
    # Política para database
    log_info "Creando política database-policy..."
    if ! vault policy write database-policy - <<EOF
path "secret/data/database/*" {
  capabilities = ["read"]
}
path "secret/metadata/database/*" {
  capabilities = ["read", "list"]
}
EOF
    then
        log_error "No se pudo crear política database-policy"
        exit 1
    fi
    log_success "Política database-policy creada"
    
    # Política para identity
    log_info "Creando política identity-policy..."
    if ! vault policy write identity-policy - <<EOF
path "secret/data/identity/*" {
  capabilities = ["read"]
}
path "secret/data/database/zitadel" {
  capabilities = ["read"]
}
path "secret/metadata/identity/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/database/zitadel" {
  capabilities = ["read", "list"]
}
EOF
    then
        log_error "No se pudo crear política identity-policy"
        exit 1
    fi
    log_success "Política identity-policy creada"
    
    # Política para monitoring
    log_info "Creando política monitoring-policy..."
    if ! vault policy write monitoring-policy - <<EOF
path "secret/data/monitoring/*" {
  capabilities = ["read"]
}
path "secret/metadata/monitoring/*" {
  capabilities = ["read", "list"]
}
EOF
    then
        log_error "No se pudo crear política monitoring-policy"
        exit 1
    fi
    log_success "Política monitoring-policy creada"
    
    # Verificar políticas creadas
    log_verify "Verificando políticas creadas..."
    local policies=$(vault policy list)
    if ! echo "$policies" | grep -q "database-policy"; then
        log_error "Política database-policy no encontrada"
        exit 1
    fi
    if ! echo "$policies" | grep -q "identity-policy"; then
        log_error "Política identity-policy no encontrada"
        exit 1
    fi
    if ! echo "$policies" | grep -q "monitoring-policy"; then
        log_error "Política monitoring-policy no encontrada"
        exit 1
    fi
    log_success "Todas las políticas verificadas"
}

# Función para crear roles de autenticación
create_k8s_roles() {
    log_step "Creando roles de autenticación de Kubernetes..."
    
    # Rol para database
    log_info "Creando rol database-role..."
    if ! vault write auth/kubernetes/role/database-role \
        bound_service_account_names=postgres \
        bound_service_account_namespaces=database \
        policies=database-policy \
        ttl=1h; then
        log_error "No se pudo crear rol database-role"
        exit 1
    fi
    log_success "Rol database-role creado"
    
    # Rol para identity
    log_info "Creando rol identity-role..."
    if ! vault write auth/kubernetes/role/identity-role \
        bound_service_account_names=zitadel \
        bound_service_account_namespaces=identity \
        policies=identity-policy \
        ttl=1h; then
        log_error "No se pudo crear rol identity-role"
        exit 1
    fi
    log_success "Rol identity-role creado"
    
    # Rol para monitoring
    log_info "Creando rol monitoring-role..."
    if ! vault write auth/kubernetes/role/monitoring-role \
        bound_service_account_names=grafana \
        bound_service_account_namespaces=monitoring \
        policies=monitoring-policy \
        ttl=1h; then
        log_error "No se pudo crear rol monitoring-role"
        exit 1
    fi
    log_success "Rol monitoring-role creado"
    
    # Verificar roles creados
    log_verify "Verificando roles creados..."
    if ! vault read auth/kubernetes/role/database-role; then
        log_error "Rol database-role no encontrado"
        exit 1
    fi
    if ! vault read auth/kubernetes/role/identity-role; then
        log_error "Rol identity-role no encontrado"
        exit 1
    fi
    if ! vault read auth/kubernetes/role/monitoring-role; then
        log_error "Rol monitoring-role no encontrado"
        exit 1
    fi
    log_success "Todos los roles verificados"
}

# Función para crear secretos
create_secrets() {
    log_step "Creando secretos en Vault..."
    
    # Habilitar KV v2 si no está habilitado
    if ! vault secrets list | grep -q "secret/"; then
        log_info "Habilitando KV v2 secret engine..."
        if ! vault secrets enable -path=secret kv-v2; then
            log_error "No se pudo habilitar KV v2"
            exit 1
        fi
        log_success "KV v2 habilitado"
    else
        log_success "KV v2 ya está habilitado"
    fi
    
    # Crear secretos para database
    log_info "Creando secretos para database..."
    if ! vault kv put secret/database/postgres \
        username=postgres \
        password="postgres123456" \
        database=postgres; then
        log_error "No se pudo crear secreto database/postgres"
        exit 1
    fi
    log_success "Secreto database/postgres creado"
    
    # Crear secretos para identity
    log_info "Creando secretos para identity..."
    if ! vault kv put secret/identity/zitadel \
        admin_username=admin \
        admin_password="admin123456" \
        database_url="postgresql://postgres:postgres123456@postgres.database.svc.cluster.local:5432/zitadel"; then
        log_error "No se pudo crear secreto identity/zitadel"
        exit 1
    fi
    log_success "Secreto identity/zitadel creado"
    
    # Crear secretos para monitoring
    log_info "Creando secretos para monitoring..."
    if ! vault kv put secret/monitoring/grafana \
        admin_username=admin \
        admin_password="admin123456"; then
        log_error "No se pudo crear secreto monitoring/grafana"
        exit 1
    fi
    log_success "Secreto monitoring/grafana creado"
    
    # Verificar secretos creados
    log_verify "Verificando secretos creados..."
    if ! vault kv get secret/database/postgres; then
        log_error "Secreto database/postgres no encontrado"
        exit 1
    fi
    if ! vault kv get secret/identity/zitadel; then
        log_error "Secreto identity/zitadel no encontrado"
        exit 1
    fi
    if ! vault kv get secret/monitoring/grafana; then
        log_error "Secreto monitoring/grafana no encontrado"
        exit 1
    fi
    log_success "Todos los secretos verificados"
}

# Función para verificar configuración completa
verify_complete_configuration() {
    log_step "Verificando configuración completa..."
    
    # Verificar auth methods
    log_verify "Verificando auth methods..."
    if ! vault auth list | grep -q "kubernetes/"; then
        log_error "Auth kubernetes no encontrado"
        exit 1
    fi
    log_success "Auth kubernetes verificado"
    
    # Verificar políticas
    log_verify "Verificando políticas..."
    local policies=$(vault policy list)
    for policy in database-policy identity-policy monitoring-policy; do
        if ! echo "$policies" | grep -q "$policy"; then
            log_error "Política $policy no encontrada"
            exit 1
        fi
    done
    log_success "Todas las políticas verificadas"
    
    # Verificar roles
    log_verify "Verificando roles..."
    for role in database-role identity-role monitoring-role; do
        if ! vault read auth/kubernetes/role/$role &> /dev/null; then
            log_error "Rol $role no encontrado"
            exit 1
        fi
    done
    log_success "Todos los roles verificados"
    
    # Verificar secretos
    log_verify "Verificando secretos..."
    for secret in database/postgres identity/zitadel monitoring/grafana; do
        if ! vault kv get secret/$secret &> /dev/null; then
            log_error "Secreto $secret no encontrado"
            exit 1
        fi
    done
    log_success "Todos los secretos verificados"
    
    log_success "✅ Configuración completa verificada"
}

# Función principal
main() {
    echo -e "${GREEN}🔐 Configuración Verbosa de Vault${NC}"
    echo "=================================="
    
    # Configurar port-forward
    log_info "Configurando port-forward para Vault..."
    kubectl port-forward svc/vault -n vault 8201:8200 >/dev/null 2>&1 &
    local pf_pid=$!
    sleep 3
    
    # Ejecutar pasos de configuración
    check_prerequisites
    check_vault_status
    get_root_token
    configure_kubernetes_auth
    create_policies
    create_k8s_roles
    create_secrets
    verify_complete_configuration
    
    # Limpiar port-forward
    kill $pf_pid >/dev/null 2>&1 || true
    
    echo ""
    log_success "🎉 Configuración de Vault completada exitosamente"
    echo ""
    echo "📋 Resumen de configuración:"
    echo "   ✅ Auth kubernetes habilitado y configurado"
    echo "   ✅ 3 políticas creadas (database, identity, monitoring)"
    echo "   ✅ 3 roles de autenticación creados"
    echo "   ✅ Secretos básicos creados"
    echo ""
    echo "🔗 Próximos pasos:"
    echo "   1. Desplegar aplicaciones con anotaciones de Vault"
    echo "   2. Verificar que los pods pueden obtener secretos"
    echo "   3. Configurar port-forwards para acceso externo"
}

# Ejecutar función principal
main "$@" 