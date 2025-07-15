#!/usr/bin/env bats

@test "Mailu Pods" {
  run kubectl get pods -n mail
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAME"* ]]
}

@test "Mailu Services" {
  run kubectl get services -n mail
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAME"* ]]
}

@test "Mailu Deployments" {
  run kubectl get deployments -n mail
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAME"* ]]
}

@test "Zitadel Pods" {
  run kubectl get pods -n identity
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAME"* ]]
}

@test "Zitadel Services" {
  run kubectl get services -n identity
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAME"* ]]
}

@test "Zitadel Deployments" {
  run kubectl get deployments -n identity
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAME"* ]]
}

@test "Grafana Pods" {
  run kubectl get pods -n monitoring
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAME"* ]]
}

@test "Grafana Services" {
  run kubectl get services -n monitoring
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAME"* ]]
}

@test "Grafana Deployments" {
  run kubectl get deployments -n monitoring
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAME"* ]]
} 