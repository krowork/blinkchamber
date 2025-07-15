# terraform/phases/03-secrets/main.tf
# Fase 3: Configuración de Secretos en Vault

terraform {
  required_version = ">= 1.5.0"

  # Backend local para desarrollo
  backend "local" {
    path = "../terraform-secrets.tfstate"
  }

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.21.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
  }
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
  default     = "development"
}

variable "vault_address" {
  description = "Dirección de Vault"
  type        = string
  default     = "http://localhost:8201"
}

# Datos de la fase anterior
data "terraform_remote_state" "vault_init" {
  backend = "local"
  config = {
    path = "../terraform-vault-init.tfstate"
  }
}

# Configurar provider de Vault
provider "vault" {
  address = var.vault_address
  # El token se obtiene de la variable de entorno VAULT_TOKEN
}

# Configurar provider de Kubernetes
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "kind-${var.cluster_name}"
}

# Configuración de autenticación de Kubernetes en Vault
resource "vault_auth_backend" "kubernetes" {
  type        = "kubernetes"
  description = "Kubernetes auth backend"
}

# Configurar el auth backend de Kubernetes
resource "vault_kubernetes_auth_backend_config" "k8s_config" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = "https://kubernetes.default.svc.cluster.local:443"
  disable_iss_validation = true
  disable_local_ca_jwt   = false

  depends_on = [vault_auth_backend.kubernetes]
}

# Nota: La configuración de autenticación de Kubernetes se completará
# automáticamente usando el service account token del pod de Vault

# Configuración local
locals {
  # Configuración de secretos por componente
  database_secrets = {
    postgres = {
      username = "postgres"
      password = random_password.postgres_password.result
      database = "postgres"
      host     = "postgres.database.svc.cluster.local"
      port     = "5432"
    }
  }

  identity_secrets = {
    zitadel = {
      database_username = "zitadel"
      database_password = random_password.zitadel_db_password.result
      database_name     = "zitadel"
      admin_username    = "zitadel-admin"
      admin_password    = random_password.zitadel_admin_password.result
      jwt_secret        = random_password.zitadel_jwt_secret.result
      masterkey         = random_password.zitadel_masterkey.result
    }
  }

  storage_secrets = {
    minio = {
      access_key  = "minioadmin"
      secret_key  = random_password.minio_secret_key.result
      bucket_name = "blinkchamber-storage"
      region      = "us-east-1"
    }
  }

  monitoring_secrets = {
    grafana = {
      admin_username = "admin"
      admin_password = random_password.grafana_admin_password.result
    }
  }

  # (Eliminar todos los bloques de Postfix/Dovecot)
}

# Generación de contraseñas seguras
resource "random_password" "postgres_password" {
  length  = 32
  special = true
}

resource "random_password" "zitadel_db_password" {
  length  = 32
  special = true
}

resource "random_password" "zitadel_admin_password" {
  length  = 16
  special = true
}

resource "random_password" "zitadel_jwt_secret" {
  length  = 64
  special = true
}

resource "random_password" "zitadel_masterkey" {
  length  = 32
  special = true
}

resource "random_password" "minio_secret_key" {
  length  = 32
  special = true
}

resource "random_password" "grafana_admin_password" {
  length  = 16
  special = true
}

# Habilitar KV secrets engine v2 si no está habilitado
resource "vault_mount" "kv_v2" {
  path        = "secret"
  type        = "kv-v2"
  description = "KV Version 2 secret engine mount"

  options = {
    version = "2"
  }
}

# Secretos de base de datos
resource "vault_kv_secret_v2" "database_postgres" {
  mount               = vault_mount.kv_v2.path
  name                = "database/postgres"
  cas                 = 1
  delete_all_versions = true

  data_json = jsonencode(local.database_secrets.postgres)
}

resource "vault_kv_secret_v2" "database_zitadel" {
  mount               = vault_mount.kv_v2.path
  name                = "database/zitadel"
  cas                 = 1
  delete_all_versions = true

  data_json = jsonencode({
    username = local.identity_secrets.zitadel.database_username
    password = local.identity_secrets.zitadel.database_password
    database = local.identity_secrets.zitadel.database_name
    host     = local.database_secrets.postgres.host
    port     = local.database_secrets.postgres.port
  })
}

# Secretos de identidad (Zitadel)
resource "vault_kv_secret_v2" "identity_zitadel" {
  mount               = vault_mount.kv_v2.path
  name                = "identity/zitadel"
  cas                 = 1
  delete_all_versions = true

  data_json = jsonencode({
    admin_username = local.identity_secrets.zitadel.admin_username
    admin_password = local.identity_secrets.zitadel.admin_password
    jwt_secret     = local.identity_secrets.zitadel.jwt_secret
    masterkey      = local.identity_secrets.zitadel.masterkey
  })
}

