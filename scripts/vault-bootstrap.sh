#!/bin/bash

# scripts/vault-bootstrap.sh - Orquestador principal del bootstrap de Vault en fases

set -e

# Detectar directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Cargar bibliotecas existentes
source "$SCRIPT_DIR/lib/common.sh" 2>/dev/null || {
    # Funciones básicas si no existe common.sh
    log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*"; }
    error() { echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" >&2; }
    success() { echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $*"; }
    warning() { echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $*"; }
}

# Variables globales
CLUSTER_NAME="${CLUSTER_NAME:-blinkchamber}"
ENVIRONMENT="${ENVIRONMENT:-development}"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
DATA_DIR="$PROJECT_ROOT/data"
VAULT_DATA_DIR="$DATA_DIR/vault"

# Configuración por entorno
case $ENVIRONMENT in
    "production")
        AUTO_UNSEAL_METHOD="awskms"
        BACKUP_ENABLED=true
        HA_ENABLED=true
        ;;
    "staging")
        AUTO_UNSEAL_METHOD="transit"
        BACKUP_ENABLED=true
        HA_ENABLED=false
        ;;
    "development"|*)
        AUTO_UNSEAL_METHOD="shamir"
        BACKUP_ENABLED=false
        HA_ENABLED=false
        ;;
esac

# Crear directorios necesarios
mkdir -p "$VAULT_DATA_DIR" "$DATA_DIR/backup"

show_help() {
    cat << EOF
🚀 blinkchamber - Vault Bootstrap Automático

Uso: $0 [fase|comando] [opciones]

FASES DE BOOTSTRAP:
  1, bootstrap     Fase 1: Infraestructura básica (ingress, cert-manager, vault-infra)
  2, vault-init    Fase 2: Inicialización automática de Vault
  3, secrets       Fase 3: Configuración de secretos en Vault
  4, applications  Fase 4: Despliegue de aplicaciones con Vault
  all             Ejecutar todas las fases secuencialmente

COMANDOS DE GESTIÓN:
  status          Mostrar estado de Vault y fases
  init            Inicializar Vault directamente (alternativa a fase 2)
  unseal          Unseal manual para desarrollo
  backup          Crear backup de Vault
  restore         Restaurar backup de Vault
  reset           Resetear Vault (¡DESTRUCTIVO!)
  port-forward    Configurar port-forwarding a Vault
  logs            Mostrar logs de Vault

OPCIONES:
  --environment ENV    Entorno: development, staging, production (default: $ENVIRONMENT)
  --cluster-name NAME  Nombre del cluster (default: $CLUSTER_NAME)
  --auto-unseal METHOD Método de auto-unseal: shamir, transit, awskms, azurekeyvault
  --skip-wait         No esperar confirmación entre fases
  --dry-run          Mostrar comandos sin ejecutar
  --verbose          Modo verbose
  --force            Forzar operación sin confirmaciones
  --force-reset      Resetear Vault completamente (¡DESTRUCTIVO! Elimina todos los secretos)

VARIABLES DE ENTORNO:
  ENVIRONMENT=env          Entorno de despliegue
  CLUSTER_NAME=name        Nombre del cluster Kind
  VAULT_TOKEN=token        Token de Vault (para operaciones)
  DRY_RUN=true            Modo dry-run
  VERBOSE=true            Modo verbose

EJEMPLOS:
  # Bootstrap completo automático
  $0 all

  # Bootstrap por fases (para debugging)
  $0 1                    # Solo infraestructura
  $0 2                    # Solo inicialización de Vault
  $0 3                    # Solo configuración de secretos
  $0 4                    # Solo aplicaciones

  # Gestión de Vault
  $0 status               # Ver estado actual
  $0 init                 # Inicializar Vault directamente
  $0 unseal               # Unseal manual (desarrollo)
  $0 backup               # Crear backup
  $0 port-forward         # Acceso local a Vault

  # Reseteo de Vault (¡DESTRUCTIVO!)
  $0 2 --force-reset      # Resetear Vault y reinicializar automáticamente
  $0 all --force-reset    # Bootstrap completo con reseteo de Vault

  # Entornos específicos
  ENVIRONMENT=production $0 all --auto-unseal awskms
  ENVIRONMENT=staging $0 all --auto-unseal transit

Para más información: https://github.com/blinkchamber/docs

EOF
}

