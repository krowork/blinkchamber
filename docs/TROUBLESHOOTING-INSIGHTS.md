# Troubleshooting Insights - BlinkChamber

## 🎯 Insights Aprendidos

Este documento recopila los insights aprendidos durante el desarrollo y troubleshooting del proyecto BlinkChamber, especialmente relacionados con **configuración hardcodeada** y **gestión de secretos profesional con Vault Agent Sidecar**.

## 🚨 Problemas Principales Identificados

### 1. **Configuración Hardcodeada vs Vault Agent Sidecar**

#### ❌ **Problema: Configuración Hardcodeada**
```yaml
# MAL: Credenciales hardcodeadas
env:
- name: POSTGRES_PASSWORD
  value: "postgres123456"  # Hardcodeado
- name: ZITADEL_DATABASE_HOST
  value: "postgresql.database.svc.cluster.local"  # Nombre incorrecto
```

#### ✅ **Solución: Vault Agent Sidecar**
```yaml
# BIEN: Vault Agent Sidecar con autenticación de Kubernetes
apiVersion: v1
kind: ServiceAccount
metadata:
  name: zitadel-sa
  namespace: identity
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zitadel
spec:
  template:
    spec:
      serviceAccountName: zitadel-sa
      containers:
      - name: zitadel
        # Aplicación principal
      - name: vault-agent
        # Vault Agent Sidecar
        image: hashicorp/vault:1.15.2
        args:
        - agent
        - -config=/vault/config/vault-agent.hcl
      initContainers:
      - name: wait-for-secrets
        # Espera a que los secretos estén disponibles
```

### 2. **Nombres de Servicios Inconsistentes**

#### ❌ **Problema: Nombres Hardcodeados Incorrectos**
```bash
# MAL: Nombre de servicio incorrecto
ZITADEL_DATABASE_HOST=postgresql.database.svc.cluster.local
```

#### ✅ **Solución: Verificar Nombres Reales**
```bash
# BIEN: Verificar nombres reales
kubectl get services -n database
# Resultado: postgres (no postgresql)

# Usar nombres correctos
ZITADEL_DATABASE_HOST=postgres.database.svc.cluster.local
```

### 3. **Políticas de Vault Faltantes**

#### ❌ **Problema: Roles y Políticas No Creados**
```bash
# Error: permission denied
# Error: role not found
```

#### ✅ **Solución: Crear Políticas y Roles Automáticamente**
```bash
# Crear políticas granulares
vault policy write identity-policy - <<EOF
path "secret/data/identity/*" {
  capabilities = ["read"]
}
path "secret/data/database/*" {
  capabilities = ["read"]
}
EOF

# Crear roles con ServiceAccounts específicos
vault write auth/kubernetes/role/identity-role \
  bound_service_account_names=zitadel-sa \
  bound_service_account_namespaces=identity \
  policies=identity-policy ttl=1h
```

### 4. **Credenciales Inconsistentes**

#### ❌ **Problema: Diferentes Fuentes de Credenciales**
```bash
# PostgreSQL usa: -1p{OAWaY&(Ha%%zLM<Z#apv<U@Gp0?6
# Zitadel usa: postgres123456
# Resultado: FATAL: password authentication failed
```

#### ✅ **Solución: Usar Misma Fuente de Credenciales**
```bash
# Usar secretos de Vault consistentemente
# PostgreSQL: secret/data/database/postgres
# Zitadel: secret/data/database/postgres (mismo secreto)
```

### 5. **Templates de Vault Malformados**

#### ❌ **Problema: Templates Sin Salto de Línea**
```hcl
# MAL: Sin salto de línea final
"vault.hashicorp.com/agent-inject-template-postgres" = <<-EOT
  {{- with secret "secret/data/database/postgres" -}}
  POSTGRES_USER={{ .Data.data.username }}
  POSTGRES_PASSWORD={{ .Data.data.password }}
  {{- end -}}
EOT
```

#### ✅ **Solución: Templates Correctos**
```hcl
# BIEN: Con salto de línea final
"vault.hashicorp.com/agent-inject-template-postgres" = <<-EOT
  {{- with secret "secret/data/database/postgres" -}}
  POSTGRES_USER={{ .Data.data.username }}
  POSTGRES_PASSWORD={{ .Data.data.password }}
  {{- end }}
EOT
```

### 6. **Vault Agent Sidecar No Configurado**

#### ❌ **Problema: Aplicaciones Sin Vault Agent**
```yaml
# MAL: Sin Vault Agent Sidecar
containers:
- name: zitadel
  # Solo aplicación principal
```

#### ✅ **Solución: Vault Agent Sidecar Completo**
```yaml
# BIEN: Vault Agent Sidecar con configuración completa
containers:
- name: zitadel
  # Aplicación principal
- name: vault-agent
  # Vault Agent Sidecar
  image: hashicorp/vault:1.15.2
  args:
  - agent
  - -config=/vault/config/vault-agent.hcl
  volumeMounts:
  - name: vault-config
    mountPath: /vault/config
  - name: vault-secrets
    mountPath: /vault/secrets
initContainers:
- name: wait-for-secrets
  # Espera a que los secretos estén disponibles
```

## 🔧 Soluciones Implementadas

### 1. **Script de Configuración Automática**

