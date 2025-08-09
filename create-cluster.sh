#!/usr/bin/env bash

# ========================================
# SCRIPT DE CONVENIENCIA - CREATE KIND CLUSTER
# ========================================
# Este script redirige a scripts/create-kind-cluster.sh
# para mantener compatibilidad con comandos existentes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_SCRIPT="$SCRIPT_DIR/scripts/create-kind-cluster.sh"

if [ ! -f "$CLUSTER_SCRIPT" ]; then
    echo "❌ Error: No se encontró el script scripts/create-kind-cluster.sh"
    echo "💡 Asegúrate de ejecutar este comando desde la raíz del proyecto"
    exit 1
fi

# Ejecutar el script de cluster con todos los argumentos pasados
exec "$CLUSTER_SCRIPT" "$@" 