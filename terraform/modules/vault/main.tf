# modules/vault/main.tf - Módulo especializado para HashiCorp Vault

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

# Variables del módulo
variable "namespace" {
  description = "Namespace para Vault"
  type        = string
  default     = "vault"
}

variable "chart_version" {
  description = "Versión del chart de Vault"
  type        = string
  default     = "0.26.1"
}

variable "vault_image" {
  description = "Imagen de Vault"
  type = object({
    repository = string
    tag        = string
  })
  default = {
    repository = "hashicorp/vault"
    tag        = "1.15.2"
  }
}

variable "tls_enabled" {
  description = "Habilitar TLS para Vault"
  type        = bool
  default     = false
}

variable "ingress_config" {
  description = "Configuración de ingress para Vault"
  type = object({
    enabled     = bool
    host        = string
    tls_enabled = bool
    annotations = map(string)
  })
  default = {
    enabled     = true
    host        = "vault.blinkchamber.local"
    tls_enabled = true
    annotations = {
      "kubernetes.io/ingress.class"                  = "nginx"
      "cert-manager.io/cluster-issuer"               = "ca-issuer"
      "nginx.ingress.kubernetes.io/ssl-redirect"     = "true"
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTP"
    }
  }
}

variable "resources" {
  description = "Recursos para Vault"
  type = object({
    server = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
    injector = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
  })
  default = {
    server = {
      requests = {
        cpu    = "250m"
        memory = "256Mi"
      }
      limits = {
        cpu    = "1000m"
        memory = "1Gi"
      }
    }
    injector = {
      requests = {
        cpu    = "50m"
        memory = "64Mi"
      }
      limits = {
        cpu    = "100m"
        memory = "128Mi"
      }
    }
  }
}

variable "storage_size" {
  description = "Tamaño de almacenamiento para Vault"
  type        = string
  default     = "10Gi"
}

variable "high_availability" {
  description = "Configuración de alta disponibilidad"
  type = object({
    enabled  = bool
    replicas = number
  })
  default = {
    enabled  = false
    replicas = 1
  }
}

# Namespace para Vault
resource "kubernetes_namespace" "vault" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "vault"
      "app.kubernetes.io/instance"  = "vault"
      "app.kubernetes.io/component" = "server"
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
          config  = var.tls_enabled ? local.vault_config_tls : local.vault_config_http
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
        } : { enabled = false }

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
          enabled = true
          path    = "/v1/sys/health?standbyok=true&sealedcode=204&uninitcode=204"
        }

        livenessProbe = {
          enabled             = true
          path                = "/v1/sys/health?standbyok=true"
          initialDelaySeconds = 60
        }

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

      # Configuración de CSI
      csi = {
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
    
    service_registration "kubernetes" {}
    
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
    
    service_registration "kubernetes" {}
    
    log_level = "INFO"
    log_format = "json"
    
    api_addr = "https://POD_IP:8200"
    
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

# Outputs del módulo
output "namespace" {
  description = "Namespace de Vault"
  value       = kubernetes_namespace.vault.metadata[0].name
}

output "service_name" {
  description = "Nombre del servicio de Vault"
  value       = "vault"
}

output "endpoint" {
  description = "Endpoint de Vault"
  value       = var.tls_enabled ? "https://vault.${var.namespace}.svc.cluster.local:8200" : "http://vault.${var.namespace}.svc.cluster.local:8200"
}

output "ready" {
  description = "Estado de preparación de Vault"
  value       = helm_release.vault.status == "deployed"
}

output "service_account" {
  description = "ServiceAccount de Vault"
  value       = "vault"
}

output "ingress_host" {
  description = "Host de ingress para Vault"
  value       = var.ingress_config.enabled ? var.ingress_config.host : null
} 