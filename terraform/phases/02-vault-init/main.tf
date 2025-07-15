# terraform/phases/02-vault-init/main.tf
# Fase 2: Inicialización Automática de Vault

terraform {
  required_version = ">= 1.5.0"

  # Backend local para desarrollo
  backend "local" {
    path = "../terraform-vault-init.tfstate"
  }

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.21.0"
    }
  }
}

# Configuración de proveedores
provider "kubernetes" {
  config_path    = pathexpand("~/.kube/config")
  config_context = "kind-${var.cluster_name}"
}

provider "helm" {
  kubernetes {
    config_path    = pathexpand("~/.kube/config")
    config_context = "kind-${var.cluster_name}"
  }
}

provider "kubectl" {
  config_path    = pathexpand("~/.kube/config")
  config_context = "kind-${var.cluster_name}"
}

provider "vault" {
  address = "http://vault.vault.svc.cluster.local:8200"
  token   = var.vault_token
}

# Variables principales
variable "cluster_name" {
  description = "Nombre del cluster"
  type        = string
  default     = "blinkchamber"
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  default     = "development"
}

variable "auto_unseal_method" {
  description = "Método de auto-unseal"
  type        = string
  default     = "shamir"
  validation {
    condition     = contains(["shamir", "transit", "awskms", "azurekeyvault"], var.auto_unseal_method)
    error_message = "Método de auto-unseal debe ser: shamir, transit, awskms, o azurekeyvault."
  }
}

variable "vault_namespace" {
  description = "Namespace donde está desplegado Vault"
  type        = string
  default     = "vault"
}

variable "init_timeout" {
  description = "Timeout para la inicialización en segundos"
  type        = number
  default     = 600
}

# Variables para auto-unseal AWS KMS
variable "kms_key_id" {
  description = "ID de la clave KMS para auto-unseal"
  type        = string
  default     = ""
}

# Variables para auto-unseal Azure Key Vault
variable "azure_tenant_id" {
  description = "Azure Tenant ID para auto-unseal"
  type        = string
  default     = ""
}

variable "azure_client_id" {
  description = "Azure Client ID para auto-unseal"
  type        = string
  default     = ""
}

variable "azure_client_secret" {
  description = "Azure Client Secret para auto-unseal"
  type        = string
  default     = ""
}

variable "azure_vault_name" {
  description = "Azure Key Vault name para auto-unseal"
  type        = string
  default     = ""
}

variable "azure_key_name" {
  description = "Azure Key name para auto-unseal"
  type        = string
  default     = ""
}

variable "vault_token" {
  description = "Token de Vault para configuración"
  type        = string
  default     = ""
}

# Datos de la fase anterior
data "terraform_remote_state" "bootstrap" {
  backend = "local"
  config = {
    path = "../terraform-bootstrap.tfstate"
  }
}

# Configuración local
locals {
  vault_endpoint = data.terraform_remote_state.bootstrap.outputs.phase1_status.components.vault_infrastructure.endpoint
  vault_external = "http://localhost:8200"

  # Configuración de auto-unseal por entorno
  auto_unseal_config = var.environment == "production" ? {
    enabled = true
    method  = var.auto_unseal_method
    config = var.auto_unseal_method == "awskms" ? {
      region     = "us-west-2"
      kms_key_id = var.kms_key_id
      } : var.auto_unseal_method == "azurekeyvault" ? {
      tenant_id     = var.azure_tenant_id
      client_id     = var.azure_client_id
      client_secret = var.azure_client_secret
      vault_name    = var.azure_vault_name
      key_name      = var.azure_key_name
    } : {}
    } : {
    enabled = false
    method  = "shamir"
    config  = {}
  }
}

# Random ID para jobs únicos
resource "random_id" "init_job_id" {
  byte_length = 4
}

