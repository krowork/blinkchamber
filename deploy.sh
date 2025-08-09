#!/usr/bin/env bash

# ========================================
# SCRIPT DE CONVENIENCIA - DEPLOY UMBRELLA
# ========================================
# Este script redirige a scripts/deploy-umbrella.sh
# para mantener compatibilidad con comandos existentes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UMBRELLA_SCRIPT="$SCRIPT_DIR/scripts/deploy-umbrella.sh"

if [ ! -f "$UMBRELLA_SCRIPT" ]; then
    echo "❌ Error: No se encontró el script scripts/deploy-umbrella.sh"
    echo "💡 Asegúrate de ejecutar este comando desde la raíz del proyecto"
    exit 1
fi

# Ejecutar el script de umbrella con todos los argumentos pasados
exec "$UMBRELLA_SCRIPT" "$@" 