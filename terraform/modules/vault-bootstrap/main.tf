# terraform/modules/vault-bootstrap/main.tf
# Módulo especializado para Bootstrap de HashiCorp Vault

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
  }
}

# Variables del módulo se encuentran en variables.tf

# Namespace para Vault
resource "kubernetes_namespace" "vault" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "vault"
      "app.kubernetes.io/instance"  = "vault"
      "app.kubernetes.io/component" = "server"
      "blinkchamber.io/phase"       = var.deploy_only_infrastructure ? "1" : "2"
    }
  }
}

# ClusterRole para Vault
resource "kubernetes_cluster_role" "vault" {
  metadata {
    name = "vault-auth"
  }

  rule {
    api_groups = [""]
    resources  = ["serviceaccounts"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["authentication.k8s.io"]
    resources  = ["tokenreviews"]
    verbs      = ["create"]
  }

  rule {
    api_groups = ["authorization.k8s.io"]
    resources  = ["subjectaccessreviews"]
    verbs      = ["create"]
  }

  # Permisos adicionales para auto-inicialización
  dynamic "rule" {
    for_each = var.auto_init ? [1] : []
    content {
      api_groups = [""]
      resources  = ["secrets"]
      verbs      = ["create", "get", "update", "patch"]
    }
  }
}

# ClusterRoleBinding para Vault
resource "kubernetes_cluster_role_binding" "vault" {
  metadata {
    name = "vault-auth"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.vault.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "vault"
    namespace = kubernetes_namespace.vault.metadata[0].name
  }
}

# Random ID para jobs únicos
resource "random_id" "init_id" {
  count       = var.auto_init ? 1 : 0
  byte_length = 4
}

# Vault usando Helm Chart
resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  namespace  = kubernetes_namespace.vault.metadata[0].name
  version    = var.chart_version

  values = [
    yamlencode({
      global = {
        enabled    = true
        tlsDisable = !var.tls_enabled
      }

      injector = {
        enabled   = true
        replicas  = var.high_availability.enabled ? 2 : 1
        resources = var.resources.injector
      }

      server = {
        enabled = true

        image = var.vault_image

        # Configuración de almacenamiento
        dataStorage = {
          enabled      = true
          size         = var.storage_size
          storageClass = "standard"
        }

        # Configuración de alta disponibilidad
        ha = {
          enabled = var.high_availability.enabled
        }

        # Configuración standalone o HA
        standalone = {
          enabled = !var.high_availability.enabled
          config  = var.auto_unseal.enabled && var.auto_unseal.method != "shamir" ? local.vault_config_auto_unseal : (var.tls_enabled ? local.vault_config_tls : local.vault_config_http)
        }

        # Configuración de recursos
        resources = var.resources.server

        # Configuración de ingress
        ingress = var.ingress_config.enabled ? {
          enabled     = true
          annotations = var.ingress_config.annotations
          hosts = [
            {
              host  = var.ingress_config.host
              paths = ["/"]
            }
          ]
          tls = var.ingress_config.tls_enabled ? [
            {
              secretName = "vault-tls"
              hosts      = [var.ingress_config.host]
            }
          ] : []
          } : {
          enabled     = false
          annotations = {}
          hosts       = []
          tls         = []
        }

        # Configuración de ServiceAccount
        serviceAccount = {
          create = true
          name   = "vault"
        }

        # Configuración de seguridad
        securityContext = {
          runAsNonRoot = true
          runAsGroup   = 1000
          runAsUser    = 100
          fsGroup      = 1000
        }

        # Configuración de probes
        readinessProbe = {
          enabled             = true
          path                = "/v1/sys/health?standbyok=true&sealedcode=204&uninitcode=204"
          failureThreshold    = 5
          initialDelaySeconds = 30
          periodSeconds       = 10
          timeoutSeconds      = 5
        }

        livenessProbe = {
          enabled             = true
          path                = "/v1/sys/health?standbyok=true&sealedcode=204&uninitcode=204"
          initialDelaySeconds = 90
          failureThreshold    = 5
          periodSeconds       = 10
          timeoutSeconds      = 5
        }

        # Variables de entorno para auto-unseal
        extraEnvironmentVars = var.auto_unseal.enabled ? var.auto_unseal.config : {}

        # Configuración de affinity para HA
        affinity = var.high_availability.enabled ? {
          podAntiAffinity = {
            requiredDuringSchedulingIgnoredDuringExecution = [
              {
                labelSelector = {
                  matchLabels = {
                    "app.kubernetes.io/name"     = "vault"
                    "app.kubernetes.io/instance" = "vault"
                    "component"                  = "server"
                  }
                }
                topologyKey = "kubernetes.io/hostname"
              }
            ]
          }
        } : null
      }

      # Configuración de UI
      ui = {
        enabled     = true
        serviceType = "ClusterIP"
      }

      # Configuración de CSI (solo si no es solo infraestructura)
      csi = var.deploy_only_infrastructure ? {
        enabled = false
        image = {
          repository = "hashicorp/vault-csi-provider"
          tag        = "1.4.2"
        }
        resources = {
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "256Mi"
          }
        }
        } : {
        enabled = true
        image = {
          repository = "hashicorp/vault-csi-provider"
          tag        = "1.4.2"
        }
        resources = {
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "256Mi"
          }
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.vault,
    kubernetes_cluster_role_binding.vault
  ]
}

# Configuración local para Vault
locals {
  vault_config_http = <<-EOT
    ui = true
    
    listener "tcp" {
      address     = "0.0.0.0:8200"
      tls_disable = 1
    }
    
    storage "file" {
      path = "/vault/data"
    }
    
    log_level = "INFO"
    log_format = "json"
    
    api_addr = "http://POD_IP:8200"
    
    telemetry {
      prometheus_retention_time = "30s"
      disable_hostname = true
    }
  EOT

  vault_config_tls = <<-EOT
    ui = true
    
    listener "tcp" {
      address       = "0.0.0.0:8200"
      tls_cert_file = "/vault/tls/tls.crt"
      tls_key_file  = "/vault/tls/tls.key"
    }
    
    storage "file" {
      path = "/vault/data"
    }
    
    log_level = "INFO"
    log_format = "json"
    
    api_addr = "https://POD_IP:8200"
    
    telemetry {
      prometheus_retention_time = "30s"
      disable_hostname = true
    }
  EOT

  vault_config_auto_unseal = <<-EOT
    ui = true
    
    listener "tcp" {
      address     = "0.0.0.0:8200"
      tls_disable = 1
    }
    
    storage "file" {
      path = "/vault/data"
    }
    
    seal "${var.auto_unseal.method}" {
      ${join("\n      ", [for k, v in var.auto_unseal.config : "${k} = \"${v}\""])}
    }
    
    log_level = "INFO"
    log_format = "json"
    
    api_addr = "http://POD_IP:8200"
    
    telemetry {
      prometheus_retention_time = "30s"
      disable_hostname = true
    }
  EOT
}

# NetworkPolicy para Vault
resource "kubernetes_network_policy" "vault_network_policy" {
  metadata {
    name      = "vault-network-policy"
    namespace = kubernetes_namespace.vault.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name"     = "vault"
        "app.kubernetes.io/instance" = "vault"
      }
    }

    policy_types = ["Ingress", "Egress"]

    # Ingress rules
    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = "ingress-nginx"
          }
        }
      }

      from {
        namespace_selector {
          match_labels = {
            name = "identity"
          }
        }
      }

      from {
        namespace_selector {
          match_labels = {
            name = "database"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "8200"
      }
    }

    # Egress rules
    egress {
      # Allow DNS
      to {
        namespace_selector {
          match_labels = {
            name = "kube-system"
          }
        }
      }

      ports {
        protocol = "UDP"
        port     = "53"
      }
    }

    egress {
      # Allow Kubernetes API
      ports {
        protocol = "TCP"
        port     = "443"
      }
    }
  }
} 