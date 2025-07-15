# modules/database/main.tf - Módulo especializado para PostgreSQL

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
  description = "Namespace para PostgreSQL"
  type        = string
  default     = "database"
}

variable "chart_version" {
  description = "Versión del chart de PostgreSQL"
  type        = string
  default     = "13.2.24"
}

variable "postgres_config" {
  description = "Configuración de PostgreSQL"
  type = object({
    version  = string
    database = string
    user     = string
  })
  default = {
    version  = "15"
    database = "blinkchamber"
    user     = "postgres"
  }
}

variable "storage_size" {
  description = "Tamaño de almacenamiento para PostgreSQL"
  type        = string
  default     = "10Gi"
}

variable "resources" {
  description = "Recursos para PostgreSQL"
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
      cpu    = "250m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
  }
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

# Namespace para PostgreSQL
resource "kubernetes_namespace" "database" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "database"
      "app.kubernetes.io/instance" = "postgresql"
    }
  }
}

# Generar contraseñas seguras
resource "random_password" "postgres_password" {
  length  = 32
  special = true
}

resource "random_password" "zitadel_password" {
  length  = 32
  special = true
}

resource "random_password" "grafana_password" {
  length  = 32
  special = true
}

# PostgreSQL usando Helm
resource "helm_release" "postgresql" {
  name       = "postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  namespace  = kubernetes_namespace.database.metadata[0].name
  version    = var.chart_version

  values = [
    yamlencode({
      auth = {
        postgresPassword = random_password.postgres_password.result
        database         = var.postgres_config.database
      }

      primary = {
        persistence = {
          enabled      = true
          storageClass = "standard"
          size         = var.storage_size
        }

        resources = var.resources
      }

      readReplicas = {
        replicaCount = var.high_availability.enabled ? var.high_availability.replicas - 1 : 0
      }

      metrics = {
        enabled = true
      }
    })
  ]

  depends_on = [kubernetes_namespace.database]
}

# Secret para aplicaciones
resource "kubernetes_secret" "app_credentials" {
  metadata {
    name      = "app-credentials"
    namespace = kubernetes_namespace.database.metadata[0].name
  }

  type = "Opaque"

  data = {
    postgres-password = base64encode(random_password.postgres_password.result)
    zitadel-user      = base64encode("zitadel")
    zitadel-password  = base64encode(random_password.zitadel_password.result)
    grafana-user      = base64encode("grafana")
    grafana-password  = base64encode(random_password.grafana_password.result)
  }
}

# Outputs del módulo
output "namespace" {
  description = "Namespace de PostgreSQL"
  value       = kubernetes_namespace.database.metadata[0].name
}

output "service_name" {
  description = "Nombre del servicio de PostgreSQL"
  value       = "postgresql"
}

output "endpoint" {
  description = "Endpoint de PostgreSQL"
  value       = "postgresql.${kubernetes_namespace.database.metadata[0].name}.svc.cluster.local:5432"
}

output "database_name" {
  description = "Nombre de la base de datos"
  value       = var.postgres_config.database
}

output "credentials_secret" {
  description = "Secret con credenciales"
  value       = kubernetes_secret.app_credentials.metadata[0].name
}

output "ready" {
  description = "Estado de preparación de PostgreSQL"
  value       = helm_release.postgresql.status == "deployed"
} 