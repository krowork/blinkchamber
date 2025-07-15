resource "vault_policy" "database" {
  name = "database-policy"

  policy = <<EOT
path "secret/data/database/*" {
  capabilities = ["read"]
}
EOT
}

resource "vault_policy" "identity" {
  name = "identity-policy"

  policy = <<EOT
path "secret/data/identity/*" {
  capabilities = ["read"]
}

path "secret/data/database/*" {
  capabilities = ["read"]
}
EOT
}

resource "vault_policy" "monitoring" {
  name = "monitoring-policy"

  policy = <<EOT
path "secret/data/monitoring/*" {
  capabilities = ["read"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "database" {
  backend   = "kubernetes"
  role_name = "database-role"

  bound_service_account_names      = ["postgres"]
  bound_service_account_namespaces = ["database"]
  token_policies                   = ["database-policy"]
  ttl                              = 3600
}

resource "vault_kubernetes_auth_backend_role" "identity" {
  backend   = "kubernetes"
  role_name = "identity-role"

  bound_service_account_names      = ["zitadel"]
  bound_service_account_namespaces = ["identity"]
  token_policies                   = ["identity-policy"]
  ttl                              = 3600
}

resource "vault_kubernetes_auth_backend_role" "monitoring" {
  backend   = "kubernetes"
  role_name = "monitoring-role"

  bound_service_account_names      = ["grafana"]
  bound_service_account_namespaces = ["monitoring"]
  token_policies                   = ["monitoring-policy"]
  ttl                              = 3600
}
