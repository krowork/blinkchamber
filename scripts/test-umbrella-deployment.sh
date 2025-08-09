#!/usr/bin/env bash
set -euo pipefail

# Script para probar el deployment del umbrella chart con diferentes environments

ENVIRONMENT=${1:-"development"}
CHART_NAME="blinkchamber-platform"

echo "🚀 Probando deployment del umbrella chart para environment: $ENVIRONMENT"

# Verificar que el environment existe
if [ ! -f "environments/$ENVIRONMENT/values.yaml" ]; then
    echo "❌ Error: Environment '$ENVIRONMENT' no existe"
    echo "💡 Environments disponibles:"
    ls environments/ | grep -v README.md | grep -v base
    exit 1
fi

# Verificar prerequisitos
echo "🔍 Verificando prerequisitos..."

if ! kubectl cluster-info &>/dev/null; then
    echo "❌ Error: No hay conexión al cluster de Kubernetes"
    exit 1
fi

if ! helm version &>/dev/null; then
    echo "❌ Error: Helm no está disponible"
    exit 1
fi

echo "✅ Prerequisitos verificados"

# Dry-run para verificar la configuración
echo "🧪 Ejecutando dry-run del deployment..."
helm upgrade --install "$CHART_NAME" . \
    -f environments/base/values.yaml \
    -f "environments/$ENVIRONMENT/values.yaml" \
    --dry-run --debug > /tmp/umbrella-dry-run.yaml

echo "✅ Dry-run completado exitosamente"
echo "📄 Resultado guardado en: /tmp/umbrella-dry-run.yaml"

# Mostrar configuración de ZITADEL específica
echo ""
echo "🔍 Configuración de ZITADEL para $ENVIRONMENT:"
echo "================================================"

# Extraer configuración de ZITADEL del dry-run
grep -A 20 -B 5 "kind: Deployment" /tmp/umbrella-dry-run.yaml | grep -A 25 "name.*zitadel" || echo "⚠️  No se encontró deployment de ZITADEL"

echo ""
echo "📊 Resumen de configuración:"
echo "- Environment: $ENVIRONMENT"
echo "- Base config: environments/base/values.yaml"
echo "- Environment config: environments/$ENVIRONMENT/values.yaml"

# Preguntar si continuar con deployment real
echo ""
read -p "¿Continuar con el deployment real? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Desplegando umbrella chart..."
    
    helm upgrade --install "$CHART_NAME" . \
        -f environments/base/values.yaml \
        -f "environments/$ENVIRONMENT/values.yaml" \
        --timeout 10m
    
    echo "✅ Deployment completado"
    echo ""
    echo "📊 Estado del cluster:"
    kubectl get pods -A | grep -E "(zitadel|vault|postgres|redis)"
    
    echo ""
    echo "🌐 Para acceder a ZITADEL:"
    case $ENVIRONMENT in
        "test")
            echo "kubectl port-forward -n identity svc/zitadel 8080:8080"
            echo "URL: http://localhost:8080 (zitadel.test.blinkchamber.local)"
            ;;
        "development")
            echo "kubectl port-forward -n identity svc/zitadel 8080:8080"
            echo "URL: http://localhost:8080 (zitadel.dev.blinkchamber.local)"
            ;;
        "staging")
            echo "kubectl port-forward -n identity svc/zitadel 8080:8080"
            echo "URL: http://localhost:8080 (zitadel.staging.blinkchamber.local)"
            ;;
        "production")
            echo "Ingress configurado para: https://zitadel.blinkchamber.com"
            ;;
    esac
else
    echo "❌ Deployment cancelado"
fi
