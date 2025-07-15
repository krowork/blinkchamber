# modules/cert-manager/main.tf - Módulo especializado para cert-manager

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
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.5"
    }
  }
}

# Variables del módulo
variable "namespace" {
  description = "Namespace para cert-manager"
  type        = string
  default     = "cert-manager"
}

variable "chart_version" {
  description = "Versión del chart de cert-manager"
  type        = string
  default     = "v1.13.3"
}

variable "install_crds" {
  description = "Instalar CRDs automáticamente"
  type        = bool
  default     = true
}

variable "ca_config" {
  description = "Configuración de la CA"
  type = object({
    common_name  = string
    organization = string
    country      = string
  })
  default = {
    common_name  = "blinkchamber CA"
    organization = "blinkchamber"
    country      = "ES"
  }
}

variable "resources" {
  description = "Recursos para cert-manager"
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
      cpu    = "10m"
      memory = "32Mi"
    }
    limits = {
      cpu    = "100m"
      memory = "128Mi"
    }
  }
}

# Namespace para cert-manager
resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "cert-manager"
      "app.kubernetes.io/instance"  = "cert-manager"
      "app.kubernetes.io/component" = "controller"
    }
  }
}

# cert-manager Helm Release
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name
  version    = var.chart_version

  set {
    name  = "installCRDs"
    value = var.install_crds
  }

  set {
    name  = "global.leaderElection.namespace"
    value = kubernetes_namespace.cert_manager.metadata[0].name
  }

  values = [
    yamlencode({
      resources = var.resources

      webhook = {
        resources = var.resources
      }

      cainjector = {
        resources = var.resources
      }
    })
  ]

  depends_on = [kubernetes_namespace.cert_manager]
}

# Crear CA privada para certificados
resource "tls_private_key" "ca_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "ca_cert" {
  private_key_pem = tls_private_key.ca_key.private_key_pem

  subject {
    common_name  = var.ca_config.common_name
    organization = var.ca_config.organization
    country      = var.ca_config.country
  }

  validity_period_hours = 8760 # 1 año
  is_ca_certificate     = true

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "crl_signing",
  ]
}

# Secret para la CA
resource "kubernetes_secret" "ca_key_pair" {
  metadata {
    name      = "ca-key-pair"
    namespace = kubernetes_namespace.cert_manager.metadata[0].name
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = tls_self_signed_cert.ca_cert.cert_pem
    "tls.key" = tls_private_key.ca_key.private_key_pem
  }

  depends_on = [helm_release.cert_manager]
}

# Esperar a que cert-manager esté listo
resource "null_resource" "wait_for_cert_manager" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Esperando cert-manager..."
      kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=cert-manager -n ${kubernetes_namespace.cert_manager.metadata[0].name} --timeout=300s
      kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=webhook -n ${kubernetes_namespace.cert_manager.metadata[0].name} --timeout=300s
      kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=cainjector -n ${kubernetes_namespace.cert_manager.metadata[0].name} --timeout=300s
    EOT
  }

  depends_on = [helm_release.cert_manager]
}

# ClusterIssuer para certificados internos
resource "null_resource" "create_cluster_issuer" {
  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: ca-key-pair
EOF
    EOT
  }

  depends_on = [
    null_resource.wait_for_cert_manager,
    kubernetes_secret.ca_key_pair
  ]
}

# Outputs del módulo
output "namespace" {
  description = "Namespace de cert-manager"
  value       = kubernetes_namespace.cert_manager.metadata[0].name
}

output "ca_cluster_issuer_name" {
  description = "Nombre del ClusterIssuer de CA"
  value       = "ca-issuer"
}

output "ca_secret_name" {
  description = "Nombre del secret de la CA"
  value       = kubernetes_secret.ca_key_pair.metadata[0].name
}

output "ready" {
  description = "Estado de preparación de cert-manager"
  value       = helm_release.cert_manager.status == "deployed"
}

output "ca_cert_pem" {
  description = "Certificado de la CA en formato PEM"
  value       = tls_self_signed_cert.ca_cert.cert_pem
  sensitive   = true
} 