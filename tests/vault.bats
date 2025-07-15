#!/usr/bin/env bats

@test "Vault Pods" {
  run kubectl get pods -n vault
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAME"* ]]
}

@test "Vault Service Account" {
  run kubectl get serviceaccount vault -n vault
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAME"* ]]
}

@test "Vault Services" {
  run kubectl get services -n vault
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAME"* ]]
}

@test "Vault ConfigMaps" {
  run kubectl get configmaps -n vault
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAME"* ]]
}

@test "Vault Status" {
  run kubectl exec -n vault statefulset/vault -- vault status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Initialized"* ]]
}

@test "Vault Auth List" {
  run kubectl exec -n vault statefulset/vault -- vault auth list
  [ "$status" -eq 0 ]
  [[ "$output" == *"kubernetes/"* ]]
} 