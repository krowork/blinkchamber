# modules/ingress/main.tf - Módulo especializado para Ingress Controller

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
  }
}

# Variables del módulo
variable "namespace" {
  description = "Namespace para el ingress controller"
  type        = string
  default     = "ingress-nginx"
}

variable "chart_version" {
  description = "Versión del chart de ingress-nginx"
  type        = string
  default     = "4.8.3"
}

variable "node_ports" {
  description = "Puertos de nodo para HTTP y HTTPS"
  type = object({
    http  = number
    https = number
  })
  default = {
    http  = 30080
    https = 30443
  }
}

variable "resources" {
  description = "Recursos para el ingress controller"
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
      memory = "128Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

variable "enable_metrics" {
  description = "Habilitar métricas para el ingress controller"
  type        = bool
  default     = true
}

# Namespace para Ingress Controller
resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "ingress-nginx"
      "app.kubernetes.io/instance"  = "ingress-nginx"
      "app.kubernetes.io/component" = "controller"
    }
  }
}

# Ingress NGINX Controller
resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name
  version    = var.chart_version

  values = [
    yamlencode({
      controller = {
        service = {
          type = "NodePort"
          nodePorts = {
            http  = var.node_ports.http
            https = var.node_ports.https
          }
        }

        nodeSelector = {
          "ingress-ready" = "true"
        }

        tolerations = [
          {
            key      = "node-role.kubernetes.io/control-plane"
            operator = "Equal"
            effect   = "NoSchedule"
          },
          {
            key      = "node-role.kubernetes.io/master"
            operator = "Equal"
            effect   = "NoSchedule"
          }
        ]

        # Configuración para Kind
        hostPort = {
          enabled = true
          ports = {
            http  = 80
            https = 443
          }
        }

        config = {
          "use-forwarded-headers"      = "true"
          "compute-full-forwarded-for" = "true"
          "use-proxy-protocol"         = "false"
        }

        metrics = {
          enabled = var.enable_metrics
        }

        admissionWebhooks = {
          enabled = true
        }

        resources = var.resources
      }
    })
  ]

  depends_on = [kubernetes_namespace.ingress_nginx]
}

# Outputs del módulo
output "namespace" {
  description = "Namespace del ingress controller"
  value       = kubernetes_namespace.ingress_nginx.metadata[0].name
}

output "service_name" {
  description = "Nombre del servicio del ingress controller"
  value       = "${helm_release.ingress_nginx.name}-controller"
}

output "ready" {
  description = "Estado de preparación del ingress controller"
  value       = helm_release.ingress_nginx.status == "deployed"
}

output "node_ports" {
  description = "Puertos de nodo expuestos"
  value       = var.node_ports
} 