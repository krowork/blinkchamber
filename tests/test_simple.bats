#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'

ZITADEL_RELEASE_NAME="zitadel"
VAULT_RELEASE_NAME="vault"
NAMESPACE="default"

@test "Test simple de variables" {
  [ "$ZITADEL_RELEASE_NAME" = "zitadel" ]
  [ "$VAULT_RELEASE_NAME" = "vault" ]
  [ "$NAMESPACE" = "default" ]
}

@test "Test simple de kubectl" {
  run kubectl version --client
  [ "$status" -eq 0 ]
} 