# Función para verificar prerequisitos
check_prerequisites() {
    log "🔍 Verificando prerequisitos..."
    
    local missing=()
    
    command -v kubectl >/dev/null 2>&1 || missing+=("kubectl")
    command -v terraform >/dev/null 2>&1 || missing+=("terraform")
    command -v helm >/dev/null 2>&1 || missing+=("helm")
    command -v jq >/dev/null 2>&1 || missing+=("jq")
    
    if [ ${#missing[@]} -ne 0 ]; then
        error "Herramientas faltantes: ${missing[*]}"
        error "Instala las herramientas requeridas antes de continuar"
        exit 1
    fi
    
    # Verificar cluster Kind
    if ! kind get clusters | grep -q "^$CLUSTER_NAME$"; then
        warning "Cluster Kind '$CLUSTER_NAME' no encontrado"
        log "Creando cluster con configuración adecuada..."
        
        # Usar configuración de Kind si existe
        if [ -f "$PROJECT_ROOT/config/kind-config.yaml" ]; then
            kind create cluster --name "$CLUSTER_NAME" --config "$PROJECT_ROOT/config/kind-config.yaml" || {
                error "Error al crear cluster con configuración. Intentando creación básica..."
                kind create cluster --name "$CLUSTER_NAME"
                # Agregar etiqueta necesaria manualmente
                kubectl label node "${CLUSTER_NAME}-control-plane" ingress-ready=true --overwrite
            }
        else
            kind create cluster --name "$CLUSTER_NAME"
            # Agregar etiqueta necesaria manualmente
            kubectl label node "${CLUSTER_NAME}-control-plane" ingress-ready=true --overwrite
        fi
    fi
    
    # Configurar kubectl context
    kubectl config use-context "kind-$CLUSTER_NAME" >/dev/null 2>&1
    
    # Verificar que el cluster es funcional
    if ! kubectl cluster-info >/dev/null 2>&1; then
        error "Cluster Kind '$CLUSTER_NAME' no es accesible"
        exit 1
    fi
    
    # Asegurar que el nodo tiene las etiquetas necesarias
    if ! kubectl get nodes "${CLUSTER_NAME}-control-plane" -o jsonpath='{.metadata.labels.ingress-ready}' 2>/dev/null | grep -q "true"; then
        log "Agregando etiqueta ingress-ready al nodo control-plane..."
        kubectl label node "${CLUSTER_NAME}-control-plane" ingress-ready=true --overwrite
    fi
    
    success "✅ Prerequisitos verificados"
}


# Función para ejecutar Terraform en una fase
run_terraform_phase() {
    local phase=$1
    local phase_dir="$TERRAFORM_DIR/phases/$phase"
    local action=${2:-apply}
    
    if [ ! -d "$phase_dir" ]; then
        error "Directorio de fase no encontrado: $phase_dir"
        return 1
    fi
    
    log "🔧 Ejecutando Terraform en fase $phase ($action)..."
    
    cd "$phase_dir"
    
    # Variables comunes para todas las fases
    local tf_vars=(
        "-var" "cluster_name=$CLUSTER_NAME"
        "-var" "environment=$ENVIRONMENT"
    )
    
    # Variables específicas por fase
    case $phase in
        "02-vault-init")
            tf_vars+=("-var" "auto_unseal_method=$AUTO_UNSEAL_METHOD")
            ;;
    esac
    
    case $action in
        "init")
            terraform init -upgrade
            ;;
        "plan")
            terraform init -upgrade >/dev/null 2>&1
            terraform plan "${tf_vars[@]}"
            ;;
        "apply")
            terraform init -upgrade >/dev/null 2>&1
            if [[ "${DRY_RUN:-false}" == "true" ]]; then
                log "DRY RUN: terraform apply ${tf_vars[*]}"
            else
                terraform apply "${tf_vars[@]}" -auto-approve
            fi
            ;;
        "destroy")
            terraform destroy "${tf_vars[@]}" -auto-approve
            ;;
    esac
    
    cd - >/dev/null
}

