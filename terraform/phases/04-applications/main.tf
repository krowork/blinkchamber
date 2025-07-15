# terraform/phases/04-applications/main-simple.tf
# Versión simplificada sin PVCs persistentes

terraform {
  required_version = ">= 1.5.0"

  backend "local" {
    path = "../terraform-applications.tfstate"
  }

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.21.0"
    }
  }
}

variable "cluster_name" {
  description = "Nombre del cluster"
  type        = string
  default     = "blinkchamber"
}



variable "vault_address" {
  description = "Dirección de Vault"
  type        = string
  default     = "http://localhost:8201"
}

# Configurar providers
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "kind-${var.cluster_name}"
}

provider "vault" {
  address = var.vault_address
}

locals {
  domains = {
    base    = "blinkchamber.local"
    grafana = "grafana.blinkchamber.local"
    zitadel = "zitadel.blinkchamber.local"
    minio   = "minio.blinkchamber.local"
    mailu   = "mailu.blinkchamber.local"
  }
}

# Namespace para Base de Datos
resource "kubernetes_namespace" "database" {
  metadata {
    name = "database"
    labels = {
      "blinkchamber.io/component" = "database"
      "blinkchamber.io/phase"     = "4"
    }
  }
}

# ServiceAccount para PostgreSQL
resource "kubernetes_service_account" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.database.metadata[0].name
    annotations = {
      "vault.hashicorp.com/agent-inject" = "true"
      "vault.hashicorp.com/role"         = "database-role"
    }
  }
}

# PostgreSQL con volumen emptyDir
resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.database.metadata[0].name
    labels = {
      app = "postgres"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
        annotations = {
          "vault.hashicorp.com/agent-inject"                   = "true"
          "vault.hashicorp.com/role"                           = "database-role"
          "vault.hashicorp.com/agent-inject-secret-postgres"   = "secret/data/database/postgres"
          "vault.hashicorp.com/agent-inject-template-postgres" = <<-EOT
            {{- with secret "secret/data/database/postgres" -}}
            POSTGRES_USER={{ .Data.data.username }}
            POSTGRES_PASSWORD={{ .Data.data.password }}
            POSTGRES_DB={{ .Data.data.database }}
            {{- end }}
          EOT
        }
      }

      spec {
        service_account_name = kubernetes_service_account.postgres.metadata[0].name

        container {
          name  = "postgres"
          image = "postgres:15"

          command = ["/bin/bash", "-c"]
          args = [
            <<-EOT
              # Esperar a que Vault agent inyecte secretos
              while [ ! -f /vault/secrets/postgres ]; do
                echo "Esperando secretos de Vault..."
                sleep 5
              done
              
              # Cargar variables de entorno desde Vault
              export $(cat /vault/secrets/postgres | xargs)
              
              # Imprimir configuración para debugging
              echo "Configuración de PostgreSQL:"
              echo "POSTGRES_USER: $POSTGRES_USER"
              echo "POSTGRES_DB: $POSTGRES_DB"
              echo "POSTGRES_PASSWORD está configurado: $([ -n "$POSTGRES_PASSWORD" ] && echo 'Sí' || echo 'No')"
              
              # Inicializar PostgreSQL
              docker-entrypoint.sh postgres
            EOT
          ]

          port {
            container_port = 5432
            name           = "postgres"
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "1000m"
              memory = "1Gi"
            }
          }

          volume_mount {
            name       = "postgres-data"
            mount_path = "/var/lib/postgresql/data"
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", "postgres"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", "postgres"]
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        # Usar emptyDir en lugar de PVC
        volume {
          name = "postgres-data"
          empty_dir {
            size_limit = "10Gi"
          }
        }
      }
    }
  }
}

# Servicio para PostgreSQL
resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.database.metadata[0].name
  }

  spec {
    selector = {
      app = "postgres"
    }

    port {
      port        = 5432
      target_port = 5432
      name        = "postgres"
    }
  }
}

# Namespace para Monitoring
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "blinkchamber.io/component" = "monitoring"
      "blinkchamber.io/phase"     = "4"
    }
  }
}

# ServiceAccount para Grafana
resource "kubernetes_service_account" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "vault.hashicorp.com/agent-inject" = "true"
      "vault.hashicorp.com/role"         = "monitoring-role"
    }
  }
}

