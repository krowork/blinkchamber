#!/usr/bin/env bats

@test "Database Policy" {
  run kubectl exec -n vault statefulset/vault -- vault policy read database-policy
  [ "$status" -eq 0 ]
  [[ "$output" == *"path \"secret/data/database/*\""* ]]
}

@test "Identity Policy" {
  run kubectl exec -n vault statefulset/vault -- vault policy read identity-policy
  [ "$status" -eq 0 ]
  [[ "$output" == *"path \"secret/data/identity/*\""* ]]
}

@test "Monitoring Policy" {
  run kubectl exec -n vault statefulset/vault -- vault policy read monitoring-policy
  [ "$status" -eq 0 ]
  [[ "$output" == *"path \"secret/data/monitoring/*\""* ]]
}

@test "Database Role" {
  run kubectl exec -n vault statefulset/vault -- vault read auth/kubernetes/role/database-role
  [ "$status" -eq 0 ]
  [[ "$output" == *"bound_service_account_names*postgres"* ]]
}

@test "Identity Role" {
  run kubectl exec -n vault statefulset/vault -- vault read auth/kubernetes/role/identity-role
  [ "$status" -eq 0 ]
  [[ "$output" == *"bound_service_account_names*zitadel"* ]]
}

@test "Monitoring Role" {
  run kubectl exec -n vault statefulset/vault -- vault read auth/kubernetes/role/monitoring-role
  [ "$status" -eq 0 ]
  [[ "$output" == *"bound_service_account_names*grafana"* ]]
}