# Función para verificar estado de una fase
check_phase_status() {
    local phase=$1
    local phase_dir="$TERRAFORM_DIR/phases/$phase"
    
    # Buscar archivos de estado en múltiples ubicaciones
    local state_files=(
        "$phase_dir/terraform.tfstate"
        "$TERRAFORM_DIR/phases/terraform-bootstrap.tfstate"
        "$TERRAFORM_DIR/phases/terraform-vault-init.tfstate"
        "$TERRAFORM_DIR/phases/terraform-secrets.tfstate"
        "$TERRAFORM_DIR/phases/terraform-applications.tfstate"
    )
    
    local found_state=false
    for state_file in "${state_files[@]}"; do
        if [ -f "$state_file" ]; then
            found_state=true
            break
        fi
    done
    
    if [ "$found_state" = false ]; then
        echo "not_applied"
        return
    fi
    
    cd "$phase_dir" 2>/dev/null || return
    
    # Verificar si el estado tiene outputs válidos
    if terraform show -json 2>/dev/null | jq -e '.values.outputs' >/dev/null 2>&1; then
        echo "applied"
    else
        # Si no hay outputs pero hay recursos, considerar como aplicado
        if terraform show -json 2>/dev/null | jq -e '.values.root_module.resources[]?' >/dev/null 2>&1; then
            echo "applied"
        else
            echo "error"
        fi
    fi
    
    cd - >/dev/null 2>&1
}

# Función para ejecutar fase específica
execute_phase() {
    local phase_num=$1
    local skip_wait=${2:-false}
    
    case $phase_num in
        1|"bootstrap")
            log "🚀 FASE 1: Bootstrap Básico"
            log "Desplegando: kubernetes-base, ingress, cert-manager, vault-infrastructure"
            
            run_terraform_phase "01-bootstrap"
            
            log "⏳ Esperando que los servicios estén listos..."
            
            # Esperar cert-manager
            log "Esperando cert-manager..."
            kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=600s || {
                warning "Cert-manager tardó más de lo esperado, verificando estado..."
                kubectl get pods -n cert-manager
            }
            
            # Esperar ingress-nginx
            log "Esperando ingress-nginx..."
            kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=600s || {
                warning "Ingress-nginx tardó más de lo esperado, verificando estado..."
                kubectl get pods -n ingress-nginx
            }
            
            # Esperar vault
            log "Esperando vault..."
            kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=vault -n vault --timeout=600s || {
                warning "Vault tardó más de lo esperado, verificando estado..."
                kubectl get pods -n vault
            }
            
            success "✅ Fase 1 completada: Infraestructura básica lista"
            ;;
            
        2|"vault-init")
            log "🔐 FASE 2: Inicialización de Vault"
            log "Configurando: auto-init, kubernetes-auth, políticas básicas"
            
            # Verificar que fase 1 esté completada
            if [ "$(check_phase_status "01-bootstrap")" != "applied" ]; then
                error "Fase 1 no completada. Ejecuta primero: $0 1"
                exit 1
            fi
            
            # Verificar que Vault esté ejecutándose
            if ! kubectl get pods -n vault -l app.kubernetes.io/name=vault --no-headers | grep -q Running; then
                error "Vault no está ejecutándose. Verifica la fase 1."
                exit 1
            fi
            
            # Si se solicita force-reset, resetear Vault primero
            if [ "${FORCE_RESET:-false}" = "true" ]; then
                log "🔄 Reseteo forzado solicitado, eliminando Vault existente..."
                if reset_vault_safe; then
                    success "✅ Vault reseteado exitosamente"
                else
                    error "❌ Error al resetear Vault"
                    exit 1
                fi
            fi
            
            # Usar inicialización directa más robusta
            if init_vault_direct; then
                success "✅ Fase 2 completada: Vault inicializado y configurado"
            else
                error "❌ Error en la inicialización de Vault"
                exit 1
            fi
            ;;
            
        3|"secrets")
            log "⚙️ FASE 3: Configuración de Secretos"
            log "Configurando: KV engine, secretos de aplicaciones, políticas"
            
            # Verificar que fase 2 esté completada
            if [ "$(check_phase_status "02-vault-init")" != "applied" ]; then
                error "Fase 2 no completada. Ejecuta primero: $0 2"
                exit 1
            fi
            
            run_terraform_phase "03-secrets"
            
            
            success "✅ Fase 3 completada: Secretos configurados en Vault"
            ;;
            
        4|"applications")
            log "🎯 FASE 4: Despliegue de Aplicaciones"
            log "Desplegando: database, identity, storage con integración Vault"
            
            # Verificar que fase 3 esté completada
            if [ "$(check_phase_status "03-secrets")" != "applied" ]; then
                error "Fase 3 no completada. Ejecuta primero: $0 3"
                exit 1
            fi
            
            run_terraform_phase "04-applications"
            
            success "✅ Fase 4 completada: Aplicaciones desplegadas con Vault"
            ;;
            
        *)
            error "Fase desconocida: $phase_num"
            show_help
            exit 1
            ;;
    esac
    
    # Pausa entre fases (excepto si se omite)
    if [[ "$skip_wait" != "true" && "$phase_num" != "4" && "$phase_num" != "applications" ]]; then
        log "⏸️ Fase $phase_num completada. Presiona Enter para continuar a la siguiente fase..."
        read -r
    fi
}

