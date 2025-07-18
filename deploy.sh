#!/usr/bin/env bash
set -euo pipefail

# =====================
# VARIABLES PRINCIPALES
# =====================
VAULT_NAMESPACE="blinkchamber"
ZITADEL_NAMESPACE="identity"
POSTGRES_NAMESPACE="database"
VAULT_VALUES="vault-values.yaml"
ZITADEL_VALUES="zitadel-values.yaml"
POSTGRES_VALUES="postgresql-ha-values.yaml"

# Rutas parametrizables (ajusta según tu entorno)
VAULT_TLS_CERT="/ruta/a/tu/certificado.crt"
VAULT_TLS_KEY="/ruta/a/tu/clave.key"
ZITADEL_TLS_CERT="/ruta/a/tls.crt"
ZITADEL_TLS_KEY="/ruta/a/tls.key"

# =====================
# FUNCIONES DE AYUDA
# =====================
show_help() {
  echo "\nOpciones de despliegue recomendadas:"
  echo "  1) Desplegar infraestructura base (Terraform: namespaces, cert-manager, nginx-ingress)"
  echo "  2) Crear secret TLS para Vault"
  echo "  3) Desplegar Vault"
  echo "  4) Inicializar y desellar Vault"
  echo "  5) Desplegar PostgreSQL HA (Bitnami + Vault Injector)"
  echo "  6) Desplegar ZITADEL (con Vault Injector)"
  echo "  h) Mostrar ayuda"
  echo "  0) Salir"
}

# =====================
# VAULT
# =====================
deploy_vault() {
  echo "[Vault] Agregando repositorio de Helm y actualizando..."
  helm repo add hashicorp https://helm.releases.hashicorp.com || true
  helm repo update

  echo "[Vault] Creando namespace si no existe..."
  kubectl get ns "$VAULT_NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$VAULT_NAMESPACE"

  echo "[Vault] Desplegando Vault en modo HA..."
  helm upgrade --install vault hashicorp/vault \
    -n "$VAULT_NAMESPACE" --create-namespace \
    -f "$VAULT_VALUES"
}

init_unseal_vault() {
  echo "[Vault] Inicializando y desellando Vault..."
  bash terraform/vault-init.sh "$VAULT_NAMESPACE"
}

create_vault_tls_secret() {
  echo "[Vault] Creando secret TLS para Vault..."
  kubectl create secret generic vault-tls \
    --from-file=tls.crt="$VAULT_TLS_CERT" \
    --from-file=tls.key="$VAULT_TLS_KEY" \
    -n "$VAULT_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
}

# =====================
# ZITADEL
# =====================
deploy_zitadel() {
  echo "[ZITADEL] Agregando repositorio de Helm y actualizando..."
  helm repo add zitadel https://charts.zitadel.com || true
  helm repo update

  echo "[ZITADEL] Creando namespace si no existe..."
  kubectl get ns "$ZITADEL_NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$ZITADEL_NAMESPACE"

  echo "[ZITADEL] Desplegando ZITADEL (con Vault Injector)..."
  helm upgrade --install zitadel zitadel/zitadel \
    -n "$ZITADEL_NAMESPACE" --create-namespace \
    -f "$ZITADEL_VALUES"
}

# =====================
# POSTGRESQL HA
# =====================
deploy_postgres_ha() {
  echo "[PostgreSQL HA] Agregando repositorio de Helm y actualizando..."
  helm repo add bitnami https://charts.bitnami.com/bitnami || true
  helm repo update

  echo "[PostgreSQL HA] Creando namespace si no existe..."
  kubectl get ns "$POSTGRES_NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$POSTGRES_NAMESPACE"

  echo "[PostgreSQL HA] Desplegando PostgreSQL HA con Vault Injector..."
  helm upgrade --install postgresql-ha bitnami/postgresql-ha \
    -n "$POSTGRES_NAMESPACE" --create-namespace \
    -f "$POSTGRES_VALUES"
}

# =====================
# INFRAESTRUCTURA BASE
# =====================
provision_infra() {
  echo "[Infra] Desplegando infraestructura base (namespaces, cert-manager, nginx-ingress) con Terraform..."
  cd terraform/kind
  terraform init
  terraform apply -auto-approve
  cd ../..
}

# =====================
# MENÚ INTERACTIVO
# =====================
while true; do
  show_help
  read -rp $'\nSelecciona una opción (puedes ejecutar varias en orden, separadas por espacio): ' opciones
  for opcion in $opciones; do
    case $opcion in
      1) provision_infra ;;
      2) create_vault_tls_secret ;;
      3) deploy_vault ;;
      4) init_unseal_vault ;;
      5) deploy_postgres_ha ;;
      6) deploy_zitadel ;;
      h|H) show_help ;;
      0) echo "Saliendo..."; exit 0 ;;
      *) echo "Opción no válida: $opcion" ;;
    esac
  done
done 