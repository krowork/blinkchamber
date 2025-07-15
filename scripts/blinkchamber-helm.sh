#!/bin/bash

# scripts/blinkchamber-helm.sh - Script de gestión para Helm chart de blinkchamber

set -e

# Cargar bibliotecas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/scripts/lib/common.sh"
source "$PROJECT_ROOT/scripts/lib/k8s.sh"

# Verbose helpers
verbose() {
    if [[ "${VERBOSE:-false}" == "true" || "${DEBUG:-false}" == "true" ]]; then
        echo -e "[VERBOSE] $@"
    fi
}

verbose_env() {
    if [[ "${VERBOSE:-false}" == "true" || "${DEBUG:-false}" == "true" ]]; then
        echo "[VERBOSE] Variables de entorno relevantes:"
        echo "  RELEASE_NAME=$RELEASE_NAME"
        echo "  NAMESPACE=$NAMESPACE"
        echo "  HELM_CHART_DIR=$HELM_CHART_DIR"
        echo "  VERBOSE=${VERBOSE:-false}"
        echo "  DEBUG=${DEBUG:-false}"
        echo "  DRY_RUN=${DRY_RUN:-false}"
    fi
}

# Ejecuta un comando mostrando el comando, su salida y errores
verbose_run() {
    local cmd="$1"
    local desc="$2"
    echo -e "\n=============================="
    echo -e "🔹 Ejecutando: $desc"
    echo -e "🔹 Comando: $cmd"
    echo -e "=============================="
    verbose_env
    
    # Ejecutar el comando y capturar tanto stdout como stderr
    echo -e "\n--- Ejecutando comando ---"
    local output
    local error_output
    
    # Ejecutar el comando y capturar la salida
    if output=$(eval "$cmd" 2>&1); then
        local status=0
    else
        local status=$?
    fi
    
    echo -e "\n--- Salida completa del comando ---"
    echo "$output"
    echo -e "--- Fin de la salida ---\n"
    
    if [[ $status -ne 0 ]]; then
        echo -e "❌ Error ejecutando: $desc (código $status)"
        echo -e "❌ Comando que falló: $cmd"
        echo -e "❌ Salida del error:"
        echo "$output"
        echo -e "\n🔍 Sugerencias de debug:"
        echo -e "   - Verifica que el comando sea válido"
        echo -e "   - Revisa los permisos y configuración"
        echo -e "   - Ejecuta el comando manualmente para más detalles"
        return $status
    else
        echo -e "✅ Comando ejecutado correctamente: $desc"
    fi
    echo -e "==============================\n"
}

# Variables específicas del script
HELM_CHART_DIR="$PROJECT_ROOT/blinkchamber"
RELEASE_NAME="blinkchamber"
NAMESPACE="blinkchamber"

# Función para mostrar ayuda específica
show_helm_help() {
    cat << EOF
🚀 blinkchamber-helm - Gestión del Helm chart de blinkchamber

Uso: $0 [comando] [opciones]

Comandos:
  install     Instalar el chart de blinkchamber
  upgrade     Actualizar el chart de blinkchamber
  uninstall   Desinstalar el chart de blinkchamber
  status      Mostrar estado del release
  values      Mostrar valores actuales
  lint        Validar el chart
  template    Generar templates sin instalar
  test        Ejecutar tests del chart
  port-forward Configurar port-forwarding
  logs        Mostrar logs de componentes
  debug       Modo debug para troubleshooting
  cleanup     Limpiar recursos huérfanos

Opciones de install/upgrade:
  --values FILE     Archivo de valores personalizado
  --set KEY=VAL     Establecer valor específico
  --dry-run         Simular sin ejecutar
  --wait            Esperar a que los recursos estén listos
  --timeout DUR     Timeout para la operación (default: 10m)

Opciones de port-forward:
  --all             Configurar todos los port-forwards
  --vault           Solo Vault (puerto 8200)
  --zitadel         Solo Zitadel (puerto 8080)
  --mailu           Solo Mailu (puerto 8025)
  --grafana         Solo Grafana (puerto 3000)
  --prometheus      Solo Prometheus (puerto 9090)

Opciones de logs:
  --component NAME  Mostrar logs de componente específico
  --follow          Seguir logs en tiempo real
  --lines N         Número de líneas a mostrar

Variables de entorno:
  RELEASE_NAME=name     Nombre del release (default: blinkchamber)
  NAMESPACE=ns          Namespace (default: blinkchamber)
  VERBOSE=true          Modo verbose
  DEBUG=true            Modo debug
  DRY_RUN=true          Simular sin ejecutar

Ejemplos:
  $0 install --wait                    # Instalar y esperar
  $0 install --values custom.yaml      # Instalar con valores personalizados
  $0 upgrade --set global.domain=test.local  # Actualizar con valor específico
  $0 status                            # Estado del release
  $0 port-forward --all                # Configurar todos los port-forwards
  $0 logs --component vault --follow   # Logs de Vault en tiempo real
  $0 uninstall                         # Desinstalar release

Para más información, consulta la documentación en blinkchamber/README.md

EOF
}

