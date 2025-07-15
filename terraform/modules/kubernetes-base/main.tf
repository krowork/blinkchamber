# modules/kubernetes-base/main.tf - Configuración base de providers Kubernetes

terraform {
  required_version = ">= 1.5.0"

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

# Variables del módulo
variable "cluster_name" {
  description = "Nombre del cluster"
  type        = string
  default     = "blinkchamber"
}

variable "kubeconfig_path" {
  description = "Ruta al archivo kubeconfig"
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "Contexto de kubeconfig"
  type        = string
  default     = null
}

# Configuración de proveedores
provider "kubernetes" {
  config_path    = pathexpand(var.kubeconfig_path)
  config_context = var.kubeconfig_context != null ? var.kubeconfig_context : "kind-${var.cluster_name}"
}

provider "helm" {
  kubernetes {
    config_path    = pathexpand(var.kubeconfig_path)
    config_context = var.kubeconfig_context != null ? var.kubeconfig_context : "kind-${var.cluster_name}"
  }
}

provider "kubectl" {
  config_path    = pathexpand(var.kubeconfig_path)
  config_context = var.kubeconfig_context != null ? var.kubeconfig_context : "kind-${var.cluster_name}"
}

# Outputs para otros módulos
output "cluster_info" {
  description = "Información del cluster"
  value = {
    name    = var.cluster_name
    context = var.kubeconfig_context != null ? var.kubeconfig_context : "kind-${var.cluster_name}"
    config  = var.kubeconfig_path
  }
} 