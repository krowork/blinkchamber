#!/usr/bin/env bats

@test "Vault HA" {
  run kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items..status.phase}'
  [ "$status" -eq 0 ]
  [[ "$output" == "Running Running Running" ]]
}

@test "Zitadel HA" {
  run kubectl get pods -n default -l app.kubernetes.io/component=zitadel -o jsonpath='{.items..status.phase}'
  [ "$status" -eq 0 ]
  [[ "$output" == "Running Running Running" ]]
}

@test "PostgreSQL HA" {
  run kubectl get cluster -n database postgres-cluster -o jsonpath='{.status.instances}'
  [ "$status" -eq 0 ]
  [[ "$output" -eq 3 ]]
}

@test "Vault Failover" {
  run kubectl delete pod -n vault -l app.kubernetes.io/name=vault --selector='statefulset.kubernetes.io/pod-name=vault-0'
  [ "$status" -eq 0 ]
  sleep 60
  run kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items..status.phase}'
  [ "$status" -eq 0 ]
  [[ "$output" == "Running Running Running" ]]
}

@test "Zitadel Failover" {
  run kubectl delete pod -n default -l app.kubernetes.io/component=zitadel --selector='statefulset.kubernetes.io/pod-name=zitadel-0'
  [ "$status" -eq 0 ]
  sleep 60
  run kubectl get pods -n default -l app.kubernetes.io/component=zitadel -o jsonpath='{.items..status.phase}'
  [ "$status" -eq 0 ]
  [[ "$output" == "Running Running Running" ]]
}

@test "PostgreSQL Failover" {
  run kubectl delete pod -n database -l cnpg.io/cluster=postgres-cluster,role=primary
  [ "$status" -eq 0 ]
  sleep 60
  run kubectl get cluster -n database postgres-cluster -o jsonpath='{.status.readyInstances}'
  [ "$status" -eq 0 ]
  [[ "$output" -eq 3 ]]
}