# Grafana con volumen emptyDir
resource "kubernetes_deployment" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      app = "grafana"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "grafana"
      }
    }

    template {
      metadata {
        labels = {
          app = "grafana"
        }
        annotations = {
          "vault.hashicorp.com/agent-inject"                  = "true"
          "vault.hashicorp.com/role"                          = "monitoring-role"
          "vault.hashicorp.com/agent-inject-secret-grafana"   = "secret/data/monitoring/grafana"
          "vault.hashicorp.com/agent-inject-template-grafana" = <<-EOT
            {{- with secret "secret/data/monitoring/grafana" -}}
            GF_SECURITY_ADMIN_USER={{ .Data.data.admin_username }}
            GF_SECURITY_ADMIN_PASSWORD={{ .Data.data.admin_password }}
            {{- end }}
          EOT
        }
      }

      spec {
        service_account_name = kubernetes_service_account.grafana.metadata[0].name

        container {
          name  = "grafana"
          image = "grafana/grafana:10.2.2"

          command = ["/bin/bash", "-c"]
          args = [
            <<-EOT
              # Esperar a que Vault agent inyecte secretos
              while [ ! -f /vault/secrets/grafana ]; do
                echo "Esperando secretos de Vault..."
                sleep 5
              done
              
              # Cargar variables de entorno desde Vault
              source /vault/secrets/grafana
              
              # Inicializar Grafana
              /run.sh
            EOT
          ]

          port {
            container_port = 3000
            name           = "http"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          volume_mount {
            name       = "grafana-data"
            mount_path = "/var/lib/grafana"
          }

          liveness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        # Usar emptyDir en lugar de PVC
        volume {
          name = "grafana-data"
          empty_dir {
            size_limit = "5Gi"
          }
        }
      }
    }
  }
}

# Servicio para Grafana
resource "kubernetes_service" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    selector = {
      app = "grafana"
    }

    port {
      port        = 3000
      target_port = 3000
      name        = "http"
    }
  }
}

# Ingress para Grafana (condicional)
resource "kubernetes_ingress_v1" "grafana" {
  count = local.grafana_public ? 1 : 0

  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                  = "nginx"
      "cert-manager.io/cluster-issuer"               = "ca-issuer"
      "nginx.ingress.kubernetes.io/ssl-redirect"     = "true"
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTP"
    }
  }

  spec {
    tls {
      hosts       = [local.domains.grafana]
      secret_name = "grafana-tls"
    }

    rule {
      host = local.domains.grafana
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.grafana.metadata[0].name
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }
}

# Namespace para Identity (Zitadel)
resource "kubernetes_namespace" "identity" {
  metadata {
    name = "identity"
    labels = {
      "blinkchamber.io/component" = "identity"
      "blinkchamber.io/phase"     = "4"
    }
  }
}

# ServiceAccount para Zitadel
resource "kubernetes_service_account" "zitadel" {
  metadata {
    name      = "zitadel"
    namespace = kubernetes_namespace.identity.metadata[0].name
    annotations = {
      "vault.hashicorp.com/agent-inject" = "true"
      "vault.hashicorp.com/role"         = "identity-role"
    }
  }
}

