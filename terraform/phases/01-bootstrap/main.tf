# terraform/phases/01-bootstrap/main.tf
# Fase 1: Bootstrap Básico - Infraestructura sin secretos

terraform {
  required_version = ">= 1.5.0"

  # Backend local para desarrollo
  backend "local" {
    path = "../terraform-bootstrap.tfstate"
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
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.5"
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

# Variables principales
variable "cluster_name" {
  description = "Nombre del cluster"
  type        = string
  default     = "blinkchamber"
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  default     = "local"
}

variable "tls_enabled" {
  description = "Habilitar TLS entre componentes"
  type        = bool
  default     = false
}

# Datos locales para configuración
locals {
  # Configuración de dominios
  domains = {
    base    = "blinkchamber.local"
    vault   = "vault.blinkchamber.local"
    grafana = "grafana.blinkchamber.local"
    zitadel = "zitadel.blinkchamber.local"
    minio   = "minio.blinkchamber.local"
  }

  # Configuración de recursos por defecto
  default_resources = {
    small = {
      requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
      limits = {
        cpu    = "500m"
        memory = "512Mi"
      }
    }
    medium = {
      requests = {
        cpu    = "250m"
        memory = "256Mi"
      }
      limits = {
        cpu    = "1000m"
        memory = "1Gi"
      }
    }
  }
}

# Módulo base de Kubernetes
module "kubernetes_base" {
  source = "../../modules/kubernetes-base"

  cluster_name       = var.cluster_name
  kubeconfig_path    = "~/.kube/config"
  kubeconfig_context = "kind-${var.cluster_name}"
}

# Módulo de Ingress Controller
module "ingress" {
  source = "../../modules/ingress"

  namespace     = "ingress-nginx"
  chart_version = "4.8.3"

  node_ports = {
    http  = 30080
    https = 30443
  }

  resources      = local.default_resources.small
  enable_metrics = true

  depends_on = [module.kubernetes_base]
}

# Módulo de cert-manager
module "cert_manager" {
  source = "../../modules/cert-manager"

  namespace     = "cert-manager"
  chart_version = "v1.13.3"
  install_crds  = true

  ca_config = {
    common_name  = "blinkchamber CA"
    organization = "blinkchamber"
    country      = "ES"
  }

  resources = {
    requests = {
      cpu    = "10m"
      memory = "32Mi"
    }
    limits = {
      cpu    = "100m"
      memory = "128Mi"
    }
  }

  depends_on = [module.ingress]
}

# Módulo de Vault Bootstrap (solo infraestructura)
resource "kubernetes_service_account" "vault" {
  metadata {
    name      = "vault"
    namespace = "vault"
  }
}

module "vault_bootstrap" {
  source = "../../modules/vault-bootstrap"

  namespace     = "vault"
  chart_version = "0.26.1"

  vault_image = {
    repository = "hashicorp/vault"
    tag        = "1.15.2"
  }

  # Solo infraestructura, no inicialización
  deploy_only_infrastructure = true
  auto_init                  = false

  tls_enabled  = var.tls_enabled
  storage_size = "10Gi"

  high_availability = {
    enabled  = false
    replicas = 1
  }

  ingress_config = {
    enabled     = true
    host        = local.domains.vault
    tls_enabled = true
    annotations = {
      "kubernetes.io/ingress.class"                  = "nginx"
      "cert-manager.io/cluster-issuer"               = "ca-issuer"
      "nginx.ingress.kubernetes.io/ssl-redirect"     = "true"
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTP"
    }
  }

  resources = {
    server = local.default_resources.medium
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

  service_account = kubernetes_service_account.vault.metadata[0].name

  depends_on = [module.cert_manager]
}

# Outputs de la fase 1
output "phase1_status" {
  description = "Estado de la fase 1 - Bootstrap básico"
  value = {
    cluster_name = var.cluster_name
    environment  = var.environment
    components = {
      kubernetes_base = {
        ready = true
      }
      ingress = {
        namespace = module.ingress.namespace
        ready     = module.ingress.ready
      }
      cert_manager = {
        namespace         = module.cert_manager.namespace
        ca_cluster_issuer = module.cert_manager.ca_cluster_issuer_name
        ready             = module.cert_manager.ready
      }
      vault_infrastructure = {
        namespace = module.vault_bootstrap.namespace
        endpoint  = module.vault_bootstrap.endpoint
        ready     = module.vault_bootstrap.infrastructure_ready
      }
    }
  }
}

output "next_phase" {
  description = "Información para la siguiente fase"
  value = {
    phase             = 2
    description       = "Vault Initialization"
    vault_endpoint    = module.vault_bootstrap.endpoint
    vault_namespace   = module.vault_bootstrap.namespace
    prerequisites_met = true
  }
} 