#!/usr/bin/env bats

@test "Vault Policy List" {
  run kubectl exec -n vault statefulset/vault -- vault policy list
  [ "$status" -eq 0 ]
}

@test "Vault Policy Read (database-policy)" {
  run kubectl exec -n vault statefulset/vault -- vault policy read database-policy
  [ "$status" -eq 0 ]
}

@test "Vault Policy Read (identity-policy)" {
  run kubectl exec -n vault statefulset/vault -- vault policy read identity-policy
  [ "$status" -eq 0 ]
}

@test "Vault K8s Roles List" {
  run kubectl exec -n vault statefulset/vault -- vault list auth/kubernetes/role
  [ "$status" -eq 0 ]
}

@test "Vault K8s Role (mailu-role)" {
  run kubectl exec -n vault statefulset/vault -- vault read auth/kubernetes/role/mailu-role
  [ "$status" -eq 0 ]
}

@test "Vault K8s Role (zitadel-role)" {
  run kubectl exec -n vault statefulset/vault -- vault read auth/kubernetes/role/zitadel-role
  [ "$status" -eq 0 ]
} 