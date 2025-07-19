#!/usr/bin/env bash

set -e

CLUSTER_NAME="blinkchamber"

if kind get clusters | grep -q "^$CLUSTER_NAME$"; then
  echo "El clúster Kind '$CLUSTER_NAME' ya existe."
else
  echo "Creando clúster Kind '$CLUSTER_NAME'..."
  kind create cluster --name "$CLUSTER_NAME"
fi 