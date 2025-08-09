#!/usr/bin/env bash

# ========================================
# SCRIPT DE CONVENIENCIA - PLATFORM MANAGEMENT
# ========================================
# Este script redirige a scripts/manage-platform.sh
# para facilitar el acceso a las funcionalidades de gestión

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANAGE_SCRIPT="$SCRIPT_DIR/scripts/manage-platform.sh"

if [ ! -f "$MANAGE_SCRIPT" ]; then
    echo "❌ Error: No se encontró el script scripts/manage-platform.sh"
    echo "💡 Asegúrate de ejecutar este comando desde la raíz del proyecto"
    exit 1
fi

# Ejecutar el script de gestión con todos los argumentos pasados
exec "$MANAGE_SCRIPT" "$@"
