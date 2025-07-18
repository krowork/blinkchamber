#!/bin/bash
set -euo pipefail

# Leer la contraseña desde el archivo inyectado por Vault Agent
export POSTGRES_PASSWORD="$(cat /vault/secrets/POSTGRES_PASSWORD)"

# Ejecutar el entrypoint original de Bitnami PostgreSQL
exec /opt/bitnami/scripts/postgresql/entrypoint.sh /opt/bitnami/scripts/postgresql/run.sh 