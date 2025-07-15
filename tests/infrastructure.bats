#!/usr/bin/env bats

@test "Cluster Info" {
  run kubectl cluster-info
  [ "$status" -eq 0 ]
  [[ "$output" == *"Kubernetes control plane"* ]]
}

@test "List Nodes" {
  run kubectl get nodes
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAME"* ]]
}

@test "List Namespaces" {
  run kubectl get namespaces
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAME"* ]]
}

@test "List Pods" {
  run kubectl get pods --all-namespaces
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAMESPACE"* ]]
}

@test "List Services" {
  run kubectl get services --all-namespaces
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAMESPACE"* ]]
} 