# terraform/modules/vault-bootstrap/variables.tf
# Variables para el módulo vault-bootstrap

variable "namespace" {
  description = "Namespace para Vault"
  type        = string
  default     = "vault"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.namespace))
    error_message = "El namespace debe contener solo letras minúsculas, números y guiones."
  }
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

variable "deploy_only_infrastructure" {
  description = "Solo desplegar infraestructura sin inicialización automática"
  type        = bool
  default     = false
}

variable "auto_init" {
  description = "Habilitar inicialización automática de Vault"
  type        = bool
  default     = false
}

variable "auto_unseal" {
  description = "Configuración de auto-unseal"
  type = object({
    enabled = bool
    method  = string
    config  = map(string)
  })
  default = {
    enabled = false
    method  = "shamir"
    config  = {}
  }
  validation {
    condition     = contains(["shamir", "awskms", "azurekeyvault", "transit", "gcpckms"], var.auto_unseal.method)
    error_message = "El método de auto-unseal debe ser uno de: shamir, awskms, azurekeyvault, transit, gcpckms."
  }
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  default     = "development"
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "El entorno debe ser development, staging o production."
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
  validation {
    condition     = can(regex("^[0-9]+[GMK]i?$", var.storage_size))
    error_message = "El tamaño de almacenamiento debe tener formato válido (ej: 10Gi, 1024Mi)."
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
  validation {
    condition     = var.high_availability.replicas >= 1 && var.high_availability.replicas <= 7
    error_message = "El número de réplicas debe estar entre 1 y 7."
  }
}

variable "backup_config" {
  description = "Configuración de backup automático"
  type = object({
    enabled   = bool
    schedule  = string
    retention = string
    storage = object({
      type   = string
      bucket = string
      path   = string
    })
  })
  default = {
    enabled   = false
    schedule  = "0 2 * * *"
    retention = "30d"
    storage = {
      type   = "s3"
      bucket = ""
      path   = "vault-backups"
    }
  }
}

variable "monitoring" {
  description = "Configuración de monitoreo"
  type = object({
    enabled           = bool
    metrics_enabled   = bool
    audit_enabled     = bool
    telemetry_enabled = bool
  })
  default = {
    enabled           = true
    metrics_enabled   = true
    audit_enabled     = true
    telemetry_enabled = true
  }
}

variable "security" {
  description = "Configuración de seguridad"
  type = object({
    network_policies = bool
    pod_security     = bool
    rbac_enabled     = bool
  })
  default = {
    network_policies = true
    pod_security     = true
    rbac_enabled     = true
  }
} 