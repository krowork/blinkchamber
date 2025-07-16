terraform {
  required_version = ">= 1.5.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
  }
}

variable "namespace" {
  description = "Namespace to deploy the operator into"
  type        = string
  default     = "cnpg-system"
}

resource "kubernetes_namespace" "cnpg_system" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "cnpg" {
  name       = "cnpg"
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "cnpg"
  namespace  = kubernetes_namespace.cnpg_system.metadata[0].name
  version    = "0.18.0" # Use a specific version for stability
}

output "namespace" {
  value = kubernetes_namespace.cnpg_system.metadata[0].name
}

output "ready" {
  value = helm_release.cnpg.status == "deployed"
}
