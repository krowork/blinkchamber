# modules/identity/main.tf - Módulo especializado para Zitadel

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14.0"
    }
  }
}

# Variables del módulo
variable "namespace" {
  description = "Namespace para Zitadel"
  type        = string
  default     = "identity"
}

variable "database_config" {
  description = "Configuración de conexión a la base de datos"
  type = object({
    host     = string
    port     = number
    database = string
    secret   = string
  })
  default = {
    host     = "postgresql.database.svc.cluster.local"
    port     = 5432
    database = "blinkchamber"
    secret   = "app-credentials"
  }
}

variable "ingress_config" {
  description = "Configuración de ingress para Zitadel"
  type = object({
    enabled     = bool
    hosts       = list(string)
    tls_enabled = bool
    annotations = map(string)
  })
  default = {
    enabled     = true
    hosts       = ["localhost", "zitadel.blinkchamber.local"]
    tls_enabled = true
    annotations = {
      "kubernetes.io/ingress.class"                  = "nginx"
      "cert-manager.io/cluster-issuer"               = "ca-issuer"
      "nginx.ingress.kubernetes.io/ssl-redirect"     = "true"
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTP"
    }
  }
}

variable "replicas" {
  description = "Número de réplicas de Zitadel"
  type        = number
  default     = 2
}

variable "resources" {
  description = "Recursos para Zitadel"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "1Gi"
    }
  }
}

variable "tls_enabled" {
  description = "Habilitar TLS para Zitadel"
  type        = bool
  default     = false
}

# Namespace para Zitadel
resource "kubernetes_namespace" "identity" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "identity"
      "app.kubernetes.io/instance" = "zitadel"
    }
  }
}

# Aplicar manifiestos de Zitadel
resource "kubectl_manifest" "zitadel_deployment" {
  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "zitadel"
      namespace = kubernetes_namespace.identity.metadata[0].name
      labels = {
        app                          = "zitadel"
        "app.kubernetes.io/name"     = "zitadel"
        "app.kubernetes.io/instance" = "zitadel"
      }
    }
    spec = {
      replicas = var.replicas
      selector = {
        matchLabels = {
          app = "zitadel"
        }
      }
      template = {
        metadata = {
          labels = {
            app = "zitadel"
          }
        }
        spec = {
          containers = [
            {
              name  = "zitadel"
              image = "ghcr.io/zitadel/zitadel:v2.42.0"
              ports = [
                {
                  containerPort = 8080
                  protocol      = "TCP"
                }
              ]
              env = [
                {
                  name  = "ZITADEL_DATABASE_POSTGRES_HOST"
                  value = var.database_config.host
                },
                {
                  name  = "ZITADEL_DATABASE_POSTGRES_PORT"
                  value = tostring(var.database_config.port)
                },
                {
                  name  = "ZITADEL_DATABASE_POSTGRES_DATABASE"
                  value = var.database_config.database
                },
                {
                  name = "ZITADEL_DATABASE_POSTGRES_USER_USERNAME"
                  valueFrom = {
                    secretKeyRef = {
                      name = var.database_config.secret
                      key  = "zitadel-user"
                    }
                  }
                },
                {
                  name = "ZITADEL_DATABASE_POSTGRES_USER_PASSWORD"
                  valueFrom = {
                    secretKeyRef = {
                      name = var.database_config.secret
                      key  = "zitadel-password"
                    }
                  }
                },
                {
                  name = "ZITADEL_DATABASE_POSTGRES_ADMIN_USERNAME"
                  valueFrom = {
                    secretKeyRef = {
                      name = var.database_config.secret
                      key  = "zitadel-user"
                    }
                  }
                },
                {
                  name = "ZITADEL_DATABASE_POSTGRES_ADMIN_PASSWORD"
                  valueFrom = {
                    secretKeyRef = {
                      name = var.database_config.secret
                      key  = "zitadel-password"
                    }
                  }
                },
                {
                  name  = "ZITADEL_DATABASE_POSTGRES_USER_SSL_MODE"
                  value = "disable"
                },
                {
                  name  = "ZITADEL_DATABASE_POSTGRES_ADMIN_SSL_MODE"
                  value = "disable"
                },
                {
                  name  = "ZITADEL_EXTERNALSECURE"
                  value = tostring(var.tls_enabled)
                },
                {
                  name  = "ZITADEL_TLS_ENABLED"
                  value = tostring(var.tls_enabled)
                },
                {
                  name  = "ZITADEL_MASTERKEY"
                  value = "MasterkeyNeedsToHave32Characters"
                },
                {
                  name  = "ZITADEL_CONFIGMAPNAME"
                  value = ""
                }
              ]
              args = [
                "start-from-init",
                "--masterkeyFromEnv",
                var.tls_enabled ? "--tlsMode=enabled" : "--tlsMode=disabled"
              ]
              resources = var.resources
              livenessProbe = {
                httpGet = {
                  path = "/debug/healthz"
                  port = 8080
                }
                initialDelaySeconds = 30
                periodSeconds       = 10
                timeoutSeconds      = 5
                failureThreshold    = 3
              }
              readinessProbe = {
                httpGet = {
                  path = "/debug/ready"
                  port = 8080
                }
                initialDelaySeconds = 5
                periodSeconds       = 5
                timeoutSeconds      = 3
                failureThreshold    = 3
              }
            }
          ]
        }
      }
    }
  })
}

