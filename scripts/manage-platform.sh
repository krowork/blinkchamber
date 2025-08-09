#!/usr/bin/env bash
set -euo pipefail

# =====================================================
# BLINKCHAMBER PLATFORM MANAGEMENT SCRIPT
# =====================================================
# Script completo para gestión de la plataforma BlinkChamber
# Incluye: gestión de secretos, reinicio de pods, configuración inicial

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables globales
VAULT_NAMESPACE="blinkchamber"
VAULT_POD="vault-0"
VERBOSE=false

# =====================================================
# FUNCIONES DE LOGGING
# =====================================================
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

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# =====================================================
# FUNCIÓN DE AYUDA
# =====================================================
show_help() {
    cat << EOF
🚀 BlinkChamber Platform Management Tool

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    secrets                 - Gestión de secretos
        create-all             - Crear todos los secretos necesarios
        create-postgres        - Crear secretos de PostgreSQL
        create-zitadel         - Crear secretos de ZITADEL
        create-vault           - Crear secretos de Vault para ZITADEL
        create-mailu           - Crear secretos de Mailu
        create-grafana         - Crear secretos de Grafana
        create-redis           - Crear secretos de Redis
        sync-k8s               - Sincronizar secretos de Kubernetes
        list                   - Listar secretos existentes
        verify                 - Verificar secretos necesarios

    pods                    - Gestión de pods
        restart-all            - Reiniciar todos los pods problemáticos
        restart-postgres       - Reiniciar pods de PostgreSQL
        restart-zitadel        - Reiniciar pods de ZITADEL
        restart-grafana        - Reiniciar pods de Grafana
        status                 - Ver estado de todos los pods

    vault                   - Gestión de Vault
        init                   - Inicializar Vault (primera vez)
        unseal                 - Desellar Vault
        setup-auth             - Configurar autenticación Kubernetes
        status                 - Ver estado de Vault

    platform                - Gestión de plataforma
        setup                  - Setup completo de la plataforma (Vault + secretos + verificación)
        health-check           - Verificación completa de salud
        fix-issues             - Intentar solucionar problemas automáticamente
        full-restart           - Reinicio completo de la plataforma
        verify-longhorn        - Verificación detallada de Longhorn (almacenamiento)

OPTIONS:
    -v, --verbose           - Mostrar logs detallados
    -f, --force             - Forzar operación sin confirmación
    -h, --help              - Mostrar esta ayuda

EXAMPLES:
    $0 platform setup                       # Setup completo de la plataforma
    $0 secrets create-all                    # Crear todos los secretos
    $0 pods restart-all                      # Reiniciar pods problemáticos
    $0 vault init                            # Inicializar Vault
    $0 platform health-check                # Verificar estado general
    $0 platform fix-issues --force          # Solucionar problemas automáticamente

EOF
}

# =====================================================
# FUNCIONES DE UTILIDAD
# =====================================================
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

check_prerequisites() {
    log "Verificando prerequisitos..."
    
    # Verificar kubectl
    if ! command -v kubectl &> /dev/null; then
        error "kubectl no está instalado"
        exit 1
    fi
    
    # Verificar conexión al cluster
    if ! kubectl cluster-info &> /dev/null; then
        error "No se puede conectar al cluster de Kubernetes"
        exit 1
    fi
    
    # Verificar que Vault esté disponible
    if ! kubectl get pod -n "$VAULT_NAMESPACE" "$VAULT_POD" &> /dev/null; then
        error "Pod de Vault no encontrado: $VAULT_NAMESPACE/$VAULT_POD"
        exit 1
    fi
    
    success "Prerequisitos verificados"
}

vault_exec() {
    kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- "$@"
}

# =====================================================
# FUNCIONES DE GESTIÓN DE SECRETOS
# =====================================================
create_postgres_secrets() {
    log "Creando secretos de PostgreSQL..."
    
    local postgres_password=$(generate_password)
    local postgres_user="postgres"
    
    vault_exec vault kv put secret/database/postgres \
        username="$postgres_user" \
        password="$postgres_password"
    
    success "Secretos de PostgreSQL creados"
    info "Usuario: $postgres_user"
    info "Contraseña: $postgres_password"
    echo
}