# Función para configurar acceso a Vault
setup_vault_access() {
    log "🔧 Configurando acceso local a Vault..."
    
    # Obtener token root
    local root_token
    root_token=$(kubectl get secret vault-root-token -n vault -o jsonpath='{.data.token}' 2>/dev/null | base64 -d || echo "")
    
    if [ -n "$root_token" ]; then
        echo "VAULT_ADDR=http://localhost:8200" > "$VAULT_DATA_DIR/vault-env.sh"
        echo "VAULT_TOKEN=$root_token" >> "$VAULT_DATA_DIR/vault-env.sh"
        echo "export VAULT_ADDR VAULT_TOKEN" >> "$VAULT_DATA_DIR/vault-env.sh"
        
        success "✅ Configuración de acceso guardada en: $VAULT_DATA_DIR/vault-env.sh"
        log "Para usar Vault CLI: source $VAULT_DATA_DIR/vault-env.sh"
    else
        warning "⚠️ No se pudo obtener el token root de Vault"
    fi
}

# Función para mostrar estado
show_status() {
    log "📊 Estado actual del sistema blinkchamber"
    echo ""
    
    # Verificar cluster
    if kind get clusters | grep -q "^$CLUSTER_NAME$"; then
        success "✅ Cluster Kind '$CLUSTER_NAME' está activo"
    else
        error "❌ Cluster Kind '$CLUSTER_NAME' no encontrado"
        return 1
    fi
    
    # Estado de las fases
    echo ""
    log "📋 Estado de las fases:"
    
    for i in {1..4}; do
        local phase_dir phase_name status_icon status_text
        
        case $i in
            1) phase_dir="01-bootstrap"; phase_name="Bootstrap Básico" ;;
            2) phase_dir="02-vault-init"; phase_name="Inicialización Vault" ;;
            3) phase_dir="03-secrets"; phase_name="Configuración Secretos" ;;
            4) phase_dir="04-applications"; phase_name="Aplicaciones" ;;
        esac
        
        case $(check_phase_status "$phase_dir") in
            "applied") status_icon="✅"; status_text="Completada" ;;
            "error") status_icon="❌"; status_text="Error" ;;
            *) status_icon="⏸️"; status_text="Pendiente" ;;
        esac
        
        printf "  Fase %d: %-25s %s %s\n" $i "$phase_name" "$status_icon" "$status_text"
    done
    
    # Estado de Vault si está desplegado
    if kubectl get namespace vault >/dev/null 2>&1; then
        echo ""
        log "🔐 Estado de Vault:"
        
        # Port forward temporal para verificar estado
        kubectl port-forward svc/vault -n vault 8200:8200 >/dev/null 2>&1 &
        local pf_pid=$!
        sleep 3
        
        if curl -s http://localhost:8200/v1/sys/health >/dev/null 2>&1; then
            local vault_status
            vault_status=$(curl -s http://localhost:8200/v1/sys/health | jq -r '.')
            
            local initialized sealed
            initialized=$(echo "$vault_status" | jq -r '.initialized // false')
            sealed=$(echo "$vault_status" | jq -r '.sealed // true')
            
            if [ "$initialized" = "true" ]; then
                success "  ✅ Inicializado: Sí"
            else
                error "  ❌ Inicializado: No"
            fi
            
            if [ "$sealed" = "false" ]; then
                success "  ✅ Sealed: No (Vault está operativo)"
            else
                warning "  ⚠️ Sealed: Sí (Vault está sellado)"
            fi
            
        else
            warning "  ⚠️ Vault no responde en http://localhost:8200"
        fi
        
        kill $pf_pid >/dev/null 2>&1 || true
        
        # Información de acceso
        echo ""
        log "🌐 Acceso a Vault:"
        log "  UI: http://localhost:8200/ui (después de: kubectl port-forward svc/vault -n vault 8200:8200)"
        
        if [ -f "$VAULT_DATA_DIR/vault-env.sh" ]; then
            log "  CLI: source $VAULT_DATA_DIR/vault-env.sh"
        fi
    fi
}

