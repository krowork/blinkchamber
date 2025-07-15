#!/bin/bash

# scripts/test-error-handling.sh - Script de prueba para el nuevo sistema de manejo de errores
# Demuestra cómo el sistema captura y reporta errores cuando el script se detiene abruptamente

set -e

# Cargar bibliotecas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/scripts/lib/common.sh" 2>/dev/null || {
    # Funciones básicas si no existe common.sh
    log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*"; }
    error() { echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" >&2; }
    success() { echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $*"; }
    warning() { echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $*"; }
}

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función para mostrar ayuda
show_help() {
    cat << EOF
🧪 Script de Prueba - Sistema de Manejo de Errores

Uso: $0 [tipo_de_error]

Tipos de error para probar:
  kubectl-error      Simular error de kubectl (comando no encontrado)
  vault-error        Simular error de Vault (namespace no existe)
  terraform-error    Simular error de Terraform (no instalado)
  helm-error         Simular error de Helm (no instalado)
  timeout-error      Simular timeout (comando que tarda demasiado)
  syntax-error       Simular error de sintaxis
  permission-error   Simular error de permisos
  network-error      Simular error de red
  all                Probar todos los tipos de error

Ejemplos:
  $0 kubectl-error    # Probar manejo de error de kubectl
  $0 all              # Probar todos los tipos de error
  $0 --help           # Mostrar esta ayuda

EOF
}

# Función para simular error de kubectl
test_kubectl_error() {
    echo -e "${BLUE}🧪 Probando manejo de error de kubectl...${NC}"
    echo "Ejecutando comando que fallará: kubectl get pods -n namespace-que-no-existe"
    
    # Este comando fallará y debería ser capturado por el sistema de manejo de errores
    kubectl get pods -n namespace-que-no-existe
}

# Función para simular error de Vault
test_vault_error() {
    echo -e "${BLUE}🧪 Probando manejo de error de Vault...${NC}"
    echo "Ejecutando comando que fallará: kubectl exec -n vault statefulset/vault -- vault status"
    
    # Este comando fallará si Vault no está desplegado
    kubectl exec -n vault statefulset/vault -- vault status
}

# Función para simular error de Terraform
test_terraform_error() {
    echo -e "${BLUE}🧪 Probando manejo de error de Terraform...${NC}"
    echo "Ejecutando comando que fallará: terraform validate en directorio inexistente"
    
    # Este comando fallará si Terraform no está instalado o el directorio no existe
    cd /tmp/directorio-que-no-existe && terraform validate
}

# Función para simular error de Helm
test_helm_error() {
    echo -e "${BLUE}🧪 Probando manejo de error de Helm...${NC}"
    echo "Ejecutando comando que fallará: helm lint chart-que-no-existe"
    
    # Este comando fallará si Helm no está instalado o el chart no existe
    helm lint /tmp/chart-que-no-existe
}

# Función para simular timeout
test_timeout_error() {
    echo -e "${BLUE}🧪 Probando manejo de error de timeout...${NC}"
    echo "Ejecutando comando que tardará demasiado: sleep 10 (con timeout de 2s)"
    
    # Este comando debería fallar por timeout
    timeout 2 sleep 10
}

# Función para simular error de sintaxis
test_syntax_error() {
    echo -e "${BLUE}🧪 Probando manejo de error de sintaxis...${NC}"
    echo "Ejecutando comando con sintaxis incorrecta"
    
    # Este comando tiene sintaxis incorrecta
    echo "comando con sintaxis incorrecta" | bash
}

# Función para simular error de permisos
test_permission_error() {
    echo -e "${BLUE}🧪 Probando manejo de error de permisos...${NC}"
    echo "Ejecutando comando que requiere permisos especiales"
    
    # Este comando requiere permisos de root
    cat /etc/shadow
}

# Función para simular error de red
test_network_error() {
    echo -e "${BLUE}🧪 Probando manejo de error de red...${NC}"
    echo "Ejecutando comando que fallará por error de red"
    
    # Este comando fallará por error de red
    curl -m 5 http://servidor-que-no-existe.com
}

# Función para probar todos los errores
test_all_errors() {
    echo -e "${PURPLE}🧪 Probando todos los tipos de error...${NC}"
    echo "=========================================="
    
    local tests=(
        "kubectl-error"
        "vault-error"
        "terraform-error"
        "helm-error"
        "timeout-error"
        "syntax-error"
        "permission-error"
        "network-error"
    )
    
    for test in "${tests[@]}"; do
        echo ""
        echo -e "${CYAN}--- Probando: $test ---${NC}"
        case $test in
            kubectl-error)
                test_kubectl_error
                ;;
            vault-error)
                test_vault_error
                ;;
            terraform-error)
                test_terraform_error
                ;;
            helm-error)
                test_helm_error
                ;;
            timeout-error)
                test_timeout_error
                ;;
            syntax-error)
                test_syntax_error
                ;;
            permission-error)
                test_permission_error
                ;;
            network-error)
                test_network_error
                ;;
        esac
        echo -e "${GREEN}✅ Test $test completado${NC}"
    done
}

# Función principal
main() {
    echo -e "\n=============================="
    echo "🧪 Script de Prueba - Manejo de Errores"
    echo "=============================="
    
    # Parsear argumentos
    local error_type="${1:-}"
    
    if [[ -z "$error_type" || "$error_type" == "--help" || "$error_type" == "-h" ]]; then
        show_help
        exit 0
    fi
    
    echo "🔧 Configuración:"
    echo "  Tipo de error: $error_type"
    echo "  Timestamp: $(date)"
    echo ""
    
    # Ejecutar test según el tipo de error
    case $error_type in
        kubectl-error)
            test_kubectl_error
            ;;
        vault-error)
            test_vault_error
            ;;
        terraform-error)
            test_terraform_error
            ;;
        helm-error)
            test_helm_error
            ;;
        timeout-error)
            test_timeout_error
            ;;
        syntax-error)
            test_syntax_error
            ;;
        permission-error)
            test_permission_error
            ;;
        network-error)
            test_network_error
            ;;
        all)
            test_all_errors
            ;;
        *)
            echo -e "${RED}❌ Tipo de error no reconocido: $error_type${NC}"
            show_help
            exit 1
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}✅ Prueba completada${NC}"
    echo ""
    echo "💡 Nota: Este script está diseñado para fallar y demostrar"
    echo "   el sistema de manejo de errores. Los fallos son esperados."
}

# Ejecutar función principal
main "$@" 