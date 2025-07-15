#!/bin/bash

# scripts/install-syntax-tools.sh - Instalador de herramientas de validación de sintaxis
# Instala todas las herramientas necesarias para los tests de validación de sintaxis

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
NC='\033[0m'

# Función para mostrar ayuda
show_help() {
    cat << EOF
🔧 Instalador de Herramientas de Validación de Sintaxis - blinkchamber

Uso: $0 [opciones]

Opciones:
  --all              Instalar todas las herramientas
  --terraform        Instalar Terraform
  --helm             Instalar Helm
  --yamllint         Instalar yamllint
  --jq               Instalar jq
  --shellcheck       Instalar shellcheck
  --check            Verificar herramientas instaladas
  --help             Mostrar esta ayuda

Ejemplos:
  $0 --all                    # Instalar todas las herramientas
  $0 --check                  # Verificar qué está instalado
  $0 --yamllint --jq          # Instalar solo yamllint y jq

EOF
}

# Función para detectar el sistema operativo
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para instalar Terraform
install_terraform() {
    if command_exists terraform; then
        success "Terraform ya está instalado: $(terraform version | head -1)"
        return 0
    fi
    
    log "Instalando Terraform..."
    local os=$(detect_os)
    
    case $os in
        "ubuntu"|"debian")
            # Agregar repositorio oficial de HashiCorp
            wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
            sudo apt update && sudo apt install -y terraform
            ;;
        "centos"|"rhel"|"fedora")
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
            sudo yum install -y terraform
            ;;
        "macos")
            if command_exists brew; then
                brew install terraform
            else
                error "Homebrew no está instalado. Instala Homebrew primero."
                return 1
            fi
            ;;
        *)
            error "Sistema operativo no soportado: $os"
            error "Instala Terraform manualmente desde: https://www.terraform.io/downloads"
            return 1
            ;;
    esac
    
    success "Terraform instalado: $(terraform version | head -1)"
}

# Función para instalar Helm
install_helm() {
    if command_exists helm; then
        success "Helm ya está instalado: $(helm version --short)"
        return 0
    fi
    
    log "Instalando Helm..."
    
    # Descargar e instalar Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    success "Helm instalado: $(helm version --short)"
}

# Función para instalar yamllint
install_yamllint() {
    if command_exists yamllint; then
        success "yamllint ya está instalado: $(yamllint --version)"
        return 0
    fi
    
    log "Instalando yamllint..."
    
    if command_exists pip3; then
        pip3 install yamllint
    elif command_exists pip; then
        pip install yamllint
    else
        # Intentar instalar pip primero
        local os=$(detect_os)
        case $os in
            "ubuntu"|"debian")
                sudo apt update && sudo apt install -y python3-pip
                pip3 install yamllint
                ;;
            "centos"|"rhel"|"fedora")
                sudo yum install -y python3-pip
                pip3 install yamllint
                ;;
            "macos")
                if command_exists brew; then
                    brew install yamllint
                else
                    error "Homebrew no está instalado. Instala yamllint manualmente."
                    return 1
                fi
                ;;
            *)
                error "No se pudo instalar yamllint. Instálalo manualmente: pip install yamllint"
                return 1
                ;;
        esac
    fi
    
    success "yamllint instalado: $(yamllint --version)"
}

# Función para instalar jq
install_jq() {
    if command_exists jq; then
        success "jq ya está instalado: $(jq --version)"
        return 0
    fi
    
    log "Instalando jq..."
    local os=$(detect_os)
    
    case $os in
        "ubuntu"|"debian")
            sudo apt update && sudo apt install -y jq
            ;;
        "centos"|"rhel"|"fedora")
            sudo yum install -y jq
            ;;
        "macos")
            if command_exists brew; then
                brew install jq
            else
                error "Homebrew no está instalado. Instala jq manualmente."
                return 1
            fi
            ;;
        *)
            error "Sistema operativo no soportado: $os"
            error "Instala jq manualmente desde: https://stedolan.github.io/jq/download/"
            return 1
            ;;
    esac
    
    success "jq instalado: $(jq --version)"
}

