#!/usr/bin/env bats

# Cargar helpers de prueba
load '/app/tests/helpers/bats-helpers/load'

# Variables
ZITADEL_RELEASE_NAME="zitadel"
VAULT_RELEASE_NAME="vault"
NAMESPACE="default"
ZITADEL_REPLICAS=3
VAULT_REPLICAS=3

setup() {
  # Instalar dependencias de bats
  if [ ! -d "tests/bats-helpers" ]; then
    mkdir -p tests/bats-helpers
    git clone https://github.com/bats-core/bats-helpers.git tests/bats-helpers
  fi
}

# Funciones de ayuda
kube_get_pods() {
  kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$1" -o json
}

kube_get_deployment() {
  kubectl get deployment -n "$NAMESPACE" -l "app.kubernetes.io/name=$1" -o json
}

kube_get_statefulset() {
  kubectl get statefulset -n "$NAMESPACE" -l "app.kubernetes.io/name=$1" -o json
}

check_pods_running() {
  local app_name=$1
  local expected_replicas=$2
  local pods_json
  local running_pods

  pods_json=$(kube_get_pods "$app_name")
  running_pods=$(echo "$pods_json" | jq '.items[] | select(.status.phase == "Running")' | jq -s 'length')

  [ "$running_pods" -eq "$expected_replicas" ]
}

# Pruebas
@test "ZITADEL deployment has the correct number of replicas" {
  run kube_get_deployment "zitadel"
  [ "$status" -eq 0 ]
  local replicas
  replicas=$(echo "$output" | jq '.items[0].spec.replicas')
  [ "$replicas" -eq "$ZITADEL_REPLICAS" ]
}

@test "Vault statefulset has the correct number of replicas" {
  run kube_get_statefulset "vault"
  [ "$status" -eq 0 ]
  local replicas
  replicas=$(echo "$output" | jq '.items[0].spec.replicas')
  [ "$replicas" -eq "$VAULT_REPLICAS" ]
}

@test "All ZITADEL pods are running" {
  run check_pods_running "zitadel" "$ZITADEL_REPLICAS"
  [ "$status" -eq 0 ]
}

@test "All Vault pods are running" {
  run check_pods_running "vault" "$VAULT_REPLICAS"
  [ "$status" -eq 0 ]
}

@test "ZITADEL service is accessible" {
  run kubectl get svc -n "$NAMESPACE" "$ZITADEL_RELEASE_NAME-zitadel-chart"
  [ "$status" -eq 0 ]
}

@test "Vault service is accessible" {
  run kubectl get svc -n "$NAMESPACE" "$VAULT_RELEASE_NAME-vault-chart"
  [ "$status" -eq 0 ]
}

@test "No errors in ZITADEL pod logs" {
  local pods_json
  pods_json=$(kube_get_pods "zitadel")
  local pod_names
  pod_names=$(echo "$pods_json" | jq -r '.items[].metadata.name')

  for pod in $pod_names; do
    run kubectl logs -n "$NAMESPACE" "$pod" --tail=100
    [ "$status" -eq 0 ]
    [ ! (echo "$output" | grep -i "error") ]
  done
}

@test "No errors in Vault pod logs" {
  local pods_json
  pods_json=$(kube_get_pods "vault")
  local pod_names
  pod_names=$(echo "$pods_json" | jq -r '.items[].metadata.name')

  for pod in $pod_names; do
    run kubectl logs -n "$NAMESPACE" "$pod" --tail=100
    [ "$status" -eq 0 ]
    [ ! (echo "$output" | grep -i "error") ]
  done
}

@test "Simulate node failure and verify ZITADEL remains available" {
  local node_to_cordon
  node_to_cordon=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

  run kubectl cordon "$node_to_cordon"
  [ "$status" -eq 0 ]

  # Esperar a que los pods se reasignen
  sleep 60

  run check_pods_running "zitadel" "$ZITADEL_REPLICAS"
  [ "$status" -eq 0 ]

  run kubectl uncordon "$node_to_cordon"
  [ "$status" -eq 0 ]
}

@test "Test database failover" {
  # Get the current database master
  local db_master
  db_master=$(kubectl get pod -n "$NAMESPACE" -l "app=cockroachdb,role=master" -o jsonpath='{.items[0].metadata.name}')

  # Delete the master pod to simulate a failure
  run kubectl delete pod -n "$NAMESPACE" "$db_master"
  [ "$status" -eq 0 ]

  # Wait for a new master to be elected
  sleep 60

  # Check that there is a new master
  run kubectl get pod -n "$NAMESPACE" -l "app=cockroachdb,role=master" -o jsonpath='{.items[0].metadata.name}'
  [ "$status" -eq 0 ]
  [ "$output" != "$db_master" ]

  # Check that ZITADEL is still running
  run check_pods_running "zitadel" "$ZITADEL_REPLICAS"
  [ "$status" -eq 0 ]
}

@test "Simulate node failure and verify Vault remains available" {
  local node_to_cordon
  node_to_cordon=$(kubectl get nodes -o jsonpath='{.items[1].metadata.name}')

  run kubectl cordon "$node_to_cordon"
  [ "$status" -eq 0 ]

  # Esperar a que los pods se reasignen
  sleep 60

  run check_pods_running "vault" "$VAULT_REPLICAS"
  [ "$status" -eq 0 ]

  run kubectl uncordon "$node_to_cordon"
  [ "$status" -eq 0 ]
}
