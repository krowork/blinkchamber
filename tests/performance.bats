#!/usr/bin/env bats

@test "Top Pods" {
  run kubectl top pods --all-namespaces
  [ "$status" -eq 0 ]
}

@test "Pods Resources" {
  run kubectl get pods --all-namespaces -o jsonpath='{.items[*].spec.containers[*].resources}'
  [ "$status" -eq 0 ]
}

@test "Vault Latencia DB" {
  run kubectl exec -n vault statefulset/vault -- vault kv get secret/database/postgres
  [ "$status" -eq 0 ]
}

@test "Vault Latencia Zitadel" {
  run kubectl exec -n vault statefulset/vault -- vault kv get secret/identity/zitadel
  [ "$status" -eq 0 ]
} 