create_zitadel_secrets() {
    log "Creando secretos de ZITADEL..."
    
    local zitadel_db_password=$(generate_password)
    # ZITADEL requiere masterkey de exactamente 32 bytes
    local zitadel_masterkey=$(openssl rand -hex 16)
    # Generar credenciales de administrador
    local zitadel_admin_password=$(generate_password)
    local zitadel_admin_email="admin@blinkchamber.local"
    
    # Crear secretos en Vault
    vault_exec vault kv put secret/zitadel/postgres \
        password="$zitadel_db_password"
    
    vault_exec vault kv put secret/zitadel/config \
        masterkey="$zitadel_masterkey"
    
    vault_exec vault kv put secret/zitadel/admin \
        username="zitadel-admin" \
        password="$zitadel_admin_password" \
        email="$zitadel_admin_email" \
        first_name="ZITADEL" \
        last_name="Admin" \
        display_name="ZITADEL Admin"
    
    # Crear secreto de Kubernetes para el chart oficial
    log "Creando secreto de Kubernetes para masterkey..."
    kubectl create secret generic zitadel-masterkey -n identity \
        --from-literal=masterkey="$zitadel_masterkey" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    success "Secretos de ZITADEL creados"
    info "DB Password: $zitadel_db_password"
    info "Master Key (32 bytes): ${zitadel_masterkey:0:8}..."
    info "K8s Secret: zitadel-masterkey created in identity namespace"
    info "Admin User: zitadel-admin"
    info "Admin Email: $zitadel_admin_email"
    info "Admin Password: $zitadel_admin_password"
    echo
}

create_grafana_secrets() {
    log "Creando secretos de Grafana..."
    
    local grafana_admin_password=$(generate_password)
    
    vault_exec vault kv put secret/grafana \
        adminPassword="$grafana_admin_password"
    
    success "Secretos de Grafana creados"
    info "Admin Password: $grafana_admin_password"
    echo
}

create_redis_secrets() {
    log "Creando secretos de Redis..."
    
    local redis_password=$(generate_password)
    
    vault_exec vault kv put secret/redis \
        password="$redis_password"
    
    success "Secretos de Redis creados"
    info "Password: $redis_password"
    echo
}

create_vault_secrets() {
    log "Creando secretos de Vault para ZITADEL..."
    
    local vault_token=$(generate_password)
    
    vault_exec vault kv put secret/zitadel/vault \
        token="$vault_token"
    
    success "Secretos de Vault creados"
    info "Token: $vault_token"
    echo
}

create_mailu_secrets() {
    log "Creando secretos completos de Mailu..."
    
    # Generar contraseñas seguras
    local mailu_admin_password=$(generate_password)
    local mailu_secret_key=$(generate_password)
    local mailu_db_password=$(generate_password)
    
    # Crear secretos principales en Vault
    vault_exec vault kv put secret/mailu \
        admin_username="admin" \
        admin_password="$mailu_admin_password" \
        secret_key="$mailu_secret_key"
    
    # Crear secretos de base de datos
    vault_exec vault kv put secret/mailu/database \
        password="$mailu_db_password"
    
    # Crear política de Vault para Mailu
    vault_exec vault policy write mailu-policy - <<EOF
path "secret/data/mailu/*" {
  capabilities = ["read"]
}
EOF
    
    # Crear role de Kubernetes para Mailu
    vault_exec vault write auth/kubernetes/role/mailu-role \
        bound_service_account_names=mailu \
        bound_service_account_namespaces=blinkchamber \
        policies=mailu-policy \
        ttl=1h
    
    success "Secretos completos de Mailu creados"
    info "Admin User: admin"
    info "Admin Password: $mailu_admin_password"
    info "Secret Key: $mailu_secret_key"
    info "DB Password: $mailu_db_password"
    info "Política y role de Vault configurados"
    echo
}