```bash
# Configurar todo automáticamente
./scripts/configure-vault-auth.sh
```

Este script:
- ✅ Crea políticas de Vault automáticamente
- ✅ Crea roles de autenticación de Kubernetes
- ✅ Crea secretos necesarios
- ✅ Verifica la configuración
- ✅ Configura Vault Agent Sidecar

### 2. **Configuración Centralizada en Terraform**

```hcl
# Usar secretos centralizados con Vault Agent
resource "kubernetes_deployment" "zitadel" {
  metadata {
    name = "zitadel"
    namespace = "identity"
  }
  
  spec {
    template {
      spec {
        service_account_name = "zitadel-sa"
        
        container {
          name = "zitadel"
          # Aplicación principal
        }
        
        container {
          name = "vault-agent"
          # Vault Agent Sidecar
          image = "hashicorp/vault:1.15.2"
          args = ["agent", "-config=/vault/config/vault-agent.hcl"]
        }
        
        init_container {
          name = "wait-for-secrets"
          # Espera a que los secretos estén disponibles
        }
      }
    }
  }
}
```

### 3. **Verificación de Nombres de Servicios**

```bash
# Verificar nombres reales antes de configurar
kubectl get services -n database
kubectl get services -n monitoring
kubectl get services -n identity
kubectl get services -n mail
```

### 4. **Configuración de Vault Agent**

```hcl
# Configuración de Vault Agent para cada aplicación
resource "kubernetes_config_map" "vault_agent_config" {
  metadata {
    name = "vault-agent-config"
    namespace = "identity"
  }
  
  data = {
    "vault-agent.hcl" = <<-EOT
      exit_after_auth = true
      pid_file = "/home/vault/pidfile"
      
      auto_auth {
        method "kubernetes" {
          mount_path = "auth/kubernetes"
          role = "identity-role"
        }
      }
      
      template {
        destination = "/vault/secrets/database"
        contents = <<EOH
        {{- with secret "secret/data/database/postgres" -}}
        POSTGRES_USER={{ .Data.data.username }}
        POSTGRES_PASSWORD={{ .Data.data.password }}
        POSTGRES_DB={{ .Data.data.database }}
        {{- end }}
        EOH
      }
    EOT
  }
}
```

## 📋 Checklist de Prevención

### Antes de Desplegar:

- [ ] **Verificar Vault está dessellado**
- [ ] **Crear políticas y roles de Vault**
- [ ] **Verificar nombres de servicios reales**
- [ ] **Usar secretos centralizados**
- [ ] **Verificar templates de Vault**
- [ ] **Configurar Vault Agent Sidecar**
- [ ] **Crear ServiceAccounts específicos**
- [ ] **Configurar initContainers para esperar secretos**
- [ ] **Probar conectividad entre servicios**

### Durante el Despliegue:

- [ ] **Monitorear logs de vault-agent**
- [ ] **Verificar secretos se generan correctamente**
- [ ] **Comprobar autenticación de base de datos**
- [ ] **Verificar health checks**
- [ ] **Monitorear logs de initContainers**

### Después del Despliegue:

- [ ] **Verificar todos los pods están Running**
- [ ] **Probar acceso a aplicaciones**
- [ ] **Verificar logs de aplicaciones**
- [ ] **Verificar logs de Vault Agent**
- [ ] **Documentar configuración exitosa**

## 🎯 Mejores Prácticas

### 1. **Usar Vault Agent Sidecar como Fuente Única de Verdad**
```bash
# ✅ BIEN: Obtener credenciales desde Vault Agent
kubectl exec -it pod-name -c vault-agent -- cat /vault/secrets/secret-name

# ❌ MAL: Hardcodear credenciales
env:
- name: PASSWORD
  value: "hardcoded-password"
```

### 2. **Verificar Configuración Antes de Desplegar**
```bash
# Verificar que todo esté configurado
./scripts/configure-vault-auth.sh
kubectl get pods --all-namespaces
kubectl get serviceaccounts --all-namespaces
```

### 3. **Usar Nombres de Servicios Correctos**
```bash
# Verificar nombres reales
kubectl get services --all-namespaces

# Usar nombres correctos en configuración
host=postgres.database.svc.cluster.local  # ✅ Correcto
host=postgresql.database.svc.cluster.local # ❌ Incorrecto
```

### 4. **Monitorear Logs Durante Despliegue**
```bash
# Monitorear logs en tiempo real
kubectl logs -f deployment/zitadel -n identity
kubectl logs -f deployment/postgres -n database
kubectl logs -f deployment/zitadel -c vault-agent -n identity
```

### 5. **Configurar Vault Agent Correctamente**
```yaml
# Configuración completa de Vault Agent
containers:
- name: vault-agent
  image: hashicorp/vault:1.15.2
  args:
  - agent
  - -config=/vault/config/vault-agent.hcl
  volumeMounts:
  - name: vault-config
    mountPath: /vault/config
  - name: vault-secrets
    mountPath: /vault/secrets
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
```

### 6. **Documentar Configuración Exitosa**
```bash
# Guardar configuración exitosa
kubectl get all --all-namespaces -o yaml > successful-deployment.yaml
vault policy list > vault-policies.txt
vault auth list > vault-auth-methods.txt
``` 