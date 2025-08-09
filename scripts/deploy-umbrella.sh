#!/usr/bin/env bash
set -euo pipefail

# =====================
# VARIABLES
# =====================
CHART_NAME="blinkchamber-platform"
RELEASE_NAME="blinkchamber"
NAMESPACE="blinkchamber-platform"
VALUES_FILE="values.yaml"

# =====================
# FUNCIONES
# =====================
show_help() {
  echo "🚀 BlinkChamber Platform - Chart Umbrella"
  echo ""
  echo "Uso: $0 [OPCIÓN]"
  echo ""
  echo "Opciones:"
  echo "  install     - Instalar la plataforma completa"
  echo "  upgrade     - Actualizar la plataforma"
  echo "  uninstall   - Desinstalar la plataforma"
  echo "  status      - Ver estado de la plataforma"
  echo "  logs        - Ver logs de todos los componentes"
  echo "  setup       - Configuración inicial completa (Vault + secretos)"
  echo "  fix         - Solucionar problemas automáticamente"
  echo "  restart     - Reiniciar pods problemáticos"
  echo "  help        - Mostrar esta ayuda"
  echo ""
  echo "Ejemplos:"
  echo "  $0 install"
  echo "  $0 setup      # Configurar Vault y crear secretos"
  echo "  $0 fix        # Solucionar problemas automáticamente"
  echo "  $0 restart    # Reiniciar pods problemáticos"
  echo "  $0 status"
  echo ""
  echo "💡 Para gestión avanzada usar: ./scripts/manage-platform.sh"
}

add_repositories() {
  echo "📦 Agregando repositorios de Helm..."
  helm repo add jetstack https://charts.jetstack.io
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo add bitnami https://charts.bitnami.com/bitnami
  helm repo add hashicorp https://helm.releases.hashicorp.com
  helm repo add zitadel https://charts.zitadel.com
  helm repo update
}

install_platform() {
  echo "🚀 Instalando BlinkChamber Platform..."
  
  # Verificar que Helm esté disponible
  if ! command -v helm &> /dev/null; then
    echo "❌ Error: Helm no está instalado"
    exit 1
  fi
  
  # Agregar repositorios
  add_repositories
  
  # Actualizar dependencias
  echo "📋 Actualizando dependencias del chart..."
  helm dependency update
  
  # Instalar la plataforma
  echo "🔧 Instalando plataforma en namespace: $NAMESPACE"
  helm upgrade --install "$RELEASE_NAME" . \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --values "$VALUES_FILE" \
    --wait \
    --timeout 10m
  
  echo "✅ Plataforma instalada correctamente!"
  echo ""
  echo "📋 Para ver el estado: $0 status"
  echo "📋 Para ver logs: $0 logs"
}

upgrade_platform() {
  echo "🔄 Actualizando BlinkChamber Platform..."
  
  add_repositories
  helm dependency update
  
  helm upgrade "$RELEASE_NAME" . \
    --namespace "$NAMESPACE" \
    --values "$VALUES_FILE" \
    --wait \
    --timeout 10m
  
  echo "✅ Plataforma actualizada correctamente!"
}

uninstall_platform() {
  echo "🗑️  Desinstalando BlinkChamber Platform..."
  
  read -p "¿Estás seguro de que quieres desinstalar la plataforma? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    helm uninstall "$RELEASE_NAME" --namespace "$NAMESPACE"
    echo "✅ Plataforma desinstalada correctamente!"
  else
    echo "❌ Desinstalación cancelada"
  fi
}

show_status() {
  echo "📊 Estado de BlinkChamber Platform"
  echo "=================================="
  
  # Estado general del release
  echo ""
  echo "🔍 Estado del Release:"
  helm status "$RELEASE_NAME" --namespace "$NAMESPACE" 2>/dev/null || echo "Release no encontrado"
  
  # Pods por namespace
  echo ""
  echo "📦 Pods por Namespace:"
  for ns in infra blinkchamber database identity; do
    echo ""
    echo "Namespace: $ns"
    kubectl get pods -n "$ns" --no-headers 2>/dev/null || echo "Namespace no encontrado"
  done
  
  # Servicios
  echo ""
  echo "🌐 Servicios:"
  kubectl get svc -A -l app.kubernetes.io/part-of=blinkchamber-platform 2>/dev/null || echo "No se encontraron servicios"
}

show_logs() {
  echo "📋 Logs de BlinkChamber Platform"
  echo "================================"
  
  for ns in infra blinkchamber database identity; do
    echo ""
    echo "📝 Logs del namespace: $ns"
    echo "------------------------"
    
    pods=$(kubectl get pods -n "$ns" --no-headers -o custom-columns=":metadata.name" 2>/dev/null || echo "")
    
    if [ -n "$pods" ]; then
      for pod in $pods; do
        echo ""
        echo "🔍 Pod: $pod"
        kubectl logs -n "$ns" "$pod" --tail=10 2>/dev/null || echo "No se pudieron obtener logs"
      done
    else
      echo "No se encontraron pods en este namespace"
    fi
  done
}

# =====================
# NUEVAS FUNCIONES
# =====================
setup_platform() {
  echo "🔧 Configuración inicial de la plataforma..."
  
  if [ ! -f "scripts/manage-platform.sh" ]; then
    echo "❌ Error: scripts/manage-platform.sh no encontrado"
    exit 1
  fi
  
  echo "📋 Ejecutando configuración inicial..."
  ./scripts/manage-platform.sh vault setup-auth
  ./scripts/manage-platform.sh secrets create-all
  
  echo "✅ Configuración inicial completada!"
}

fix_platform() {
  echo "🔧 Solucionando problemas de la plataforma..."
  
  if [ ! -f "scripts/manage-platform.sh" ]; then
    echo "❌ Error: scripts/manage-platform.sh no encontrado"
    exit 1
  fi
  
  ./scripts/manage-platform.sh platform fix-issues
}

restart_pods() {
  echo "🔄 Reiniciando pods problemáticos..."
  
  if [ ! -f "scripts/manage-platform.sh" ]; then
    echo "❌ Error: scripts/manage-platform.sh no encontrado"
    exit 1
  fi
  
  ./scripts/manage-platform.sh pods restart-all
}

# =====================
# MENÚ PRINCIPAL
# =====================
case "${1:-help}" in
  install)
    install_platform
    ;;
  upgrade)
    upgrade_platform
    ;;
  uninstall)
    uninstall_platform
    ;;
  status)
    show_status
    ;;
  logs)
    show_logs
    ;;
  setup)
    setup_platform
    ;;
  fix)
    fix_platform
    ;;
  restart)
    restart_pods
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    echo "❌ Opción no válida: $1"
    echo ""
    show_help
    exit 1
    ;;
esac 