sync_kubernetes_secrets() {
    log "Sincronizando secretos de Kubernetes para el umbrella chart..."
    
    # Verificar que Vault esté disponible
    if ! vault_exec vault status &>/dev/null; then
        error "Vault no está disponible"
        return 1
    fi
    
    # Obtener masterkey desde Vault
    local masterkey
    masterkey=$(vault_exec vault kv get -field=masterkey secret/zitadel/config 2>/dev/null)
    
    if [[ -z "$masterkey" ]]; then
        warning "Masterkey no encontrado en Vault, generando uno nuevo..."
        masterkey=$(openssl rand -hex 16)
        vault_exec vault kv put secret/zitadel/config masterkey="$masterkey"
    fi
    
    # Crear/actualizar secreto de Kubernetes
    log "Creando secreto zitadel-masterkey en Kubernetes..."
    kubectl create secret generic zitadel-masterkey -n identity \
        --from-literal=masterkey="$masterkey" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Verificar otros secretos necesarios para el umbrella chart
    log "Verificando otros secretos de Kubernetes..."
    
    # Aquí podemos agregar más secretos si es necesario
    # Por ejemplo, certificados TLS, etc.
    
    success "Secretos de Kubernetes sincronizados"
    info "zitadel-masterkey: ✅ Creado/Actualizado"
    info "Masterkey: ${masterkey:0:8}..."
    echo
}

create_all_secrets() {
    log "Creando todos los secretos necesarios..."
    echo
    
    create_postgres_secrets
    create_zitadel_secrets
    create_vault_secrets
    create_mailu_secrets
    create_grafana_secrets
    create_redis_secrets
    
    success "Todos los secretos han sido creados correctamente"
}

list_secrets() {
    log "Listando secretos existentes en Vault..."
    echo
    
    info "Secretos disponibles:"
    vault_exec vault kv list secret/data/ 2>/dev/null || warning "No se pudieron listar los secretos"
    
    echo
    info "Detalles de secretos:"
    
    # PostgreSQL
    echo "📊 PostgreSQL:"
    vault_exec vault kv get secret/database/postgres 2>/dev/null | grep -E "username|password" || warning "Secretos de PostgreSQL no encontrados"
    
    echo
    echo "🔐 ZITADEL:"
    vault_exec vault kv get secret/zitadel/postgres 2>/dev/null | grep "password" || warning "Secretos de ZITADEL/postgres no encontrados"
    vault_exec vault kv get secret/zitadel/config 2>/dev/null | grep "masterkey" || warning "Secretos de ZITADEL/config no encontrados"
    vault_exec vault kv get secret/zitadel/admin 2>/dev/null | grep -E "username|password|email" || warning "Secretos de ZITADEL/admin no encontrados"
    vault_exec vault kv get secret/zitadel/vault 2>/dev/null | grep "token" || warning "Secretos de ZITADEL/vault no encontrados"
    
    echo "📊 Kubernetes Secrets:"
    kubectl get secret zitadel-masterkey -n identity &>/dev/null && info "zitadel-masterkey secret exists" || warning "zitadel-masterkey secret missing"
    
    echo
    echo "📧 Mailu:"
    vault_exec vault kv get secret/mailu 2>/dev/null | grep -E "admin_username|admin_password|secret_key" || warning "Secretos principales de Mailu no encontrados"
    vault_exec vault kv get secret/mailu/database 2>/dev/null | grep "password" || warning "Secretos de BD de Mailu no encontrados"
    
    echo
    echo "📈 Grafana:"
    vault_exec vault kv get secret/grafana 2>/dev/null | grep "adminPassword" || warning "Secretos de Grafana no encontrados"
    
    echo
    echo "🔴 Redis:"
    vault_exec vault kv get secret/redis 2>/dev/null | grep "password" || warning "Secretos de Redis no encontrados"
}