# Secretos de almacenamiento (MinIO)
resource "vault_kv_secret_v2" "storage_minio" {
  mount               = vault_mount.kv_v2.path
  name                = "storage/minio"
  cas                 = 1
  delete_all_versions = true

  data_json = jsonencode(local.storage_secrets.minio)
}

# Secretos de monitoreo (Grafana)
resource "vault_kv_secret_v2" "monitoring_grafana" {
  mount               = vault_mount.kv_v2.path
  name                = "monitoring/grafana"
  cas                 = 1
  delete_all_versions = true

  data_json = jsonencode(local.monitoring_secrets.grafana)
}

module "vault_policies" {
  source = "../../modules/vault-policies"
}

# Configurar audit logging
resource "vault_audit" "file_audit" {
  type = "file"

  options = {
    file_path = "/vault/audit/audit.log"
  }
}

# Configurar telemetría para Prometheus
resource "vault_mount" "sys_metrics" {
  path        = "sys/metrics"
  type        = "system"
  description = "System backend for metrics"
}

# Namespace y ServiceAccount para Vault CSI driver
resource "kubernetes_namespace" "vault_csi" {
  metadata {
    name = "vault-csi"
    labels = {
      "blinkchamber.io/component" = "vault-csi"
      "blinkchamber.io/phase"     = "3"
    }
  }
}

resource "kubernetes_service_account" "vault_csi_driver" {
  metadata {
    name      = "vault-csi-driver"
    namespace = kubernetes_namespace.vault_csi.metadata[0].name
  }
}

# ClusterRole para CSI driver
resource "kubernetes_cluster_role" "vault_csi_driver" {
  metadata {
    name = "vault-csi-driver"
  }

  rule {
    api_groups = [""]
    resources  = ["serviceaccounts/token"]
    verbs      = ["create"]
  }
}

resource "kubernetes_cluster_role_binding" "vault_csi_driver" {
  metadata {
    name = "vault-csi-driver"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.vault_csi_driver.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.vault_csi_driver.metadata[0].name
    namespace = kubernetes_namespace.vault_csi.metadata[0].name
  }
}

# Role para CSI driver en Vault
resource "vault_kubernetes_auth_backend_role" "vault_csi_driver_role" {
  backend                          = "kubernetes"
  role_name                        = "vault-csi-driver"
  bound_service_account_names      = ["vault-csi-driver"]
  bound_service_account_namespaces = ["vault-csi"]
  token_ttl                        = 86400
  token_policies                   = ["vault-csi-policy"]
}

# Política para CSI driver
resource "vault_policy" "vault_csi_policy" {
  name = "vault-csi-policy"

  policy = <<EOT
# Política para Vault CSI driver
path "secret/data/*" {
  capabilities = ["read"]
}

path "secret/metadata/*" {
  capabilities = ["read", "list"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "sys/capabilities-self" {
  capabilities = ["update"]
}
EOT
}

# Outputs de la fase 3
output "phase3_status" {
  description = "Estado de la fase 3 - Configuración de secretos"
  value = {
    kv_engine_path = vault_mount.kv_v2.path
    secrets_created = {
      database   = [vault_kv_secret_v2.database_postgres.name, vault_kv_secret_v2.database_zitadel.name]
      identity   = [vault_kv_secret_v2.identity_zitadel.name]
      storage    = [vault_kv_secret_v2.storage_minio.name]
      monitoring = [vault_kv_secret_v2.monitoring_grafana.name]
    }
    policies_created = [
      vault_policy.database_policy.name,
      vault_policy.identity_policy.name,
      vault_policy.storage_policy.name,
      vault_policy.monitoring_policy.name,
      vault_policy.vault_csi_policy.name
    ]
    k8s_roles_created = [
      vault_kubernetes_auth_backend_role.database_role.role_name,
      vault_kubernetes_auth_backend_role.identity_role.role_name,
      vault_kubernetes_auth_backend_role.storage_role.role_name,
      vault_kubernetes_auth_backend_role.monitoring_role.role_name,
      vault_kubernetes_auth_backend_role.vault_csi_driver_role.role_name
    ]
    audit_enabled  = true
    csi_configured = true
  }
}

output "secrets_summary" {
  description = "Resumen de secretos configurados"
  value = {
    database = {
      postgres_path = vault_kv_secret_v2.database_postgres.path
      zitadel_path  = vault_kv_secret_v2.database_zitadel.path
    }
    identity = {
      zitadel_path = vault_kv_secret_v2.identity_zitadel.path
    }
    storage = {
      minio_path = vault_kv_secret_v2.storage_minio.path
    }
    monitoring = {
      grafana_path = vault_kv_secret_v2.monitoring_grafana.path
    }
  }
  sensitive = false
}

output "next_phase" {
  description = "Información para la siguiente fase"
  value = {
    phase             = 4
    description       = "Application Deployment with Vault Integration"
    vault_ready       = true
    secrets_ready     = true
    prerequisites_met = true
  }
} 