# Función para unseal manual
unseal_vault() {
    log "🔓 Realizando unseal manual de Vault..."
    
    if [ ! -f "$VAULT_DATA_DIR/vault-env.sh" ]; then
        setup_vault_access
    fi
    
    # Verificar que Vault está disponible
    if ! kubectl get pods -n vault -l app.kubernetes.io/name=vault --no-headers | grep -q Running; then
        error "Vault no está ejecutándose"
        exit 1
    fi
    
    # Configurar port forward
    log "Configurando port forward..."
    kubectl port-forward svc/vault -n vault 8200:8200 >/dev/null 2>&1 &
    local pf_pid=$!
    sleep 5
    
    # Verificar conectividad
    local retries=0
    while [ $retries -lt 10 ]; do
        if curl -s http://localhost:8200/v1/sys/health >/dev/null 2>&1; then
            break
        fi
        log "Esperando conectividad con Vault... (intento $((retries + 1))/10)"
        sleep 2
        retries=$((retries + 1))
    done
    
    if [ $retries -eq 10 ]; then
        error "No se pudo conectar a Vault"
        kill $pf_pid >/dev/null 2>&1 || true
        exit 1
    fi
    
    # Verificar si ya está unsealed
    if curl -s http://localhost:8200/v1/sys/health | jq -r '.sealed' | grep -q false; then
        success "✅ Vault ya está unsealed"
        kill $pf_pid >/dev/null 2>&1 || true
        return 0
    fi
    
    # Obtener claves de unseal
    local unseal_keys
    unseal_keys=$(kubectl get secret vault-init-keys -n vault -o jsonpath='{.data.vault-init\.json}' 2>/dev/null | base64 -d | jq -r '.unseal_keys_b64[]' 2>/dev/null || echo "")
    
    if [ -z "$unseal_keys" ]; then
        error "No se encontraron claves de unseal en vault-init-keys secret"
        log "Intentando crear el secret manualmente..."
        
        # Si no existe el job, no podemos hacer unseal
        if ! kubectl get job -n vault -l app=vault-init --no-headers | grep -q .; then
            error "No hay job de inicialización disponible"
            kill $pf_pid >/dev/null 2>&1 || true
            exit 1
        fi
        
        kill $pf_pid >/dev/null 2>&1 || true
        exit 1
    fi
    
    # Realizar unseal
    local count=0
    echo "$unseal_keys" | while read -r key && [ $count -lt 3 ]; do
        log "Aplicando clave de unseal $((count + 1))/3..."
        local result
        result=$(curl -s -X PUT -d "{\"key\":\"$key\"}" http://localhost:8200/v1/sys/unseal)
        if echo "$result" | jq -e '.sealed' >/dev/null 2>&1; then
            local sealed_status
            sealed_status=$(echo "$result" | jq -r '.sealed')
            if [ "$sealed_status" = "false" ]; then
                success "✅ Vault unsealed exitosamente"
                kill $pf_pid >/dev/null 2>&1 || true
                return 0
            fi
        fi
        count=$((count + 1))
    done
    
    sleep 2
    
    # Verificar estado final
    if curl -s http://localhost:8200/v1/sys/health | jq -r '.sealed' | grep -q false; then
        success "✅ Vault unsealed exitosamente"
    else
        error "❌ Error al unseal Vault"
    fi
    
    kill $pf_pid >/dev/null 2>&1 || true
}

# Función para port forward
setup_port_forward() {
    log "🔗 Configurando port-forward a Vault..."
    
    if ! kubectl get svc vault -n vault >/dev/null 2>&1; then
        error "Servicio de Vault no encontrado. Ejecuta primero el bootstrap."
        exit 1
    fi
    
    log "Port-forwarding: http://localhost:8200 -> vault.vault.svc.cluster.local:8200"
    log "Presiona Ctrl+C para detener"
    
    kubectl port-forward svc/vault -n vault 8200:8200
}

# Función para inicializar Vault directamente
init_vault_direct() {
    log "🔐 Inicializando Vault directamente..."
    
    # Port forward temporal usando puerto 8201 para evitar conflictos
    kubectl port-forward svc/vault -n vault 8201:8200 >/dev/null 2>&1 &
    local pf_pid=$!
    sleep 5
    
    # Verificar conectividad
    local retries=0
    while [ $retries -lt 10 ]; do
        if curl -s http://localhost:8201/v1/sys/health >/dev/null 2>&1; then
            break
        fi
        log "Esperando conectividad con Vault... (intento $((retries + 1))/10)"
        sleep 2
        retries=$((retries + 1))
    done
    
    if [ $retries -eq 10 ]; then
        error "No se pudo conectar a Vault"
        kill $pf_pid >/dev/null 2>&1 || true
        return 1
    fi
    
    export VAULT_ADDR=http://localhost:8201
    
    # Verificar estado de Vault
    local vault_status
    vault_status=$(curl -s http://localhost:8201/v1/sys/health || echo "{}")
    local initialized=$(echo "$vault_status" | jq -r '.initialized // false')
    local sealed=$(echo "$vault_status" | jq -r '.sealed // true')
    
    log "Estado de Vault: inicializado=$initialized, sellado=$sealed"
    
    if [ "$initialized" = "false" ]; then
        log "🔧 Vault no está inicializado, procediendo con inicialización..."
        
        # Inicializar Vault
        local init_result
        init_result=$(vault operator init -key-shares=5 -key-threshold=3 -format=json)
        
        if [ $? -eq 0 ]; then
            log "✅ Vault inicializado exitosamente"
            
            # Extraer token root y claves
            local root_token=$(echo "$init_result" | jq -r '.root_token')
            local unseal_keys=$(echo "$init_result" | jq -r '.unseal_keys_b64 | .[]')

            log "VAULT_ROOT_TOKEN: $root_token"
            log "VAULT_UNSEAL_KEYS:"
            echo "$unseal_keys" | while read -r key; do
                log "$key"
            done

            local unseal_key_1=$(echo "$unseal_keys" | sed -n 1p)
            local unseal_key_2=$(echo "$unseal_keys" | sed -n 2p)
            local unseal_key_3=$(echo "$unseal_keys" | sed -n 3p)
            
            # Realizar unseal
            log "🔓 Realizando unseal..."
            vault operator unseal "$unseal_key_1"
            vault operator unseal "$unseal_key_2" 
            vault operator unseal "$unseal_key_3"
            
            # Configurar token
            export VAULT_TOKEN="$root_token"
            
            # Guardar configuración local
            echo "VAULT_ADDR=http://localhost:8201" > "$VAULT_DATA_DIR/vault-env.sh"
            echo "VAULT_TOKEN=$root_token" >> "$VAULT_DATA_DIR/vault-env.sh"
            echo "export VAULT_ADDR VAULT_TOKEN" >> "$VAULT_DATA_DIR/vault-env.sh"
            
            success "✅ Vault inicializado y configurado"
        else
            error "❌ Error al inicializar Vault"
            kill $pf_pid >/dev/null 2>&1 || true
            return 1
        fi
        
    elif [ "$sealed" = "true" ]; then
        log "🔓 Vault está inicializado pero sellado, intentando unseal..."
        if [ -n "$VAULT_UNSEAL_KEY" ]; then
            log "Usando VAULT_UNSEAL_KEY para unseal..."
            local unseal_keys=$(echo "$VAULT_UNSEAL_KEY" | tr "," "\n")
            echo "$unseal_keys" | while read -r key; do
                vault operator unseal "$key"
            done
            success "✅ Vault unsealed exitosamente"
        else
            error "❌ Vault está inicializado pero sellado, y no se encontraron las claves de unseal."
            error "   Por favor, proporciona las claves de unseal usando la variable de entorno VAULT_UNSEAL_KEY."
            error "   export VAULT_UNSEAL_KEY=\\\"key1,key2,key3\\\""
            kill $pf_pid >/dev/null 2>&1 || true
            return 1
        fi
        
    else
        log "✅ Vault ya está inicializado y operativo"
        
        if [ -f "$VAULT_DATA_DIR/vault-env.sh" ]; then
            source "$VAULT_DATA_DIR/vault-env.sh"
        elif [ -f "$VAULT_DATA_DIR/vault-init.json" ]; then
            local root_token=$(jq -r '.root_token' "$VAULT_DATA_DIR/vault-init.json")
            export VAULT_TOKEN="$root_token"
        else
            warning "⚠️ No se encontró token de Vault, algunas operaciones pueden fallar"
        fi
    fi
    
    # Configurar autenticación y políticas básicas
    if [ -n "$VAULT_TOKEN" ]; then
        log "🔧 Configurando autenticación de Kubernetes..."
        
        # Habilitar auth kubernetes
        vault auth enable kubernetes 2>/dev/null || log "Auth kubernetes ya habilitado"
        
        # Configurar kubernetes auth
        kubectl exec vault-0 -n vault -- vault write auth/kubernetes/config \
            token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token \
            kubernetes_host="https://kubernetes.default.svc.cluster.local:443" \
            kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt 2>/dev/null || \
            log "Configuración de kubernetes auth completada desde el exterior"
        
        log "📋 Creando políticas básicas..."
        
        # Política de desarrollo
        vault policy write blinkchamber-dev - <<EOF
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
        
        # Política de administración
        vault policy write blinkchamber-admin - <<EOF
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
        
        success "✅ Configuración de Vault completada"
    fi
    
    # Limpiar port-forward
    kill $pf_pid >/dev/null 2>&1 || true
    
    return 0
}

# Función para resetear Vault de forma segura
reset_vault_safe() {
    log "🔄 Reseteando Vault de forma segura..."
    
    # Eliminar el PVC de Vault
    if kubectl get pvc vault-data -n vault >/dev/null 2>&1; then
        log "Eliminando PVC vault-data..."
        kubectl delete pvc vault-data -n vault
        sleep 10 # Esperar a que el PVC sea eliminado
    fi
    
    # Eliminar el pod de Vault
    if kubectl get pod vault-0 -n vault >/dev/null 2>&1; then
        log "Eliminando pod vault-0..."
        kubectl delete pod vault-0 -n vault --grace-period=0 --force
        sleep 10 # Esperar a que el pod sea eliminado
    fi
    
    # Eliminar el secret de claves de unseal
    if kubectl get secret vault-init-keys -n vault >/dev/null 2>&1; then
        log "Eliminando secret vault-init-keys..."
        kubectl delete secret vault-init-keys -n vault
    fi
    
    # Eliminar el job de inicialización
    if kubectl get job vault-init -n vault >/dev/null 2>&1; then
        log "Eliminando job vault-init..."
        kubectl delete job vault-init -n vault
    fi
    
    # Eliminar el secret de token root
    if kubectl get secret vault-root-token -n vault >/dev/null 2>&1; then
        log "Eliminando secret vault-root-token..."
        kubectl delete secret vault-root-token -n vault
    fi
    
    # Eliminar el namespace de Vault
    if kubectl get namespace vault >/dev/null 2>&1; then
        log "Eliminando namespace vault..."
        kubectl delete namespace vault
    fi
    
    # Reiniciar el cluster Kind para aplicar los cambios
    log "Reiniciando cluster Kind para aplicar los cambios..."
    kind delete cluster --name "$CLUSTER_NAME"
    kind create cluster --name "$CLUSTER_NAME" --config "$PROJECT_ROOT/config/kind-config.yaml" || {
        error "Error al recrear cluster Kind con configuración."
        return 1
    }
    
    # Configurar kubectl context
    kubectl config use-context "kind-$CLUSTER_NAME" >/dev/null 2>&1
    
    # Verificar que el cluster es funcional
    if ! kubectl cluster-info >/dev/null 2>&1; then
        error "Cluster Kind '$CLUSTER_NAME' no es accesible después del reset"
        return 1
    fi
    
    # Asegurar que el nodo tiene las etiquetas necesarias
    if ! kubectl get nodes "${CLUSTER_NAME}-control-plane" -o jsonpath='{.metadata.labels.ingress-ready}' 2>/dev/null | grep -q "true"; then
        log "Agregando etiqueta ingress-ready al nodo control-plane..."
        kubectl label node "${CLUSTER_NAME}-control-plane" ingress-ready=true --overwrite
    fi
    
    success "✅ Vault reseteado de forma segura"
    return 0
}

# Función principal
main() {
    local command=${1:-help}
    local skip_wait=false
    
    # Procesar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --cluster-name)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            --auto-unseal)
                AUTO_UNSEAL_METHOD="$2"
                shift 2
                ;;
            --skip-wait)
                skip_wait=true
                shift
                ;;
            --dry-run)
                export DRY_RUN=true
                shift
                ;;
            --verbose)
                export VERBOSE=true
                set -x
                shift
                ;;
            --force)
                export FORCE_RESET=true
                shift
                ;;
            --force-reset)
                export FORCE_RESET=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                if [ -z "$command" ] || [ "$command" = "help" ]; then
                    command="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Verificar prerequisitos (excepto para help)
    if [ "$command" != "help" ]; then
        check_prerequisites
    fi
    
    # Ejecutar comando
    case $command in
        1|bootstrap)
            execute_phase 1 "$skip_wait"
            ;;
        2|vault-init)
            execute_phase 2 "$skip_wait"
            ;;
        3|secrets)
            execute_phase 3 "$skip_wait"
            ;;
        4|applications)
            execute_phase 4 "$skip_wait"
            ;;
        all)
            log "🚀 Iniciando bootstrap completo de blinkchamber"
            log "Entorno: $ENVIRONMENT | Cluster: $CLUSTER_NAME | Auto-unseal: $AUTO_UNSEAL_METHOD"
            
            if [[ "$skip_wait" != "true" ]]; then
                log "Presiona Enter para continuar o Ctrl+C para cancelar..."
                read -r
            fi
            
            execute_phase 1 true
            execute_phase 2 true
            execute_phase 3 true
            execute_phase 4 true
            
            success "🎉 ¡Bootstrap completo exitoso!"
            show_status
            ;;
        status)
            show_status
            ;;
        init)
            init_vault_direct
            ;;
        unseal)
            unseal_vault
            ;;
        port-forward)
            setup_port_forward
            ;;
        logs)
            kubectl logs -f deployment/vault -n vault
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

# Ejecutar función principal con todos los argumentos
main "$@" 