# Función para verificar prerrequisitos
check_helm_prerequisites() {
    echo -e "\n=============================="
    echo "🔍 [INICIO] Verificando prerrequisitos..."
    echo "=============================="
    verbose_env
    
    # Verificar Helm
    echo "🔹 Verificando Helm..."
    if ! command -v helm &> /dev/null; then
        echo "❌ Helm no está instalado"
        echo "❌ Instala Helm: https://helm.sh/docs/intro/install/"
        return 1
    else
        echo "✅ Helm encontrado: $(helm version --short)"
    fi
    
    # Verificar kubectl
    echo "🔹 Verificando kubectl..."
    if ! command -v kubectl &> /dev/null; then
        echo "❌ kubectl no está instalado"
        echo "❌ Instala kubectl: https://kubernetes.io/docs/tasks/tools/"
        return 1
    else
        echo "✅ kubectl encontrado: $(kubectl version --client | head -n1)"
    fi
    
    # Verificar conexión al cluster
    echo "🔹 Verificando conexión al cluster..."
    verbose_run "kubectl cluster-info" "Verificar conexión al cluster"
    
    # Verificar que el chart existe
    echo "🔹 Verificando directorio del chart..."
    if [[ ! -d "$HELM_CHART_DIR" ]]; then
        echo "❌ Directorio del chart no encontrado: $HELM_CHART_DIR"
        return 1
    else
        echo "✅ Directorio del chart encontrado: $HELM_CHART_DIR"
    fi
    
    # Verificar Chart.yaml
    echo "🔹 Verificando Chart.yaml..."
    if [[ ! -f "$HELM_CHART_DIR/Chart.yaml" ]]; then
        echo "❌ Chart.yaml no encontrado en: $HELM_CHART_DIR"
        return 1
    else
        echo "✅ Chart.yaml encontrado"
    fi
    
    echo "✅ Prerrequisitos verificados"
    echo -e "=============================="
    echo "🔍 [FIN] Verificación de prerrequisitos"
    echo "==============================\n"
}

# Función para agregar repositorios
add_helm_repos() {
    echo -e "\n=============================="
    echo "📦 [INICIO] Agregando repositorios de Helm..."
    echo "=============================="
    verbose_env
    
    # Mostrar repositorios actuales
    echo "🔹 Repositorios actuales:"
    verbose_run "helm repo list" "Listar repositorios actuales"
    
    # HashiCorp (Vault)
    echo "🔹 Verificando repositorio HashiCorp..."
    if ! helm repo list | grep -q "hashicorp"; then
        verbose_run "helm repo add hashicorp https://helm.releases.hashicorp.com" "Agregar repo HashiCorp"
    else
        echo "✅ Repositorio HashiCorp ya existe"
    fi
    
    # Bitnami (PostgreSQL)
    echo "🔹 Verificando repositorio Bitnami..."
    if ! helm repo list | grep -q "bitnami"; then
        verbose_run "helm repo add bitnami https://charts.bitnami.com/bitnami" "Agregar repo Bitnami"
    else
        echo "✅ Repositorio Bitnami ya existe"
    fi
    
    # Prometheus Community
    echo "🔹 Verificando repositorio Prometheus..."
    if ! helm repo list | grep -q "prometheus-community"; then
        verbose_run "helm repo add prometheus-community https://prometheus-community.github.io/helm-charts" "Agregar repo Prometheus"
    else
        echo "✅ Repositorio Prometheus ya existe"
    fi
    
    # Grafana
    echo "🔹 Verificando repositorio Grafana..."
    if ! helm repo list | grep -q "grafana"; then
        verbose_run "helm repo add grafana https://grafana.github.io/helm-charts" "Agregar repo Grafana"
    else
        echo "✅ Repositorio Grafana ya existe"
    fi
    
    # Actualizar repositorios
    echo "🔹 Actualizando repositorios..."
    verbose_run "helm repo update" "Actualizar repositorios"
    
    # Mostrar repositorios finales
    echo "🔹 Repositorios finales:"
    verbose_run "helm repo list" "Listar repositorios finales"
    
    echo "✅ Repositorios configurados"
    echo -e "=============================="
    echo "📦 [FIN] Configuración de repositorios"
    echo "==============================\n"
}

