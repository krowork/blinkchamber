variable "environment" {
  description = "Entorno de despliegue (dev, test, prod, local)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod", "local"], var.environment)
    error_message = "El entorno debe ser: dev, test, prod, o local."
  }
}

variable "enable_public_access" {
  description = "Habilitar acceso público a servicios (solo dev/test)"
  type        = bool
  default     = true
}

variable "enable_port_forward" {
  description = "Habilitar port-forward para servicios internos"
  type        = bool
  default     = true
}

variable "zitadel_always_public" {
  description = "Zitadel siempre público (independiente del entorno)"
  type        = bool
  default     = true
}

variable "grafana_public_access" {
  description = "Habilitar acceso público a Grafana"
  type        = bool
  default     = true
}

variable "vault_public_access" {
  description = "Habilitar acceso público a Vault (solo dev/test)"
  type        = bool
  default     = false
}

locals {
  # Configuración de acceso basada en entorno
  access_config = {
    dev = {
      enable_public_access = true
      enable_port_forward  = true
      grafana_public       = true
      vault_public         = false
    }
    test = {
      enable_public_access = true
      enable_port_forward  = true
      grafana_public       = true
      vault_public         = false
    }
    prod = {
      enable_public_access = false
      enable_port_forward  = false
      grafana_public       = false
      vault_public         = false
    }
    local = {
      enable_public_access = true
      enable_port_forward  = true
      grafana_public       = true
      vault_public         = false
    }
  }

  # Configuración actual basada en entorno
  current_access = local.access_config[var.environment]

  # Zitadel siempre público
  zitadel_public = var.zitadel_always_public

  # Grafana público solo si está habilitado y no es producción
  grafana_public = var.grafana_public_access && local.current_access.grafana_public

  # Vault público solo en desarrollo/testing
  vault_public = var.vault_public_access && local.current_access.vault_public
}

variable "enable_optional_components" {
  description = "Habilitar componentes opcionales (MinIO, etc.)"
  type        = bool
  default     = true
}

variable "tls_enabled" {
  description = "Habilitar TLS entre componentes"
  type        = bool
  default     = false
} 