# Servicio para Zitadel
resource "kubectl_manifest" "zitadel_service" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "zitadel"
      namespace = kubernetes_namespace.identity.metadata[0].name
      labels = {
        app                          = "zitadel"
        "app.kubernetes.io/name"     = "zitadel"
        "app.kubernetes.io/instance" = "zitadel"
      }
    }
    spec = {
      selector = {
        app = "zitadel"
      }
      ports = [
        {
          port       = 8080
          targetPort = 8080
          protocol   = "TCP"
        }
      ]
      type = "ClusterIP"
    }
  })

  depends_on = [kubectl_manifest.zitadel_deployment]
}

# Ingress para Zitadel (si está habilitado)
resource "kubectl_manifest" "zitadel_ingress" {
  count = var.ingress_config.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name        = "zitadel"
      namespace   = kubernetes_namespace.identity.metadata[0].name
      annotations = var.ingress_config.annotations
      labels = {
        app                          = "zitadel"
        "app.kubernetes.io/name"     = "zitadel"
        "app.kubernetes.io/instance" = "zitadel"
      }
    }
    spec = {
      rules = [for host in var.ingress_config.hosts : {
        host = host
        http = {
          paths = [
            {
              path     = "/"
              pathType = "Prefix"
              backend = {
                service = {
                  name = "zitadel"
                  port = {
                    number = 8080
                  }
                }
              }
            }
          ]
        }
      }]
      tls = var.ingress_config.tls_enabled ? [
        {
          secretName = "zitadel-tls"
          hosts      = var.ingress_config.hosts
        }
      ] : []
    }
  })

  depends_on = [kubectl_manifest.zitadel_service]
}

# Outputs del módulo
output "namespace" {
  description = "Namespace de Zitadel"
  value       = kubernetes_namespace.identity.metadata[0].name
}

output "service_name" {
  description = "Nombre del servicio de Zitadel"
  value       = "zitadel"
}

output "endpoint" {
  description = "Endpoint de Zitadel"
  value       = "zitadel.${kubernetes_namespace.identity.metadata[0].name}.svc.cluster.local:8080"
}

output "urls" {
  description = "URLs de acceso a Zitadel"
  value = {
    http  = "http://localhost:8080/"
    https = var.tls_enabled ? "https://zitadel.blinkchamber.local/" : null
    admin = "http://localhost:8080/ui/console/"
  }
}

output "ingress_hosts" {
  description = "Hosts de ingress para Zitadel"
  value       = var.ingress_config.enabled ? var.ingress_config.hosts : []
}

output "ready" {
  description = "Estado de preparación de Zitadel"
  value       = true
} 