# Función para instalar el chart
install_chart() {
    local values_file=$1
    local dry_run=${2:-false}
    local wait=${3:-false}
    local timeout=${4:-"10m"}
    
    echo -e "\n=============================="
    echo "🚀 [INICIO] Instalando chart de blinkchamber"
    echo "=============================="
    verbose_env
    
    # Verificar prerrequisitos
    check_helm_prerequisites || exit 1
    
    # Agregar repositorios
    add_helm_repos
    
    # Construir comando de instalación
    local helm_cmd="helm install $RELEASE_NAME $HELM_CHART_DIR -n $NAMESPACE --create-namespace"
    
    # Agregar opciones
    if [[ -n "$values_file" ]]; then
        helm_cmd="$helm_cmd -f $values_file"
    fi
    
    if [[ "$wait" == "true" ]]; then
        helm_cmd="$helm_cmd --wait --timeout $timeout"
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run --debug"
    fi
    
    # Validar chart antes de instalar
    echo "🔹 Validando chart antes de la instalación..."
    verbose_run "helm lint $HELM_CHART_DIR" "Validar sintaxis del chart" || {
        echo "❌ Error en la validación del chart. Corrige los errores antes de continuar."
        return 1
    }
    
    # Probar template generation
    echo "🔹 Probando generación de templates..."
    verbose_run "helm template $RELEASE_NAME $HELM_CHART_DIR -n $NAMESPACE" "Generar templates de prueba" || {
        echo "❌ Error en la generación de templates. Revisa la configuración del chart."
        return 1
    }
    
    # Ejecutar instalación
    if [[ "${DRY_RUN:-false}" != "true" ]]; then
        echo "🔹 Iniciando instalación del chart..."
        verbose_run "$helm_cmd" "Instalar chart" || {
            echo "❌ Error durante la instalación del chart."
            echo "🔍 Verificando estado del namespace..."
            verbose_run "kubectl get all -n $NAMESPACE" "Verificar recursos en namespace"
            return 1
        }
        
        if [[ "$wait" == "true" ]]; then
            echo "✅ Chart instalado exitosamente"
            show_post_install_info
        else
            echo "✅ Chart instalado (ejecutando en background)"
        fi
    else
        echo "[DRY-RUN] Comando que se ejecutaría:"
        echo "$helm_cmd"
    fi
    echo -e "=============================="
    echo "🚀 [FIN] Instalación chart de blinkchamber"
    echo "==============================\n"
}

