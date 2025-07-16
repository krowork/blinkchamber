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
  description = "Namespace to deploy Consul into"
  type        = string
  default     = "consul"
}

resource "kubernetes_namespace" "consul" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "consul" {
  name       = "consul"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "consul"
  namespace  = kubernetes_namespace.consul.metadata[0].name
  version    = "0.48.0" # Use a specific version for stability

  values = [
    <<-EOT
    global:
      name: consul
    server:
      replicas: 3
      bootstrapExpect: 3
    ui:
      enabled: true
    EOT
  ]
}

output "namespace" {
  value = kubernetes_namespace.consul.metadata[0].name
}

output "ready" {
  value = helm_release.consul.status == "deployed"
}