# Job para inicialización automática de Vault
resource "kubernetes_job" "vault_init" {
  metadata {
    name      = "vault-init-${random_id.init_job_id.hex}"
    namespace = var.vault_namespace
    labels = {
      "app"                       = "vault-init"
      "blinkchamber.io/phase"     = "2"
      "blinkchamber.io/component" = "vault-initialization"
    }
  }

  spec {
    ttl_seconds_after_finished = 300
    backoff_limit              = 3

    template {
      metadata {
        labels = {
          "app" = "vault-init"
        }
      }

      spec {
        restart_policy       = "OnFailure"
        service_account_name = "vault"

        init_container {
          name    = "wait-for-vault"
          image   = "busybox:1.35"
          command = ["/bin/sh"]
          args = [
            "-c",
            <<-EOT
              echo "Esperando que Vault esté disponible..."
              until nc -z vault.${var.vault_namespace}.svc.cluster.local 8200; do
                echo "Vault no disponible, esperando..."
                sleep 5
              done
              echo "Vault está disponible!"
            EOT
          ]
        }

        container {
          name  = "vault-init"
          image = "hashicorp/vault:1.15.2"

          command = ["/bin/sh"]
          args = [
            "-c",
            <<-EOT
              #!/bin/sh
              set -e
              
              export VAULT_ADDR="${local.vault_endpoint}"
              export VAULT_SKIP_VERIFY=true
              
              echo "🔧 Iniciando proceso de inicialización de Vault..."
              
              # Función para verificar estado de Vault
              check_vault_status() {
                vault status > /tmp/vault-status.txt 2>&1 || true
                cat /tmp/vault-status.txt
              }
              
              # Esperar a que Vault esté listo
              echo "⏳ Esperando que Vault esté listo..."
              for i in $(seq 1 60); do
                if vault status 2>/dev/null; then
                  echo "✅ Vault está respondiendo"
                  break
                fi
                echo "Intento $i/60: Vault no responde, esperando..."
                sleep 5
              done
              
              # Verificar si Vault ya está inicializado
              if vault status | grep -q "Initialized.*true"; then
                echo "ℹ️ Vault ya está inicializado"
                
                # Verificar si está unsealed
                if vault status | grep -q "Sealed.*false"; then
                  echo "✅ Vault ya está unsealed"
                  # Configurar token si existe
                  if kubectl get secret vault-root-token -n ${var.vault_namespace} >/dev/null 2>&1; then
                    ROOT_TOKEN=$(kubectl get secret vault-root-token -n ${var.vault_namespace} -o jsonpath='{.data.token}' | base64 -d)
                    export VAULT_TOKEN=$ROOT_TOKEN
                    echo "🔑 Token root configurado desde secret existente"
                  fi
                  # Continuar con configuración
                else
                  echo "🔓 Vault está sealed, intentando unseal..."
                  # En auto-unseal, esto debería resolverse automáticamente
                  if [ "${tostring(local.auto_unseal_config.enabled)}" = "true" ]; then
                    echo "⏳ Esperando auto-unseal..."
                    for i in $(seq 1 30); do
                      if vault status | grep -q "Sealed.*false"; then
                        echo "✅ Auto-unseal completado"
                        break
                      fi
                      sleep 2
                    done
                    if vault status | grep -q "Sealed.*false"; then
                      echo "✅ Auto-unseal exitoso"
                    else
                      echo "❌ Auto-unseal falló"
                      exit 1
                    fi
                  else
                    echo "🔓 Realizando unseal manual..."
                    # Intentar obtener claves de unseal
                    if kubectl get secret vault-init-keys -n ${var.vault_namespace} >/dev/null 2>&1; then
                      kubectl get secret vault-init-keys -n ${var.vault_namespace} -o jsonpath='{.data.vault-init\.json}' | base64 -d > /tmp/vault-init.json
                      
                      UNSEAL_KEY_1=$(cat /tmp/vault-init.json | jq -r '.unseal_keys_b64[0]')
                      UNSEAL_KEY_2=$(cat /tmp/vault-init.json | jq -r '.unseal_keys_b64[1]')
                      UNSEAL_KEY_3=$(cat /tmp/vault-init.json | jq -r '.unseal_keys_b64[2]')
                      
                      vault operator unseal $UNSEAL_KEY_1
                      vault operator unseal $UNSEAL_KEY_2
                      vault operator unseal $UNSEAL_KEY_3
                      
                      echo "✅ Vault unsealed exitosamente"
                    else
                      echo "❌ No se encontraron claves de unseal"
                      exit 1
                    fi
                  fi
                  
                  # Configurar token después del unseal
                  if kubectl get secret vault-root-token -n ${var.vault_namespace} >/dev/null 2>&1; then
                    ROOT_TOKEN=$(kubectl get secret vault-root-token -n ${var.vault_namespace} -o jsonpath='{.data.token}' | base64 -d)
                    export VAULT_TOKEN=$ROOT_TOKEN
                    echo "🔑 Token root configurado"
                  fi
                fi
              fi
              
              echo "🔐 Inicializando Vault..."
              
              # Configurar parámetros de inicialización
              if [ "${tostring(local.auto_unseal_config.enabled)}" = "true" ]; then
                echo "🔧 Inicializando con auto-unseal (${local.auto_unseal_config.method})"
                vault operator init \
                  -recovery-shares=5 \
                  -recovery-threshold=3 \
                  -format=json > /tmp/vault-init.json
              else
                echo "🔧 Inicializando con Shamir secret sharing"
                vault operator init \
                  -key-shares=5 \
                  -key-threshold=3 \
                  -format=json > /tmp/vault-init.json
              fi
              
              echo "✅ Vault inicializado exitosamente"
              
              # Guardar claves de inicialización en secret de Kubernetes
              kubectl create secret generic vault-init-keys \
                --from-file=vault-init.json=/tmp/vault-init.json \
                --namespace=${var.vault_namespace} \
                --dry-run=client -o yaml | kubectl apply -f -
              
              echo "💾 Claves de inicialización guardadas en secret/vault-init-keys"
              
              # Obtener root token
              ROOT_TOKEN=$(cat /tmp/vault-init.json | jq -r '.root_token')
              export VAULT_TOKEN=$ROOT_TOKEN
              
              # Si no hay auto-unseal, realizar unseal manual
              if [ "${tostring(local.auto_unseal_config.enabled)}" != "true" ]; then
                echo "🔓 Realizando unseal manual..."
                UNSEAL_KEY_1=$(cat /tmp/vault-init.json | jq -r '.unseal_keys_b64[0]')
                UNSEAL_KEY_2=$(cat /tmp/vault-init.json | jq -r '.unseal_keys_b64[1]')
                UNSEAL_KEY_3=$(cat /tmp/vault-init.json | jq -r '.unseal_keys_b64[2]')
                
                vault operator unseal $UNSEAL_KEY_1
                vault operator unseal $UNSEAL_KEY_2
                vault operator unseal $UNSEAL_KEY_3
                
                echo "✅ Vault unsealed exitosamente"
              fi
              
              # Configurar autenticación de Kubernetes
              echo "🔧 Configurando autenticación de Kubernetes..."
              
              vault auth enable kubernetes || echo "Auth kubernetes ya está habilitado"
              
              vault write auth/kubernetes/config \
                token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
                kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
                kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
              
              echo "✅ Autenticación de Kubernetes configurada"
              
              # Crear políticas básicas
              echo "📋 Creando políticas básicas..."
              
              # Política para desarrollo
              vault policy write blinkchamber-dev - <<EOF
              path "secret/data/database/*" {
                capabilities = ["read"]
              }
              path "secret/data/identity/*" {
                capabilities = ["read"]
              }
              path "secret/data/storage/*" {
                capabilities = ["read"]
              }
              EOF
              
              # Política para administración
              vault policy write blinkchamber-admin - <<EOF
              path "secret/*" {
                capabilities = ["create", "read", "update", "delete", "list"]
              }
              path "auth/*" {
                capabilities = ["create", "read", "update", "delete", "list"]
              }
              path "sys/policies/*" {
                capabilities = ["create", "read", "update", "delete", "list"]
              }
              EOF
              
              echo "✅ Políticas básicas creadas"
              
              # Guardar token root en secret separado (temporal)
              kubectl create secret generic vault-root-token \
                --from-literal=token=$ROOT_TOKEN \
                --namespace=${var.vault_namespace} \
                --dry-run=client -o yaml | kubectl apply -f -
              
              echo "💾 Root token guardado en secret/vault-root-token"
              
              # Verificación final
              echo "🔍 Verificación final..."
              vault status
              vault auth list
              vault policy list
              
              echo "🎉 ¡Inicialización de Vault completada exitosamente!"
              echo "📝 Próximos pasos:"
              echo "   1. Configurar secretos en Vault (Fase 3)"
              echo "   2. Desplegar aplicaciones con Vault (Fase 4)"
            EOT
          ]

          env {
            name  = "VAULT_ADDR"
            value = local.vault_endpoint
          }

          env {
            name  = "VAULT_SKIP_VERIFY"
            value = "true"
          }

          # Variables de entorno para auto-unseal si están configuradas
          dynamic "env" {
            for_each = local.auto_unseal_config.config
            content {
              name  = upper(env.key)
              value = env.value
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "tmp"
          empty_dir {}
        }
      }
    }
  }

  timeouts {
    create = "${var.init_timeout}s"
    update = "${var.init_timeout}s"
  }
}

# ConfigMap con información de inicialización
resource "kubernetes_config_map" "vault_init_info" {
  metadata {
    name      = "vault-init-info"
    namespace = var.vault_namespace
    labels = {
      "blinkchamber.io/phase"     = "2"
      "blinkchamber.io/component" = "vault-configuration"
    }
  }

  data = {
    vault_endpoint  = local.vault_endpoint
    auto_unseal     = tostring(local.auto_unseal_config.enabled)
    unseal_method   = local.auto_unseal_config.method
    environment     = var.environment
    init_timestamp  = timestamp()
    phase_completed = "2"
    next_phase      = "3"
  }

  depends_on = [kubernetes_job.vault_init]
}

# Outputs de la fase 2
output "phase2_status" {
  description = "Estado de la fase 2 - Inicialización de Vault"
  value = {
    vault_endpoint  = local.vault_endpoint
    init_job_name   = kubernetes_job.vault_init.metadata[0].name
    auto_unseal     = local.auto_unseal_config.enabled
    unseal_method   = local.auto_unseal_config.method
    kubernetes_auth = true
    basic_policies  = true
  }
}

output "next_phase" {
  description = "Información para la siguiente fase"
  value = {
    phase             = 3
    description       = "Secrets Management"
    vault_ready       = true
    prerequisites_met = true
  }
}

output "vault_access" {
  description = "Información de acceso a Vault"
  value = {
    internal_endpoint = local.vault_endpoint
    ui_url            = "http://localhost:8200/ui"
    port_forward_cmd  = "kubectl port-forward svc/vault -n ${var.vault_namespace} 8200:8200"
    root_token_secret = "vault-root-token"
    init_keys_secret  = "vault-init-keys"
  }
  sensitive = false
} 