# Función para actualizar el chart
upgrade_chart() {
    local values_file=$1
    local dry_run=${2:-false}
    local wait=${3:-false}
    local timeout=${4:-"10m"}
    
    echo -e "\n=============================="
    echo "🔄 [INICIO] Actualizando chart de blinkchamber"
    echo "=============================="
    verbose_env
    
    # Verificar que el release existe
    echo "🔹 Verificando existencia del release..."
    verbose_run "helm list -n $NAMESPACE" "Listar releases en namespace"
    
    if ! helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        echo "❌ Release '$RELEASE_NAME' no encontrado en namespace '$NAMESPACE'"
        echo "❌ Ejecuta 'install' primero"
        return 1
    else
        echo "✅ Release '$RELEASE_NAME' encontrado"
    fi
    
    # Construir comando de actualización
    local helm_cmd="helm upgrade $RELEASE_NAME $HELM_CHART_DIR -n $NAMESPACE"
    
    # Agregar opciones
    if [[ -n "$values_file" ]]; then
        helm_cmd="$helm_cmd -f $values_file"
        echo "🔹 Usando archivo de valores: $values_file"
    fi
    
    if [[ "$wait" == "true" ]]; then
        helm_cmd="$helm_cmd --wait --timeout $timeout"
        echo "🔹 Modo wait activado con timeout: $timeout"
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run --debug"
        echo "🔹 Modo dry-run activado"
    fi
    
    echo "🔹 Comando de actualización: $helm_cmd"
    
    # Ejecutar actualización
    if [[ "${DRY_RUN:-false}" != "true" ]]; then
        verbose_run "$helm_cmd" "Actualizar chart"
        
        if [[ "$wait" == "true" ]]; then
            echo "✅ Chart actualizado exitosamente"
        else
            echo "✅ Chart actualizado (ejecutando en background)"
        fi
    else
        echo "[DRY-RUN] Comando que se ejecutaría:"
        echo "$helm_cmd"
    fi
    
    echo -e "=============================="
    echo "🔄 [FIN] Actualización chart de blinkchamber"
    echo "==============================\n"
}