verify_secrets() {
    log "Verificando secretos necesarios..."
    
    local missing_secrets=()
    
    # Verificar PostgreSQL
    if ! vault_exec vault kv get secret/database/postgres &>/dev/null; then
        missing_secrets+=("database/postgres")
    fi
    
    # Verificar ZITADEL
    if ! vault_exec vault kv get secret/zitadel/postgres &>/dev/null; then
        missing_secrets+=("zitadel/postgres")
    fi
    
    if ! vault_exec vault kv get secret/zitadel/config &>/dev/null; then
        missing_secrets+=("zitadel/config")
    fi
    
    if ! vault_exec vault kv get secret/zitadel/admin &>/dev/null; then
        missing_secrets+=("zitadel/admin")
    fi
    
    if ! vault_exec vault kv get secret/zitadel/vault &>/dev/null; then
        missing_secrets+=("zitadel/vault")
    fi
    
    # Verificar Mailu
    if ! vault_exec vault kv get secret/mailu &>/dev/null; then
        missing_secrets+=("mailu")
    fi
    if ! vault_exec vault kv get secret/mailu/database &>/dev/null; then
        missing_secrets+=("mailu-database")
    fi
    
    # Verificar Grafana
    if ! vault_exec vault kv get secret/grafana &>/dev/null; then
        missing_secrets+=("grafana")
    fi
    
    # Verificar Redis
    if ! vault_exec vault kv get secret/redis &>/dev/null; then
        missing_secrets+=("redis")
    fi
    
    if [ ${#missing_secrets[@]} -eq 0 ]; then
        success "Todos los secretos necesarios están presentes"
    else
        warning "Secretos faltantes:"
        for secret in "${missing_secrets[@]}"; do
            echo "  - $secret"
        done
        echo
        info "Ejecuta: $0 secrets create-all para crear los secretos faltantes"
    fi
}

# =====================================================
# FUNCIONES DE GESTIÓN DE PODS
# =====================================================
restart_postgres_pods() {
    log "Reiniciando pods de PostgreSQL..."
    
    kubectl delete pods -n database -l app.kubernetes.io/name=postgresql --ignore-not-found=true
    kubectl delete pods -n database -l app=postgres --ignore-not-found=true
    
    success "Pods de PostgreSQL reiniciados"
}

restart_zitadel_pods() {
    log "Reiniciando pods de ZITADEL..."
    
    kubectl delete pods -n identity -l app.kubernetes.io/name=zitadel --ignore-not-found=true
    kubectl delete pods -n identity -l app=zitadel --ignore-not-found=true
    
    success "Pods de ZITADEL reiniciados"
}

restart_grafana_pods() {
    log "Reiniciando pods de Grafana..."
    
    kubectl delete pods -n monitoring -l app.kubernetes.io/name=grafana --ignore-not-found=true
    kubectl delete pods -n monitoring -l app=grafana --ignore-not-found=true
    
    success "Pods de Grafana reiniciados"
}

restart_all_pods() {
    log "Reiniciando todos los pods problemáticos..."
    
    restart_postgres_pods
    restart_zitadel_pods
    restart_grafana_pods
    
    success "Todos los pods han sido reiniciados"
    echo
    info "Esperando 30 segundos para que los pods se inicien..."
    sleep 30
    
    show_pod_status
}

show_pod_status() {
    log "Estado actual de los pods:"
    echo
    
    echo "📊 PostgreSQL (database namespace):"
    kubectl get pods -n database -o wide 2>/dev/null || warning "Namespace database no encontrado"
    
    echo
    echo "🔐 ZITADEL (identity namespace):"
    kubectl get pods -n identity -o wide 2>/dev/null || warning "Namespace identity no encontrado"
    
    echo
    echo "📈 Grafana (monitoring namespace):"
    kubectl get pods -n monitoring -o wide 2>/dev/null || warning "Namespace monitoring no encontrado"
    
    echo
    echo "🔒 Vault (blinkchamber namespace):"
    kubectl get pods -n blinkchamber -l app.kubernetes.io/name=vault -o wide 2>/dev/null || warning "Pods de Vault no encontrados"
}

# =====================================================
# FUNCIONES DE GESTIÓN DE VAULT
# =====================================================
init_vault() {
    log "Inicializando Vault..."
    
    # Verificar si ya está inicializado
    if vault_exec vault status 2>/dev/null | grep -q "Initialized.*true"; then
        warning "Vault ya está inicializado"
        return 0
    fi
    
    log "Vault no está inicializado. Procediendo con la inicialización..."
    
    local init_output
    init_output=$(vault_exec vault operator init -key-shares=5 -key-threshold=3 -format=json)
    
    echo "$init_output" > vault-keys.json
    
    success "Vault inicializado correctamente"
    warning "¡IMPORTANTE! Las claves de desello han sido guardadas en vault-keys.json"
    warning "Guarda este archivo en un lugar seguro y elimínalo del servidor"
    
    # Intentar desellar automáticamente
    unseal_vault
}

unseal_vault() {
    log "Desellando Vault..."
    
    if vault_exec vault status 2>/dev/null | grep -q "Sealed.*false"; then
        success "Vault ya está desellado"
        return 0
    fi
    
    if [ ! -f "vault-keys.json" ]; then
        error "Archivo vault-keys.json no encontrado"
        error "Necesitas las claves de desello para desellar Vault"
        return 1
    fi
    
    # Extraer las primeras 3 claves de desello
    local unseal_keys
    unseal_keys=($(jq -r '.unseal_keys_b64[]' vault-keys.json | head -3))
    
    for key in "${unseal_keys[@]}"; do
        vault_exec vault operator unseal "$key"
    done
    
    success "Vault desellado correctamente"
}

setup_vault_auth() {
    log "Configurando autenticación de Kubernetes en Vault..."
    
    # Habilitar auth de Kubernetes si no está habilitado
    if ! vault_exec vault auth list | grep -q kubernetes; then
        vault_exec vault auth enable kubernetes
    fi
    
    # Configurar auth de Kubernetes
    vault_exec vault write auth/kubernetes/config \
        token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
        kubernetes_host="https://kubernetes.default.svc:443" \
        kubernetes_ca_cert="$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)"
    
    # Crear políticas
    create_vault_policies
    
    # Crear roles
    create_vault_roles
    
    success "Autenticación de Kubernetes configurada"
}

create_vault_policies() {
    log "Creando políticas de Vault..."
    
    # Política para PostgreSQL
    vault_exec vault policy write postgres-policy - <<EOF
path "secret/data/database/postgres" {
  capabilities = ["read"]
}
EOF
    
    # Política para ZITADEL
    vault_exec vault policy write zitadel-policy - <<EOF
path "secret/data/zitadel/*" {
  capabilities = ["read"]
}
EOF
    
    # Política para Grafana
    vault_exec vault policy write grafana-policy - <<EOF
path "secret/data/grafana" {
  capabilities = ["read"]
}
EOF
    
    success "Políticas de Vault creadas"
}

create_vault_roles() {
    log "Creando roles de Vault..."
    
    # Role para PostgreSQL
    vault_exec vault write auth/kubernetes/role/database-role \
        bound_service_account_names=postgres \
        bound_service_account_namespaces=database \
        policies=postgres-policy \
        ttl=1h
    
    # Role para ZITADEL
    vault_exec vault write auth/kubernetes/role/zitadel-role \
        bound_service_account_names=zitadel \
        bound_service_account_namespaces=identity \
        policies=zitadel-policy \
        ttl=1h
    
    # Role para Grafana
    vault_exec vault write auth/kubernetes/role/grafana-role \
        bound_service_account_names=grafana \
        bound_service_account_namespaces=monitoring \
        policies=grafana-policy \
        ttl=1h
    
    success "Roles de Vault creados"
}

show_vault_status() {
    log "Estado de Vault:"
    echo
    
    vault_exec vault status
}

# =====================================================
# FUNCIONES DE GESTIÓN DE PLATAFORMA
# =====================================================
health_check() {
    log "Realizando verificación completa de salud de la plataforma..."
    echo
    
    # Verificar Vault
    info "1. Verificando Vault..."
    if vault_exec vault status &>/dev/null; then
        success "✅ Vault está funcionando"
    else
        error "❌ Vault tiene problemas"
    fi
    
    # Verificar secretos
    info "2. Verificando secretos..."
    verify_secrets
    
    # Verificar pods
    info "3. Verificando estado de pods..."
    show_pod_status
    
    # Verificar Longhorn (almacenamiento)
    info "4. Verificando Longhorn (almacenamiento distribuido)..."
    if kubectl get pods -n longhorn-system &>/dev/null; then
        local longhorn_ready=$(kubectl get pods -n longhorn-system --field-selector=status.phase=Running --no-headers | wc -l)
        local longhorn_total=$(kubectl get pods -n longhorn-system --no-headers | wc -l)
        
        if [ "$longhorn_ready" -gt 0 ] && [ "$longhorn_ready" -eq "$longhorn_total" ]; then
            success "✅ Longhorn está funcionando ($longhorn_ready/$longhorn_total pods)"
        else
            warning "⚠️  Longhorn tiene problemas ($longhorn_ready/$longhorn_total pods listos)"
        fi
        
        # Verificar StorageClass
        if kubectl get storageclass longhorn &>/dev/null; then
            success "✅ StorageClass de Longhorn disponible"
        else
            warning "⚠️  StorageClass de Longhorn no encontrado"
        fi
    else
        warning "⚠️  Longhorn no está instalado o namespace no existe"
    fi
    
    # Verificar eventos recientes
    info "5. Eventos recientes del cluster:"
    kubectl get events -A --sort-by='.lastTimestamp' | tail -10
    
    echo
    success "Verificación de salud completada"
}

fix_issues() {
    log "Intentando solucionar problemas automáticamente..."
    echo
    
    # 1. Verificar y crear secretos faltantes
    info "Paso 1: Verificando secretos..."
    verify_secrets
    
    read -p "¿Crear secretos faltantes? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_all_secrets
    fi
    
    # 2. Reiniciar pods problemáticos
    info "Paso 2: Reiniciando pods problemáticos..."
    restart_all_pods
    
    # 3. Verificación final
    info "Paso 3: Verificación final..."
    sleep 60  # Esperar a que los pods se estabilicen
    health_check
    
    success "Proceso de solución de problemas completado"
}

full_restart() {
    warning "⚠️  ADVERTENCIA: Esto reiniciará TODA la plataforma"
    read -p "¿Estás seguro? Escribe 'RESTART' para continuar: " -r
    
    if [[ $REPLY != "RESTART" ]]; then
        info "Operación cancelada"
        exit 0
    fi
    
    log "Realizando reinicio completo de la plataforma..."
    
    # Reiniciar todos los pods
    kubectl delete pods -n database --all --ignore-not-found=true
    kubectl delete pods -n identity --all --ignore-not-found=true
    kubectl delete pods -n monitoring --all --ignore-not-found=true
    kubectl delete pods -n blinkchamber -l app.kubernetes.io/name=vault --ignore-not-found=true
    
    success "Reinicio completo iniciado"
    info "Los pods se están reiniciando. Espera unos minutos antes de verificar el estado."
}

platform_setup() {
    log "🚀 Ejecutando setup completo de la plataforma BlinkChamber..."
    echo
    
    info "Paso 1/4: Configurando autenticación de Vault..."
    setup_vault_auth
    echo
    
    info "Paso 2/4: Creando todos los secretos necesarios..."
    create_all_secrets
    echo
    
    info "Paso 3/4: Sincronizando secretos con Kubernetes..."
    sync_kubernetes_secrets
    echo
    
    info "Paso 4/4: Verificación final de salud..."
    health_check
    echo
    
    success "✅ Setup completo de la plataforma terminado exitosamente"
    echo
    info "💡 La plataforma está lista para uso. Comandos útiles:"
    info "   ./manage.sh pods status          # Ver estado de pods"
    info "   ./manage.sh secrets verify       # Verificar secretos"
    info "   ./deploy.sh install              # Desplegar plataforma"
}

verify_longhorn_detailed() {
    log "🔍 Verificación detallada de Longhorn (almacenamiento distribuido)..."
    echo
    
    # Verificar que Longhorn esté instalado
    info "📋 Verificando pods de Longhorn..."
    if kubectl get pods -n longhorn-system &>/dev/null; then
        kubectl get pods -n longhorn-system
        echo
    else
        error "❌ Namespace longhorn-system no existe. Longhorn no está instalado."
        return 1
    fi
    
    # Verificar StorageClasses
    info "💾 Verificando StorageClasses..."
    kubectl get storageclass | grep -E "NAME|longhorn" || warning "No se encontraron StorageClasses de Longhorn"
    echo
    
    # Verificar StorageClass de videos específico
    info "🎥 Verificando StorageClass para videos..."
    if kubectl get storageclass longhorn-videos &>/dev/null; then
        success "✅ StorageClass longhorn-videos encontrado"
        kubectl get storageclass longhorn-videos
    else
        warning "⚠️  StorageClass longhorn-videos no encontrado"
    fi
    echo
    
    # Verificar volúmenes persistentes de videos
    info "📦 Verificando PersistentVolumeClaims de videos..."
    if kubectl get pvc -l app=video-storage &>/dev/null; then
        kubectl get pvc -l app=video-storage
    else
        info "No hay PVCs de video-storage actualmente"
    fi
    echo
    
    # Verificar nodos de Longhorn
    info "🖥️ Verificando nodos de Longhorn..."
    if kubectl get nodes -l longhorn.io/node=true &>/dev/null; then
        kubectl get nodes -l longhorn.io/node=true
    else
        warning "⚠️  No se encontraron nodos etiquetados para Longhorn"
    fi
    echo
    
    # Verificar configuración de Longhorn
    info "⚙️ Verificando configuración de Longhorn..."
    if kubectl get configmap -n longhorn-system longhorn-default-setting &>/dev/null; then
        success "✅ ConfigMap de configuración encontrado"
    else
        warning "⚠️  ConfigMap de configuración no encontrado"
    fi
    echo
    
    # Verificar que la UI esté disponible
    info "🌐 Verificando acceso a la UI de Longhorn..."
    if kubectl get svc -n longhorn-system longhorn-frontend &>/dev/null; then
        success "✅ Servicio de UI disponible"
        kubectl get svc -n longhorn-system longhorn-frontend
    else
        warning "⚠️  Servicio de UI no encontrado"
    fi
    echo
    
    success "✅ Verificación detallada de Longhorn completada"
    echo
    info "📊 Para acceder a la UI de Longhorn:"
    info "   kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80"
    info "   Luego abre http://localhost:8080 en tu navegador"
    echo
    info "📈 Para monitorear volúmenes:"
    info "   kubectl get volumes -n longhorn-system"
    info "   kubectl get replicas -n longhorn-system"
}

# =====================================================
# FUNCIÓN PRINCIPAL
# =====================================================
main() {
    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Verificar prerequisitos
    check_prerequisites
    
    # Procesar comandos
    case "${1:-help}" in
        secrets)
            case "${2:-}" in
                create-all) create_all_secrets ;;
                create-postgres) create_postgres_secrets ;;
                create-zitadel) create_zitadel_secrets ;;
                create-grafana) create_grafana_secrets ;;
                        create-redis) create_redis_secrets ;;
        create-vault) create_vault_secrets ;;
        create-mailu) create_mailu_secrets ;;
        sync-k8s) sync_kubernetes_secrets ;;
        list) list_secrets ;;
        verify) verify_secrets ;;
                *) 
                    error "Comando de secrets no válido: ${2:-}"
                    show_help
                    exit 1
                    ;;
            esac
            ;;
        pods)
            case "${2:-}" in
                restart-all) restart_all_pods ;;
                restart-postgres) restart_postgres_pods ;;
                restart-zitadel) restart_zitadel_pods ;;
                restart-grafana) restart_grafana_pods ;;
                status) show_pod_status ;;
                *)
                    error "Comando de pods no válido: ${2:-}"
                    show_help
                    exit 1
                    ;;
            esac
            ;;
        vault)
            case "${2:-}" in
                init) init_vault ;;
                unseal) unseal_vault ;;
                setup-auth) setup_vault_auth ;;
                status) show_vault_status ;;
                *)
                    error "Comando de vault no válido: ${2:-}"
                    show_help
                    exit 1
                    ;;
            esac
            ;;
        platform)
            case "${2:-}" in
                setup) platform_setup ;;
                health-check) health_check ;;
                fix-issues) fix_issues ;;
                full-restart) full_restart ;;
                verify-longhorn) verify_longhorn_detailed ;;
                # Aliases para consistencia con documentación
                health) health_check ;;
                fix) fix_issues ;;
                *)
                    error "Comando de platform no válido: ${2:-}"
                    show_help
                    exit 1
                    ;;
            esac
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Comando no válido: ${1:-}"
            show_help
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"
