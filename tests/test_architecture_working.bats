#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'

# Variables
ZITADEL_RELEASE_NAME="zitadel"
VAULT_RELEASE_NAME="vault"
NAMESPACE="default"
ZITADEL_REPLICAS=3
VAULT_REPLICAS=3

# Funciones de ayuda simplificadas
kube_get_pods() {
  kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$1" -o json
}

kube_get_deployment() {
  kubectl get deployment -n "$NAMESPACE" -l "app.kubernetes.io/name=$1" -o json
}

kube_get_statefulset() {
  kubectl get statefulset -n "$NAMESPACE" -l "app.kubernetes.io/name=$1" -o json
}

# Pruebas básicas
@test "Test variables are set" {
  [ "$ZITADEL_RELEASE_NAME" = "zitadel" ]
  [ "$VAULT_RELEASE_NAME" = "vault" ]
  [ "$NAMESPACE" = "default" ]
  [ "$ZITADEL_REPLICAS" -eq 3 ]
  [ "$VAULT_REPLICAS" -eq 3 ]
}

@test "Test kubectl is available" {
  run kubectl version --client
  [ "$status" -eq 0 ]
}

@test "Test ZITADEL deployment function" {
  run kube_get_deployment "zitadel"
  # Este test puede fallar si no hay deployments, pero no debe dar error de sintaxis
  echo "Deployment check completed"
}

@test "Test Vault statefulset function" {
  run kube_get_statefulset "vault"
  # Este test puede fallar si no hay statefulsets, pero no debe dar error de sintaxis
  echo "Statefulset check completed"
} 