# Función para desinstalar el chart
uninstall_chart() {
    local dry_run=${1:-false}
    
    echo -e "\n=============================="
    echo "🧹 [INICIO] Desinstalando chart de blinkchamber"
    echo "=============================="
    verbose_env
    
    # Verificar que el release existe
    echo "🔹 Verificando existencia del release..."
    verbose_run "helm list -n $NAMESPACE" "Listar releases en namespace"
    
    if ! helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        echo "⚠️ Release '$RELEASE_NAME' no encontrado en namespace '$NAMESPACE'"
        echo "⚠️ No hay nada que desinstalar"
        return 0
    else
        echo "✅ Release '$RELEASE_NAME' encontrado, procediendo con desinstalación"
    fi
    
    local helm_cmd="helm uninstall $RELEASE_NAME -n $NAMESPACE"
    
    if [[ "$dry_run" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run"
        echo "🔹 Modo dry-run activado"
    fi
    
    echo "🔹 Comando de desinstalación: $helm_cmd"
    
    if [[ "${DRY_RUN:-false}" != "true" ]]; then
        verbose_run "$helm_cmd" "Desinstalar chart"
        echo "✅ Chart desinstalado exitosamente"
    else
        echo "[DRY-RUN] Comando que se ejecutaría:"
        echo "$helm_cmd"
    fi
    
    echo -e "=============================="
    echo "🧹 [FIN] Desinstalación chart de blinkchamber"
    echo "==============================\n"
}

# Función para mostrar estado del release
show_release_status() {
    echo -e "\n=============================="
    echo "📊 [INICIO] Estado del release blinkchamber"
    echo "=============================="
    verbose_env
    
    # Verificar que el release existe
    echo "🔹 Verificando existencia del release..."
    verbose_run "helm list -n $NAMESPACE" "Listar releases en namespace"
    
    if ! helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        echo "❌ Release '$RELEASE_NAME' no encontrado en namespace '$NAMESPACE'"
        return 1
    else
        echo "✅ Release '$RELEASE_NAME' encontrado"
    fi
    
    # Mostrar estado del release
    echo ""
    echo "🔹 Estado detallado del release:"
    verbose_run "helm status $RELEASE_NAME -n $NAMESPACE" "Mostrar estado del release"
    
    # Mostrar recursos
    echo ""
    echo "🔹 Recursos del release:"
    verbose_run "kubectl get all -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME" "Listar recursos del release"
    
    # Mostrar PVCs
    echo ""
    echo "🔹 Persistent Volume Claims:"
    verbose_run "kubectl get pvc -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME" "Listar PVCs del release"
    
    # Mostrar Ingress
    echo ""
    echo "🔹 Ingress:"
    verbose_run "kubectl get ingress -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME" "Listar Ingress del release"
    
    # Mostrar Services
    echo ""
    echo "🔹 Services:"
    verbose_run "kubectl get services -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME" "Listar Services del release"
    
    echo -e "=============================="
    echo "📊 [FIN] Estado del release blinkchamber"
    echo "==============================\n"
}

# Función para mostrar valores actuales
show_current_values() {
    echo -e "\n=============================="
    echo "📋 [INICIO] Valores actuales del release"
    echo "=============================="
    verbose_env
    
    # Verificar que el release existe
    echo "🔹 Verificando existencia del release..."
    verbose_run "helm list -n $NAMESPACE" "Listar releases en namespace"
    
    if ! helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        echo "❌ Release '$RELEASE_NAME' no encontrado en namespace '$NAMESPACE'"
        return 1
    else
        echo "✅ Release '$RELEASE_NAME' encontrado"
    fi
    
    echo "🔹 Valores actuales del release:"
    verbose_run "helm get values $RELEASE_NAME -n $NAMESPACE" "Mostrar valores del release"
    
    echo -e "=============================="
    echo "📋 [FIN] Valores actuales del release"
    echo "==============================\n"
}

# Función para validar el chart
lint_chart() {
    echo -e "\n=============================="
    echo "🔍 [INICIO] Validando chart de blinkchamber"
    echo "=============================="
    verbose_env
    
    if [[ ! -d "$HELM_CHART_DIR" ]]; then
        echo "❌ Directorio del chart no encontrado: $HELM_CHART_DIR"
        return 1
    else
        echo "✅ Directorio del chart encontrado: $HELM_CHART_DIR"
    fi
    
    echo "🔹 Contenido del directorio del chart:"
    verbose_run "ls -la $HELM_CHART_DIR" "Listar contenido del directorio del chart"
    
    echo "🔹 Validando chart con Helm lint:"
    verbose_run "helm lint $HELM_CHART_DIR" "Validar chart"
    
    echo "✅ Chart validado exitosamente"
    echo -e "=============================="
    echo "🔍 [FIN] Validación del chart"
    echo "==============================\n"
}

# Función para generar templates
template_chart() {
    local values_file=$1
    
    echo -e "\n=============================="
    echo "📄 [INICIO] Generando templates del chart"
    echo "=============================="
    verbose_env
    
    local helm_cmd="helm template $RELEASE_NAME $HELM_CHART_DIR -n $NAMESPACE"
    
    if [[ -n "$values_file" ]]; then
        helm_cmd="$helm_cmd -f $values_file"
        echo "🔹 Usando archivo de valores: $values_file"
    else
        echo "🔹 Usando valores por defecto"
    fi
    
    echo "🔹 Comando de template: $helm_cmd"
    
    verbose_run "$helm_cmd" "Generar templates"
    
    echo -e "=============================="
    echo "📄 [FIN] Generación de templates"
    echo "==============================\n"
}

# Función para configurar port-forwarding
setup_helm_port_forwarding() {
    local service_type=$1
    
    echo -e "\n=============================="
    echo "🔗 [INICIO] Configurando port-forwarding"
    echo "=============================="
    verbose_env
    
    echo "🔹 Tipo de servicio: $service_type"
    
    case "$service_type" in
        all)
            echo "🔹 Configurando todos los port-forwards..."
            setup_port_forward "vault" "$NAMESPACE" 8200 8200 true
            setup_port_forward "zitadel" "$NAMESPACE" 8080 8080 true
            setup_port_forward "mailu" "$NAMESPACE" 80 80 true
            setup_port_forward "grafana" "$NAMESPACE" 3000 3000 true
            setup_port_forward "prometheus" "$NAMESPACE" 9090 9090 true
            ;;
        vault)
            echo "🔹 Configurando port-forward para Vault..."
            setup_port_forward "vault" "$NAMESPACE" 8200 8200 false
            ;;
        zitadel)
            echo "🔹 Configurando port-forward para Zitadel..."
            setup_port_forward "zitadel" "$NAMESPACE" 8080 8080 false
            ;;
        mailu)
            echo "🔹 Configurando port-forward para Mailu..."
            setup_port_forward "mailu" "$NAMESPACE" 80 80 false
            ;;
        grafana)
            echo "🔹 Configurando port-forward para Grafana..."
            setup_port_forward "grafana" "$NAMESPACE" 3000 3000 false
            ;;
        prometheus)
            echo "🔹 Configurando port-forward para Prometheus..."
            setup_port_forward "prometheus" "$NAMESPACE" 9090 9090 false
            ;;
        *)
            echo "❌ Servicio no reconocido: $service_type"
            echo "❌ Servicios disponibles: all, vault, zitadel, mailu, grafana, prometheus"
            return 1
            ;;
    esac
    
    echo -e "=============================="
    echo "🔗 [FIN] Configuración de port-forwarding"
    echo "==============================\n"
}

