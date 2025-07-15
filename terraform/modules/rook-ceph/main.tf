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
  }
}

variable "namespace" {
  description = "Namespace to deploy Rook/Ceph into"
  type        = string
  default     = "rook-ceph"
}

resource "kubernetes_namespace" "rook_ceph" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "rook_ceph" {
  name       = "rook-ceph"
  repository = "https://charts.rook.io/release"
  chart      = "rook-ceph"
  namespace  = kubernetes_namespace.rook_ceph.metadata[0].name
  version    = "v1.11.7" # Use a specific version for stability

  values = [
    <<-EOT
    crds.enabled: true
    EOT
  ]
}

resource "helm_release" "rook_ceph_cluster" {
  name       = "rook-ceph-cluster"
  repository = "https://charts.rook.io/release"
  chart      = "rook-ceph-cluster"
  namespace  = kubernetes_namespace.rook_ceph.metadata[0].name
  version    = "v1.11.7"

  values = [
    <<-EOT
    cephClusterSpec:
      storage:
        useAllNodes: true
        useAllDevices: true
    EOT
  ]

  depends_on = [helm_release.rook_ceph]
}

output "namespace" {
  value = kubernetes_namespace.rook_ceph.metadata[0].name
}

output "ready" {
  value = helm_release.rook_ceph_cluster.status == "deployed"
}
