#!/usr/bin/env bats

@test "Test mínimo de BATS" {
  run echo "ok"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
} 