# modules/storage/main.tf - Módulo especializado para MinIO

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
  description = "Namespace para MinIO"
  type        = string
  default     = "minio"
}

variable "chart_version" {
  description = "Versión del chart de MinIO"
  type        = string
  default     = "5.0.14"
}

variable "credentials" {
  description = "Credenciales de MinIO"
  type = object({
    root_user     = string
    root_password = string
  })
  default = {
    root_user     = "admin"
    root_password = "minio123"
  }
}

variable "storage_size" {
  description = "Tamaño de almacenamiento para MinIO"
  type        = string
  default     = "10Gi"
}

variable "resources" {
  description = "Recursos para MinIO"
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

variable "buckets" {
  description = "Lista de buckets a crear"
  type        = list(string)
  default     = ["terraform-state", "vault-backups", "grafana-data", "application-data"]
}

# Namespace para MinIO
resource "kubernetes_namespace" "minio" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "minio"
      "app.kubernetes.io/instance" = "minio"
    }
  }
}

# Secret para credenciales de MinIO
resource "kubernetes_secret" "minio_secret" {
  metadata {
    name      = "minio-secret"
    namespace = kubernetes_namespace.minio.metadata[0].name
  }

  type = "Opaque"

  data = {
    "root-user"     = base64encode(var.credentials.root_user)
    "root-password" = base64encode(var.credentials.root_password)
  }
}

# MinIO usando Helm Chart
resource "helm_release" "minio" {
  name       = "minio"
  repository = "https://charts.min.io/"
  chart      = "minio"
  namespace  = kubernetes_namespace.minio.metadata[0].name
  version    = var.chart_version

  values = [
    yamlencode({
      auth = {
        existingSecret = kubernetes_secret.minio_secret.metadata[0].name
      }

      mode = "standalone"

      persistence = {
        enabled      = true
        storageClass = "standard"
        accessMode   = "ReadWriteOnce"
        size         = var.storage_size
      }

      replicas = 1

      service = {
        type = "ClusterIP"
        port = 9000
      }

      consoleService = {
        type = "ClusterIP"
        port = 9001
      }

      buckets = [for bucket in var.buckets : {
        name   = bucket
        policy = "none"
        purge  = false
      }]

      resources = var.resources

      podSecurityContext = {
        enabled    = true
        fsGroup    = 1001
        runAsUser  = 1001
        runAsGroup = 1001
      }

      containerSecurityContext = {
        enabled                  = true
        runAsUser                = 1001
        runAsGroup               = 1001
        runAsNonRoot             = true
        allowPrivilegeEscalation = false
        readOnlyRootFilesystem   = false
        capabilities = {
          drop = ["ALL"]
        }
      }

      livenessProbe = {
        enabled             = true
        initialDelaySeconds = 30
        periodSeconds       = 10
        timeoutSeconds      = 5
        failureThreshold    = 3
        successThreshold    = 1
      }

      readinessProbe = {
        enabled             = true
        initialDelaySeconds = 5
        periodSeconds       = 5
        timeoutSeconds      = 3
        failureThreshold    = 3
        successThreshold    = 1
      }

      startupProbe = {
        enabled             = true
        initialDelaySeconds = 10
        periodSeconds       = 10
        timeoutSeconds      = 5
        failureThreshold    = 30
        successThreshold    = 1
      }

      metrics = {
        serviceMonitor = {
          enabled = false
        }
      }

      extraEnvVars = [
        {
          name  = "MINIO_LOG_LEVEL"
          value = "INFO"
        },
        {
          name  = "MINIO_PROMETHEUS_AUTH_TYPE"
          value = "public"
        }
      ]
    })
  ]

  depends_on = [
    kubernetes_namespace.minio,
    kubernetes_secret.minio_secret
  ]
}

# Outputs del módulo
output "namespace" {
  description = "Namespace de MinIO"
  value       = kubernetes_namespace.minio.metadata[0].name
}

output "service_name" {
  description = "Nombre del servicio de MinIO"
  value       = "minio"
}

output "console_service_name" {
  description = "Nombre del servicio de consola de MinIO"
  value       = "minio-console"
}

output "endpoint" {
  description = "Endpoint de MinIO"
  value       = "minio.${kubernetes_namespace.minio.metadata[0].name}.svc.cluster.local:9000"
}

output "console_endpoint" {
  description = "Endpoint de consola de MinIO"
  value       = "minio.${kubernetes_namespace.minio.metadata[0].name}.svc.cluster.local:9001"
}

output "buckets" {
  description = "Lista de buckets creados"
  value       = var.buckets
}

output "ready" {
  description = "Estado de preparación de MinIO"
  value       = helm_release.minio.status == "deployed"
} 