#!/usr/bin/env bats

@test "Fallo Vault Agent (delete pod)" {
  run kubectl delete pod -n mail -l app=mailu --grace-period=0 --force
  [ "$status" -eq 0 ]
}

@test "Fallo Vault (scale down)" {
  run kubectl scale statefulset/vault -n vault --replicas=0
  [ "$status" -eq 0 ]
}

@test "Fallo Vault (scale up)" {
  run kubectl scale statefulset/vault -n vault --replicas=1
  [ "$status" -eq 0 ]
}

@test "Fallo de Red (ping Vault)" {
  run kubectl run test-network --image=busybox --rm -it --restart=Never -- ping -c 3 vault.vault.svc.cluster.local
  [ "$status" -eq 0 ]
} 