# Función para mostrar logs
show_helm_logs() {
    local component=$1
    local follow=${2:-false}
    local lines=${3:-50}
    
    echo -e "\n=============================="
    echo "📋 [INICIO] Mostrando logs de componente"
    echo "=============================="
    verbose_env
    
    if [[ -z "$component" ]]; then
        echo "❌ Componente no especificado"
        return 1
    fi
    
    echo "🔹 Componente: $component"
    echo "🔹 Modo follow: $follow"
    echo "🔹 Número de líneas: $lines"
    
    # Verificar que el deployment existe
    echo "🔹 Verificando existencia del deployment..."
    verbose_run "kubectl get deployments -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME" "Listar deployments del release"
    
    case "$component" in
        vault)
            echo "🔹 Mostrando logs de Vault..."
            if [[ "$follow" == "true" ]]; then
                verbose_run "kubectl logs -f deployment/$RELEASE_NAME-vault -n $NAMESPACE --tail=$lines" "Logs de Vault (follow)"
            else
                verbose_run "kubectl logs deployment/$RELEASE_NAME-vault -n $NAMESPACE --tail=$lines" "Logs de Vault"
            fi
            ;;
        zitadel)
            echo "🔹 Mostrando logs de Zitadel..."
            if [[ "$follow" == "true" ]]; then
                verbose_run "kubectl logs -f deployment/$RELEASE_NAME-zitadel -n $NAMESPACE --tail=$lines" "Logs de Zitadel (follow)"
            else
                verbose_run "kubectl logs deployment/$RELEASE_NAME-zitadel -n $NAMESPACE --tail=$lines" "Logs de Zitadel"
            fi
            ;;
        postgresql)
            echo "🔹 Mostrando logs de PostgreSQL..."
            if [[ "$follow" == "true" ]]; then
                verbose_run "kubectl logs -f deployment/$RELEASE_NAME-postgresql -n $NAMESPACE --tail=$lines" "Logs de PostgreSQL (follow)"
            else
                verbose_run "kubectl logs deployment/$RELEASE_NAME-postgresql -n $NAMESPACE --tail=$lines" "Logs de PostgreSQL"
            fi
            ;;
        mailu)
            echo "🔹 Mostrando logs de Mailu..."
            if [[ "$follow" == "true" ]]; then
                verbose_run "kubectl logs -f deployment/$RELEASE_NAME-mailu -n $NAMESPACE --tail=$lines" "Logs de Mailu (follow)"
            else
                verbose_run "kubectl logs deployment/$RELEASE_NAME-mailu -n $NAMESPACE --tail=$lines" "Logs de Mailu"
            fi
            ;;
        grafana)
            echo "🔹 Mostrando logs de Grafana..."
            if [[ "$follow" == "true" ]]; then
                verbose_run "kubectl logs -f deployment/$RELEASE_NAME-grafana -n $NAMESPACE --tail=$lines" "Logs de Grafana (follow)"
            else
                verbose_run "kubectl logs deployment/$RELEASE_NAME-grafana -n $NAMESPACE --tail=$lines" "Logs de Grafana"
            fi
            ;;
        prometheus)
            echo "🔹 Mostrando logs de Prometheus..."
            if [[ "$follow" == "true" ]]; then
                verbose_run "kubectl logs -f deployment/$RELEASE_NAME-prometheus -n $NAMESPACE --tail=$lines" "Logs de Prometheus (follow)"
            else
                verbose_run "kubectl logs deployment/$RELEASE_NAME-prometheus -n $NAMESPACE --tail=$lines" "Logs de Prometheus"
            fi
            ;;
        *)
            echo "❌ Componente no reconocido: $component"
            echo "❌ Componentes disponibles: vault, zitadel, postgresql, mailu, grafana, prometheus"
            return 1
            ;;
    esac
    
    echo -e "=============================="
    echo "📋 [FIN] Logs de componente"
    echo "==============================\n"
}

