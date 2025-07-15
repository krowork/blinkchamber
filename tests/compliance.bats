#!/usr/bin/env bats

@test "Vault Audit Logs Count" {
  run kubectl logs -n vault statefulset/vault --tail=100 | grep -i audit
  [ "$status" -eq 0 ]
}

@test "Vault Policy List (compliance)" {
  run kubectl exec -n vault statefulset/vault -- vault policy list
  [ "$status" -eq 0 ]
}

@test "Vault Auth List (kubernetes)" {
  run kubectl exec -n vault statefulset/vault -- vault auth list | grep kubernetes
  [ "$status" -eq 0 ]
}

@test "K8s TLS Secrets" {
  run kubectl get secrets --all-namespaces | grep tls
  [ "$status" -eq 0 ]
}

@test "K8s Certificates" {
  run kubectl get certificates --all-namespaces
  [ "$status" -eq 0 ]
} 