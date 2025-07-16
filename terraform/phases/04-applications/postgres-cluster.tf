resource "kubernetes_cluster" "postgres" {
  metadata {
    name      = "postgres-cluster"
    namespace = "database"
  }

  spec {
    instances = 3

    storage {
      size = "10Gi"
      storage_class = "rook-ceph-block"
    }

    postgresql {
      parameters = {
        "log_statement" = "all"
      }
    }

    bootstrap {
      initdb {
        database = "zitadel"
        owner    = "postgres"
      }
    }
  }
}

resource "kubernetes_secret" "postgres_credentials" {
  metadata {
    name      = "postgres-cluster-superuser"
    namespace = "database"
  }

  data = {
    username = "postgres"
    password = vault_generic_secret.postgres.data.password
  }

  depends_on = [kubernetes_cluster.postgres]
}

resource "vault_generic_secret" "postgres" {
  path = "secret/data/database/postgres"

  data_json = jsonencode({
    username = "postgres"
    password = random_password.password.result
    database = "zitadel"
    host     = "postgres-cluster-rw.database.svc.cluster.local"
    port     = "5432"
  })
}

resource "random_password" "password" {
  length  = 16
  special = true
}

resource "kubernetes_namespace" "database" {
  metadata {
    name = "database"
  }
}