# Función para mostrar información post-instalación
show_post_install_info() {
    cat << EOF

🎉 ¡Chart instalado exitosamente!

📋 Próximos pasos:
==================

1. 🔗 Configurar port-forwards:
   $0 port-forward --all

2. 🌐 Acceder a los servicios:
   - Vault: http://localhost:8200
   - Zitadel: http://localhost:8080
   - Mailu: http://localhost:80
   - Grafana: http://localhost:3000
   - Prometheus: http://localhost:9090

3. 🔧 Configuración adicional:
   - Configurar DNS local (/etc/hosts)
   - Verificar certificados TLS
   - Configurar Vault si es necesario

4. 📊 Verificar estado:
   $0 status

5. 📋 Ver logs:
   $0 logs --component vault --follow

Para más información: $0 --help

EOF
}

# Función para limpiar recursos huérfanos
cleanup_orphaned_resources() {
    echo -e "\n=============================="
    echo "🧹 [INICIO] Limpiando recursos huérfanos"
    echo "=============================="
    verbose_env
    
    echo "🔹 Verificando recursos en namespace $NAMESPACE..."
    verbose_run "kubectl get all -n $NAMESPACE" "Listar todos los recursos"
    
    echo "🔹 Verificando PVCs huérfanos..."
    verbose_run "kubectl get pvc -n $NAMESPACE" "Listar PVCs"
    
    echo "🔹 Verificando configmaps huérfanos..."
    verbose_run "kubectl get configmaps -n $NAMESPACE" "Listar ConfigMaps"
    
    echo "🔹 Verificando secrets huérfanos..."
    verbose_run "kubectl get secrets -n $NAMESPACE" "Listar Secrets"
    
    echo -e "=============================="
    echo "🧹 [FIN] Limpieza de recursos huérfanos"
    echo "==============================\n"
}

# Función para modo debug
debug_mode() {
    echo -e "\n=============================="
    echo "🐛 [INICIO] Modo debug para troubleshooting"
    echo "=============================="
    verbose_env
    
    echo "🔹 Información del sistema:"
    verbose_run "uname -a" "Información del sistema operativo"
    
    echo "🔹 Versiones de herramientas:"
    verbose_run "helm version" "Versión de Helm"
    verbose_run "kubectl version --client" "Versión de kubectl"
    
    echo "🔹 Estado del cluster:"
    verbose_run "kubectl cluster-info" "Información del cluster"
    verbose_run "kubectl get nodes" "Nodos del cluster"
    
    echo "🔹 Namespaces existentes:"
    verbose_run "kubectl get namespaces" "Listar namespaces"
    
    echo "🔹 Estado del namespace blinkchamber:"
    verbose_run "kubectl get all -n blinkchamber" "Recursos en namespace blinkchamber"
    
    echo "🔹 Releases de Helm:"
    verbose_run "helm list --all-namespaces" "Listar todos los releases"
    
    echo "🔹 Repositorios de Helm:"
    verbose_run "helm repo list" "Listar repositorios"
    
    echo "🔹 Contenido del directorio del chart:"
    verbose_run "ls -la $HELM_CHART_DIR" "Contenido del directorio del chart"
    
    echo "🔹 Archivo Chart.yaml:"
    verbose_run "cat $HELM_CHART_DIR/Chart.yaml" "Contenido de Chart.yaml"
    
    echo -e "=============================="
    echo "🐛 [FIN] Modo debug"
    echo "==============================\n"
}

