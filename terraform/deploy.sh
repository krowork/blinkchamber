#!/bin/bash

set -e

# Inicializar Terraform
terraform init

# Validar la configuración de Terraform
terraform validate

# Aplicar los cambios
terraform apply -auto-approve
