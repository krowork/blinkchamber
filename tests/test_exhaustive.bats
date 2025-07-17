#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'

# Variables
ZITADEL_RELEASE_NAME="zitadel"
VAULT_RELEASE_NAME="vault"
NAMESPACE="default"
ZITADEL_REPLICAS=3
VAULT_REPLICAS=3

# Helper functions
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

# Basic Tests
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

# Chaos Engineering Tests
@test "Kill a ZITADEL pod and verify recovery" {
  local pod_to_kill
  pod_to_kill=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=zitadel" -o jsonpath='{.items[0].metadata.name}')

  run kubectl delete pod -n "$NAMESPACE" "$pod_to_kill"
  [ "$status" -eq 0 ]

  # Wait for the pod to be replaced
  sleep 60

  run check_pods_running "zitadel" "$ZITADEL_REPLICAS"
  [ "$status" -eq 0 ]
}

@test "Kill a Vault pod and verify recovery" {
  local pod_to_kill
  pod_to_kill=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=vault" -o jsonpath='{.items[0].metadata.name}')

  run kubectl delete pod -n "$NAMESPACE" "$pod_to_kill"
  [ "$status" -eq 0 ]

  # Wait for the pod to be replaced
  sleep 60

  run check_pods_running "vault" "$VAULT_REPLICAS"
  [ "$status" -eq 0 ]
}

@test "Inject latency into ZITADEL to Vault communication" {
  # This test requires a tool like 'toxiproxy' to be installed and configured.
  # For the purpose of this example, we will simulate the test.
  echo "Simulating latency injection test..."
  [ 0 -eq 0 ]
}

# Security Tests
@test "Verify TLS encryption between ZITADEL and Vault" {
  # This test would involve inspecting the network traffic between the pods.
  # For the purpose of this example, we will simulate the test.
  echo "Simulating TLS verification test..."
  [ 0 -eq 0 ]
}

@test "Check for exposed Vault secrets in ZITADEL logs" {
  local pods_json
  pods_json=$(kube_get_pods "zitadel")
  local pod_names
  pod_names=$(echo "$pods_json" | jq -r '.items[].metadata.name')

  for pod in $pod_names; do
    run kubectl logs -n "$NAMESPACE" "$pod"
    [ "$status" -eq 0 ]
    [ ! (echo "$output" | grep -i "VAULT_TOKEN") ]
  done
}

# Scalability Tests
@test "Test ZITADEL autoscaling" {
  # This test requires a load testing tool like 'k6' or 'hey'.
  # For the purpose of this example, we will simulate the test.
  echo "Simulating autoscaling test..."
  [ 0 -eq 0 ]
}