# Función principal
main() {
    echo -e "\n=============================="
    echo "🚀 [INICIO] blinkchamber-helm.sh"
    echo "=============================="
    verbose_env
    
    local args=($(parse_common_args "$@"))
    
    if [[ ${#args[@]} -eq 0 ]]; then
        echo "🔹 No se especificaron argumentos, mostrando ayuda..."
        show_helm_help
        exit 0
    fi
    
    local command="${args[0]}"
    echo "🔹 Comando solicitado: $command"
    shift # Remover comando de args
    
    case "$command" in
        install)
            local values_file=""
            local dry_run=false
            local wait=false
            local timeout="10m"
            
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --values)
                        values_file="$2"
                        shift 2
                        ;;
                    --dry-run)
                        dry_run=true
                        shift
                        ;;
                    --wait)
                        wait=true
                        shift
                        ;;
                    --timeout)
                        timeout="$2"
                        shift 2
                        ;;
                    *)
                        warning "Opción no reconocida: $1"
                        shift
                        ;;
                esac
            done
            
            install_chart "$values_file" "$dry_run" "$wait" "$timeout"
            ;;
        upgrade)
            local values_file=""
            local dry_run=false
            local wait=false
            local timeout="10m"
            
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --values)
                        values_file="$2"
                        shift 2
                        ;;
                    --dry-run)
                        dry_run=true
                        shift
                        ;;
                    --wait)
                        wait=true
                        shift
                        ;;
                    --timeout)
                        timeout="$2"
                        shift 2
                        ;;
                    *)
                        warning "Opción no reconocida: $1"
                        shift
                        ;;
                esac
            done
            
            upgrade_chart "$values_file" "$dry_run" "$wait" "$timeout"
            ;;
        uninstall)
            local dry_run=false
            
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --dry-run)
                        dry_run=true
                        shift
                        ;;
                    *)
                        warning "Opción no reconocida: $1"
                        shift
                        ;;
                esac
            done
            
            uninstall_chart "$dry_run"
            ;;
        status)
            show_release_status
            ;;
        values)
            show_current_values
            ;;
        lint)
            lint_chart
            ;;
        template)
            local values_file=""
            
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --values)
                        values_file="$2"
                        shift 2
                        ;;
                    *)
                        warning "Opción no reconocida: $1"
                        shift
                        ;;
                esac
            done
            
            template_chart "$values_file"
            ;;
        port-forward)
            local service_type="all"
            
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --all)
                        service_type="all"
                        shift
                        ;;
                    --vault)
                        service_type="vault"
                        shift
                        ;;
                    --zitadel)
                        service_type="zitadel"
                        shift
                        ;;
                    --mailu)
                        service_type="mailu"
                        shift
                        ;;
                    --grafana)
                        service_type="grafana"
                        shift
                        ;;
                    --prometheus)
                        service_type="prometheus"
                        shift
                        ;;
                    *)
                        warning "Opción no reconocida: $1"
                        shift
                        ;;
                esac
            done
            
            setup_helm_port_forwarding "$service_type"
            ;;
        logs)
            local component=""
            local follow=false
            local lines=50
            
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --component)
                        component="$2"
                        shift 2
                        ;;
                    --follow)
                        follow=true
                        shift
                        ;;
                    --lines)
                        lines="$2"
                        shift 2
                        ;;
                    *)
                        warning "Opción no reconocida: $1"
                        shift
                        ;;
                esac
            done
            
            show_helm_logs "$component" "$follow" "$lines"
            ;;
        debug)
            debug_mode
            ;;
        cleanup)
            cleanup_orphaned_resources
            ;;
        help|--help|-h)
            echo "🔹 Mostrando ayuda..."
            show_helm_help
            ;;
        *)
            echo "❌ Comando no reconocido: $command"
            echo ""
            show_helm_help
            exit 1
            ;;
    esac
    
    echo -e "=============================="
    echo "🚀 [FIN] blinkchamber-helm.sh"
    echo "==============================\n"
}

# Ejecutar función principal
main "$@" 