# Función para instalar shellcheck
install_shellcheck() {
    if command_exists shellcheck; then
        success "shellcheck ya está instalado: $(shellcheck --version | head -1)"
        return 0
    fi
    
    log "Instalando shellcheck..."
    local os=$(detect_os)
    
    case $os in
        "ubuntu"|"debian")
            sudo apt update && sudo apt install -y shellcheck
            ;;
        "centos"|"rhel"|"fedora")
            sudo yum install -y epel-release
            sudo yum install -y ShellCheck
            ;;
        "macos")
            if command_exists brew; then
                brew install shellcheck
            else
                error "Homebrew no está instalado. Instala shellcheck manualmente."
                return 1
            fi
            ;;
        *)
            error "Sistema operativo no soportado: $os"
            error "Instala shellcheck manualmente desde: https://github.com/koalaman/shellcheck#installing"
            return 1
            ;;
    esac
    
    success "shellcheck instalado: $(shellcheck --version | head -1)"
}

# Función para verificar herramientas instaladas
check_tools() {
    echo -e "${BLUE}🔍 Verificando herramientas de validación de sintaxis...${NC}"
    echo ""
    
    local tools=("terraform" "helm" "yamllint" "jq" "shellcheck")
    local all_installed=true
    
    for tool in "${tools[@]}"; do
        if command_exists "$tool"; then
            echo -e "${GREEN}✅ $tool: $(command -v $tool)${NC}"
            case $tool in
                "terraform")
                    echo "   Versión: $(terraform version | head -1)"
                    ;;
                "helm")
                    echo "   Versión: $(helm version --short)"
                    ;;
                "yamllint")
                    echo "   Versión: $(yamllint --version)"
                    ;;
                "jq")
                    echo "   Versión: $(jq --version)"
                    ;;
                "shellcheck")
                    echo "   Versión: $(shellcheck --version | head -1)"
                    ;;
            esac
        else
            echo -e "${RED}❌ $tool: No instalado${NC}"
            all_installed=false
        fi
        echo ""
    done
    
    if [[ "$all_installed" == "true" ]]; then
        echo -e "${GREEN}🎉 Todas las herramientas están instaladas y listas para usar${NC}"
        echo ""
        echo "Puedes ejecutar los tests de sintaxis con:"
        echo "  ./scripts/test-infrastructure-exhaustive.sh syntax"
    else
        echo -e "${YELLOW}⚠️  Algunas herramientas faltan. Instálalas con:${NC}"
        echo "  $0 --all"
    fi
}

# Función principal
main() {
    echo -e "\n=============================="
    echo "🔧 Instalador de Herramientas de Validación de Sintaxis"
    echo "=============================="
    
    # Parsear argumentos
    local install_all=false
    local install_terraform=false
    local install_helm=false
    local install_yamllint=false
    local install_jq=false
    local install_shellcheck=false
    local check_only=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                install_all=true
                shift
                ;;
            --terraform)
                install_terraform=true
                shift
                ;;
            --helm)
                install_helm=true
                shift
                ;;
            --yamllint)
                install_yamllint=true
                shift
                ;;
            --jq)
                install_jq=true
                shift
                ;;
            --shellcheck)
                install_shellcheck=true
                shift
                ;;
            --check)
                check_only=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "❌ Opción no reconocida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Si no se especificó ninguna opción, mostrar ayuda
    if [[ "$install_all" == "false" && "$install_terraform" == "false" && "$install_helm" == "false" && "$install_yamllint" == "false" && "$install_jq" == "false" && "$install_shellcheck" == "false" && "$check_only" == "false" ]]; then
        show_help
        exit 0
    fi
    
    # Verificar herramientas si se solicita
    if [[ "$check_only" == "true" ]]; then
        check_tools
        exit 0
    fi
    
    # Instalar herramientas según las opciones
    if [[ "$install_all" == "true" ]]; then
        install_terraform
        install_helm
        install_yamllint
        install_jq
        install_shellcheck
    else
        [[ "$install_terraform" == "true" ]] && install_terraform
        [[ "$install_helm" == "true" ]] && install_helm
        [[ "$install_yamllint" == "true" ]] && install_yamllint
        [[ "$install_jq" == "true" ]] && install_jq
        [[ "$install_shellcheck" == "true" ]] && install_shellcheck
    fi
    
    echo ""
    echo -e "${GREEN}✅ Instalación completada${NC}"
    echo ""
    echo "Ahora puedes ejecutar los tests de sintaxis:"
    echo "  ./scripts/test-infrastructure-exhaustive.sh syntax"
    echo ""
    echo "O verificar todas las herramientas:"
    echo "  $0 --check"
}

# Ejecutar función principal
main "$@" 