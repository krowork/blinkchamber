# terraform/modules/vault-bootstrap/outputs.tf
# Outputs del módulo vault-bootstrap

output "namespace" {
  description = "Namespace de Vault"
  value       = kubernetes_namespace.vault.metadata[0].name
}

output "service_name" {
  description = "Nombre del servicio de Vault"
  value       = "vault"
}

output "endpoint" {
  description = "Endpoint interno de Vault"
  value       = var.tls_enabled ? "https://vault.${var.namespace}.svc.cluster.local:8200" : "http://vault.${var.namespace}.svc.cluster.local:8200"
}

output "external_endpoint" {
  description = "Endpoint externo de Vault (ingress)"
  value       = var.ingress_config.enabled ? (var.ingress_config.tls_enabled ? "https://${var.ingress_config.host}" : "http://${var.ingress_config.host}") : null
}

output "infrastructure_ready" {
  description = "Estado de preparación de la infraestructura de Vault"
  value       = helm_release.vault.status == "deployed"
}

output "deployment_mode" {
  description = "Modo de despliegue de Vault"
  value = {
    infrastructure_only = var.deploy_only_infrastructure
    auto_init           = var.auto_init
    auto_unseal         = var.auto_unseal.enabled
    high_availability   = var.high_availability.enabled
  }
}

output "vault_config" {
  description = "Configuración de Vault"
  value = {
    image = {
      repository = var.vault_image.repository
      tag        = var.vault_image.tag
    }
    chart_version = var.chart_version
    tls_enabled   = var.tls_enabled
    storage_size  = var.storage_size
    replicas      = var.high_availability.enabled ? var.high_availability.replicas : 1
  }
  sensitive = false
}

output "service_account" {
  description = "ServiceAccount de Vault"
  value       = "vault"
}

output "ingress_host" {
  description = "Host de ingress para Vault"
  value       = var.ingress_config.enabled ? var.ingress_config.host : null
}

output "cluster_role" {
  description = "ClusterRole de Vault"
  value       = kubernetes_cluster_role.vault.metadata[0].name
}

output "network_policy" {
  description = "NetworkPolicy de Vault"
  value       = kubernetes_network_policy.vault_network_policy.metadata[0].name
}

output "auto_unseal_config" {
  description = "Configuración de auto-unseal"
  value = {
    enabled = var.auto_unseal.enabled
    method  = var.auto_unseal.method
    # No exponemos la configuración sensible
  }
  sensitive = false
}

output "ports" {
  description = "Puertos de Vault"
  value = {
    api     = 8200
    cluster = 8201
    ui      = 8200
  }
}

output "labels" {
  description = "Labels aplicadas a los recursos"
  value = {
    "app.kubernetes.io/name"      = "vault"
    "app.kubernetes.io/instance"  = "vault"
    "app.kubernetes.io/component" = "server"
    "blinkchamber.io/phase"       = var.deploy_only_infrastructure ? "1" : "2"
    "blinkchamber.io/managed-by"  = "terraform"
  }
}

output "health_checks" {
  description = "Endpoints de health checks"
  value = {
    readiness = "/v1/sys/health?standbyok=true&sealedcode=204&uninitcode=204"
    liveness  = "/v1/sys/health?standbyok=true"
    ui        = "/ui/"
  }
}

output "phase_info" {
  description = "Información de la fase actual"
  value = {
    current_phase = var.deploy_only_infrastructure ? 1 : 2
    phase_name    = var.deploy_only_infrastructure ? "Bootstrap Infrastructure" : "Vault Initialization"
    next_phase    = var.deploy_only_infrastructure ? 2 : 3
    can_proceed   = helm_release.vault.status == "deployed"
  }
} 