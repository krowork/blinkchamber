provider "vault" {
  address = "https://vault.blinkchamber.svc:8200"
  # token = "..." # Usa VAULT_TOKEN en el entorno o configura autenticación adecuada
}

resource "vault_policy" "postgres" {
  name   = "postgres-policy"
  policy = <<EOT
path "secret/data/postgres" {
  capabilities = ["read"]
}
EOT
}

resource "vault_policy" "zitadel" {
  name   = "zitadel-policy"
  policy = <<EOT
path "secret/data/zitadel/postgres" {
  capabilities = ["read"]
}
path "secret/data/zitadel/vault" {
  capabilities = ["read"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "postgres" {
  backend                          = "kubernetes"
  role_name                        = "postgres-role"
  bound_service_account_names      = ["postgresql-ha"]
  bound_service_account_namespaces = ["database"]
  policies                         = [vault_policy.postgres.name]
  ttl                              = 86400
}

resource "vault_kubernetes_auth_backend_role" "zitadel" {
  backend                          = "kubernetes"
  role_name                        = "zitadel-role"
  bound_service_account_names      = ["zitadel"]
  bound_service_account_namespaces = ["identity"]
  policies                         = [vault_policy.zitadel.name]
  ttl                              = 86400
} 