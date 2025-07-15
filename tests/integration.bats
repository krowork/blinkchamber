#!/usr/bin/env bats

@test "Vault Put Secret (integration)" {
  run kubectl exec -n vault statefulset/vault -- vault kv put secret/test/integration value=test123
  [ "$status" -eq 0 ]
}

@test "Vault Get Secret (integration)" {
  run kubectl exec -n vault statefulset/vault -- vault kv get secret/test/integration
  [ "$status" -eq 0 ]
}

@test "Vault Delete Secret (integration)" {
  run kubectl exec -n vault statefulset/vault -- vault kv delete secret/test/integration
  [ "$status" -eq 0 ]
}

@test "DNS Mailu" {
  run kubectl run test-communication --image=busybox --rm -it --restart=Never -- nslookup mailu.mail.svc.cluster.local
  [ "$status" -eq 0 ]
}

@test "DNS Zitadel" {
  run kubectl run test-communication --image=busybox --rm -it --restart=Never -- nslookup zitadel.identity.svc.cluster.local
  [ "$status" -eq 0 ]
}

@test "DNS Grafana" {
  run kubectl run test-communication --image=busybox --rm -it --restart=Never -- nslookup grafana.monitoring.svc.cluster.local
  [ "$status" -eq 0 ]
} 