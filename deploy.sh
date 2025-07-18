#!/usr/bin/env bash
set -euo pipefail

# Variables
VAULT_NAMESPACE="blinkchamber"
ZITADEL_NAMESPACE="identity"
VAULT_VALUES="vault-values.yaml"
ZITADEL_VALUES="zitadel-values.yaml"

# 1. Despliegue de Vault (chart oficial)
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

# 2. Inicialización y desellado de Vault
init_unseal_vault() {
  echo "[Vault] Inicializando y desellando Vault..."
  bash terraform/vault-init.sh "$VAULT_NAMESPACE"
}

# 3. Despliegue de ZITADEL (chart oficial)
deploy_zitadel() {
  echo "[ZITADEL] Agregando repositorio de Helm y actualizando..."
  helm repo add zitadel https://charts.zitadel.com || true
  helm repo update

  echo "[ZITADEL] Creando namespace si no existe..."
  kubectl get ns "$ZITADEL_NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$ZITADEL_NAMESPACE"

  echo "[ZITADEL] Desplegando ZITADEL en modo HA..."
  helm upgrade --install zitadel zitadel/zitadel \
    -n "$ZITADEL_NAMESPACE" --create-namespace \
    -f "$ZITADEL_VALUES"
}

# 4. Crear secrets necesarios para ZITADEL (ejemplo)
create_zitadel_secrets() {
  echo "[ZITADEL] Creando secrets necesarios (ajusta según tu entorno)..."
  # Secret de la base de datos
  kubectl create secret generic zitadel-db-secret \
    --from-literal=password="<password_db>" \
    -n "$ZITADEL_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

  # Secret del token de Vault
  kubectl create secret generic zitadel-vault-token \
    --from-literal=token="<vault_token>" \
    -n "$ZITADEL_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

  # Secret TLS para ZITADEL
  kubectl create secret tls zitadel-tls \
    --cert="</ruta/a/tls.crt>" --key="</ruta/a/tls.key>" \
    -n "$ZITADEL_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
}

# 5. Crear secret TLS para Vault (ejemplo)
create_vault_tls_secret() {
  echo "[Vault] Creando secret TLS para Vault..."
  kubectl create secret generic vault-tls \
    --from-file=tls.crt=</ruta/a/tu/certificado.crt> \
    --from-file=tls.key=</ruta/a/tu/clave.key> \
    -n "$VAULT_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
}

# 6. Despliegue de PostgreSQL HA (Bitnami + Vault Injector)
deploy_postgres_ha() {
  echo "[PostgreSQL HA] Agregando repositorio de Helm y actualizando..."
  helm repo add bitnami https://charts.bitnami.com/bitnami || true
  helm repo update

  echo "[PostgreSQL HA] Creando namespace si no existe..."
  kubectl get ns database >/dev/null 2>&1 || kubectl create ns database

  echo "[PostgreSQL HA] Desplegando PostgreSQL HA con integración Vault Injector..."
  helm upgrade --install postgresql-ha bitnami/postgresql-ha \
    -n database --create-namespace \
    -f postgresql-ha-values.yaml
}

# 0. Despliegue de infraestructura base con Terraform
provision_infra() {
  echo "[Infra] Desplegando infraestructura base (Kubernetes, red, base de datos) con Terraform..."
  cd terraform
  terraform init
  terraform apply -auto-approve
  cd ..
}

# Menú de etapas
echo "\nOpciones de despliegue disponibles:"
echo "  1) Desplegar Vault"
echo "  2) Inicializar y desellar Vault"
echo "  3) Crear secret TLS para Vault"
echo "  4) Desplegar ZITADEL"
echo "  5) Crear secrets para ZITADEL"
echo "  6) Desplegar infraestructura base (Terraform)"
echo "  7) Desplegar PostgreSQL HA (Bitnami + Vault Injector)"
echo "  0) Salir"

read -rp "Selecciona una opción (puedes ejecutar varias en orden): " opcion

case $opcion in
  1) deploy_vault ;;
  2) init_unseal_vault ;;
  3) create_vault_tls_secret ;;
  4) deploy_zitadel ;;
  5) create_zitadel_secrets ;;
  6) provision_infra ;;
  7) deploy_postgres_ha ;;
  0) echo "Saliendo..."; exit 0 ;;
  *) echo "Opción no válida"; exit 1 ;;
esac 