# Zitadel Deployment
resource "kubernetes_deployment" "zitadel" {
  metadata {
    name      = "zitadel"
    namespace = kubernetes_namespace.identity.metadata[0].name
    labels = {
      app = "zitadel"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "zitadel"
      }
    }

    template {
      metadata {
        labels = {
          app = "zitadel"
        }
        annotations = {
          "vault.hashicorp.com/agent-inject"                   = "true"
          "vault.hashicorp.com/role"                           = "identity-role"
          "vault.hashicorp.com/agent-inject-secret-zitadel"    = "secret/data/identity/zitadel"
          "vault.hashicorp.com/agent-inject-secret-database"   = "secret/data/database/postgres"
          "vault.hashicorp.com/agent-inject-template-zitadel"  = <<-EOT
            {{- with secret "secret/data/identity/zitadel" -}}
            ZITADEL_MASTERKEY={{ .Data.data.masterkey }}
            ZITADEL_ADMIN_USERNAME={{ .Data.data.admin_username }}
            ZITADEL_ADMIN_PASSWORD={{ .Data.data.admin_password }}
            {{- end }}
          EOT
          "vault.hashicorp.com/agent-inject-template-database" = <<-EOT
            {{- with secret "secret/data/database/postgres" -}}
            ZITADEL_DATABASE_POSTGRES_HOST=postgres.database.svc.cluster.local
            ZITADEL_DATABASE_POSTGRES_PORT=5432
            ZITADEL_DATABASE_POSTGRES_DATABASE={{ .Data.data.database }}
            ZITADEL_DATABASE_POSTGRES_USER_USERNAME={{ .Data.data.username }}
            ZITADEL_DATABASE_POSTGRES_USER_PASSWORD={{ .Data.data.password }}
            ZITADEL_DATABASE_POSTGRES_ADMIN_USERNAME={{ .Data.data.username }}
            ZITADEL_DATABASE_POSTGRES_ADMIN_PASSWORD={{ .Data.data.password }}
            {{- end }}
          EOT
          "vault.hashicorp.com/agent-inject-secret-mail"       = "secret/data/mail/postfix"
          "vault.hashicorp.com/agent-inject-template-mail"     = <<-EOT
            {{- with secret "secret/data/mail/postfix" -}}
            ZITADEL_SMTP_HOST={{ .Data.data.host }}
            ZITADEL_SMTP_PORT={{ .Data.data.port }}
            ZITADEL_SMTP_USER={{ .Data.data.user }}
            ZITADEL_SMTP_PASSWORD={{ .Data.data.password }}
            ZITADEL_SMTP_FROM_ADDRESS={{ .Data.data.from_address }}
            ZITADEL_SMTP_TLS=false
            ZITADEL_SMTP_STARTTLS=false
            {{- end }}
          EOT
        }
      }

      spec {
        service_account_name = kubernetes_service_account.zitadel.metadata[0].name

        container {
          name  = "zitadel"
          image = "ghcr.io/zitadel/zitadel:v2.42.0"

          command = ["/bin/sh", "-c"]
          args = [
            <<-EOT
              # Esperar a que Vault agent inyecte secretos
              while [ ! -f /vault/secrets/zitadel ] || [ ! -f /vault/secrets/database ] || [ ! -f /vault/secrets/mail ]; do
                echo "Esperando secretos de Vault..."
                sleep 5
              done
              
              # Cargar variables de entorno desde Vault
              export $(cat /vault/secrets/zitadel | xargs)
              export $(cat /vault/secrets/database | xargs)
              export $(cat /vault/secrets/mail | xargs)
              
              # Configuración adicional de Zitadel
              export ZITADEL_DATABASE_POSTGRES_USER_SSL_MODE=disable
              export ZITADEL_DATABASE_POSTGRES_ADMIN_SSL_MODE=disable
              export ZITADEL_EXTERNALSECURE=false
              export ZITADEL_TLS_ENABLED=false
              
              # Imprimir configuración para debugging
              echo "Configuración de Zitadel:"
              echo "ZITADEL_DATABASE_POSTGRES_HOST: $ZITADEL_DATABASE_POSTGRES_HOST"
              echo "ZITADEL_DATABASE_POSTGRES_DATABASE: $ZITADEL_DATABASE_POSTGRES_DATABASE"
              echo "ZITADEL_ADMIN_USERNAME: $ZITADEL_ADMIN_USERNAME"
              echo "ZITADEL_SMTP_HOST: $ZITADEL_SMTP_HOST"
              echo "ZITADEL_SMTP_PORT: $ZITADEL_SMTP_PORT"
              echo "ZITADEL_SMTP_FROM_ADDRESS: $ZITADEL_SMTP_FROM_ADDRESS"
              
              # Inicializar Zitadel
              /app/zitadel start-from-init --masterkey $ZITADEL_MASTERKEY --tlsMode disabled
            EOT
          ]

          port {
            container_port = 8080
            name           = "http"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
          }

          readiness_probe {
            http_get {
              path = "/debug/ready"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/debug/healthz"
              port = 8080
            }
            initial_delay_seconds = 60
            period_seconds        = 30
          }
        }
      }
    }
  }
}

# Servicio para Zitadel
resource "kubernetes_service" "zitadel" {
  metadata {
    name      = "zitadel"
    namespace = kubernetes_namespace.identity.metadata[0].name
  }

  spec {
    selector = {
      app = "zitadel"
    }

    port {
      port        = 8080
      target_port = 8080
      name        = "http"
    }
  }
}

# Ingress para Zitadel
resource "kubernetes_ingress_v1" "zitadel" {
  metadata {
    name      = "zitadel"
    namespace = kubernetes_namespace.identity.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                  = "nginx"
      "cert-manager.io/cluster-issuer"               = "ca-issuer"
      "nginx.ingress.kubernetes.io/ssl-redirect"     = "true"
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTP"
    }
  }

  spec {
    tls {
      hosts       = [local.domains.zitadel]
      secret_name = "zitadel-tls"
    }

    rule {
      host = local.domains.zitadel
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.zitadel.metadata[0].name
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }
}

# Outputs
output "phase4_simple_status" {
  description = "Estado de la fase 4 simplificada"
  value = {
    database = {
      namespace = kubernetes_namespace.database.metadata[0].name
      postgres = {
        service    = kubernetes_service.postgres.metadata[0].name
        vault_role = "database-role"
        storage    = "emptyDir (10Gi)"
      }
    }
    monitoring = {
      namespace = kubernetes_namespace.monitoring.metadata[0].name
      grafana = {
        service    = kubernetes_service.grafana.metadata[0].name
        ingress    = local.domains.grafana
        vault_role = "monitoring-role"
        storage    = "emptyDir (5Gi)"
      }
    }
  }
}

output "application_urls_simple" {
  description = "URLs de acceso simplificadas"
  value = {
    grafana     = local.grafana_public ? "https://${local.domains.grafana}" : "Port-forward: localhost:3000"
    zitadel     = "https://${local.domains.zitadel}"
    vault       = "Port-forward: localhost:8200"
    postgres    = "Port-forward: localhost:5432"
    environment = var.environment
    note        = "Configura DNS local para acceder a las aplicaciones públicas"
  }
} 