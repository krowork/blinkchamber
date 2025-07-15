# Sistema de Correo - BlinChamber

Esta carpeta contiene la configuración del sistema de correo para BlinChamber, que proporciona capacidades SMTP para Zitadel y otras aplicaciones utilizando **Vault Agent Sidecar** para gestión profesional de secretos.

## 🎯 Sistemas Disponibles

### **1. Mailu (Producción)**
- **Propósito**: Sistema completo de correo para producción
- **Características**:
  - SMTP para envío de correos
  - IMAP/POP3 para recepción
  - Integración con PostgreSQL
  - Persistencia de datos
  - Autenticación de usuarios
  - **Vault Agent Sidecar** para gestión de secretos
  - **ServiceAccount específico** para autenticación de Kubernetes

### **2. Mailhog (Desarrollo)**
- **Propósito**: Sistema de correo para desarrollo/testing
- **Características**:
  - SMTP para captura de correos
  - Interfaz web para visualización
  - Sin persistencia (datos se pierden al reiniciar)
  - Sin autenticación
  - **Vault Agent Sidecar** para consistencia arquitectural

## 📁 Archivos

- `mailu-deployment.yaml` - Configuración completa de Mailu con Vault Agent Sidecar
- `mailhog-deployment.yaml` - Configuración de Mailhog con Vault Agent Sidecar
- `README.md` - Esta documentación

## 🚀 Despliegue

### **Opción 1: Script Automático (Recomendado)**

```bash
# Desarrollo con Mailhog
./scripts/deploy-mail-system.sh --environment dev --system mailhog

# Testing con Mailu
./scripts/deploy-mail-system.sh --environment test --system mailu

# Producción con Mailu
./scripts/deploy-mail-system.sh --environment prod --system mailu
```

### **Opción 2: Terraform (Integrado)**

El sistema de correo está integrado en la fase 4 de Terraform:

```bash
cd terraform/phases/04-applications
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### **Opción 3: kubectl Directo**

```bash
# Para desarrollo
kubectl apply -f config/mail/mailhog-deployment.yaml

# Para producción
kubectl apply -f config/mail/mailu-deployment.yaml
```

## 🔐 Integración con Vault Agent Sidecar

### **Arquitectura de Seguridad**

```
┌─────────────────────────────────────────────────────────────────┐
│                    Pod de Mailu                                 │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   Mailu App     │  │  Vault Agent    │  │  Init Container │ │
│  │                 │  │   Sidecar       │  │                 │ │
│  │ - Lee secretos  │  │ - Auth con K8s  │  │ - Espera        │ │
│  │   desde archivo │  │ - Descarga      │  │   secretos      │ │
│  │ - Sin acceso    │  │ - Escribe a     │  │   arranque      │ │
│  │   directo a     │  │   archivo       │  │                 │ │
│  │   Vault         │  │                 │  │                 │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### **Secretos Automáticos**

El sistema genera automáticamente secretos seguros:

```bash
# Ver secretos de correo
vault kv list secret/mail/
vault kv get secret/mail/mailu
```

### **Políticas de Seguridad**

```hcl
# mail-policy: Acceso solo a secretos de correo
path "secret/data/mail/*" {
  capabilities = ["read"]
}

# mail-database-policy: Acceso a correo + database
path "secret/data/mail/*" {
  capabilities = ["read"]
}
path "secret/data/database/*" {
  capabilities = ["read"]
}
```

### **ServiceAccount y Autenticación**

```yaml
# ServiceAccount específico para Mailu
apiVersion: v1
kind: ServiceAccount
metadata:
  name: mailu-sa
  namespace: mail
---
# Deployment con Vault Agent Sidecar
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mailu
spec:
  template:
    spec:
      serviceAccountName: mailu-sa
      containers:
      - name: mailu
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

## 🔧 Configuración de Vault Agent

### **ConfigMap de Vault Agent**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-agent-config
  namespace: mail
data:
  vault-agent.hcl: |
    exit_after_auth = true
    pid_file = "/home/vault/pidfile"
    
    auto_auth {
      method "kubernetes" {
        mount_path = "auth/kubernetes"
        role = "mailu-role"
      }
    }
    
    template {
      destination = "/vault/secrets/mailu"
      contents = <<EOH
      {{- with secret "secret/data/mail/mailu" -}}
      MAILU_SMTP_HOST={{ .Data.data.smtp_host }}
      MAILU_SMTP_PORT={{ .Data.data.smtp_port }}
      MAILU_SMTP_USER={{ .Data.data.smtp_user }}
      MAILU_SMTP_PASSWORD={{ .Data.data.smtp_password }}
      {{- end }}
      EOH
    }
```

### **Rol de Vault para Mailu**

```bash
# Crear rol específico para Mailu
vault write auth/kubernetes/role/mailu-role \
  bound_service_account_names=mailu-sa \
  bound_service_account_namespaces=mail \
  policies=mail-policy ttl=1h
```

## 📊 Monitoreo y Logs

### **Logs de Vault Agent**

```bash
# Ver logs de Vault Agent en Mailu
kubectl logs -f deployment/mailu -c vault-agent -n mail

# Ver logs de la aplicación principal
kubectl logs -f deployment/mailu -c mailu -n mail

# Ver logs del initContainer
kubectl logs -f deployment/mailu -c wait-for-secrets -n mail
```

### **Verificación de Secretos**

```bash
# Verificar que los secretos se generaron correctamente
kubectl exec -it deployment/mailu -c vault-agent -n mail -- cat /vault/secrets/mailu

# Verificar conectividad con base de datos
kubectl exec -it deployment/mailu -c mailu -n mail -- nc -z postgres.database.svc.cluster.local 5432
```

## 🛠️ Troubleshooting

### **Problemas Comunes**

1. **Vault Agent no puede autenticarse**
   ```bash
   # Verificar ServiceAccount
   kubectl get serviceaccount mailu-sa -n mail
   
   # Verificar rol de Vault
   vault read auth/kubernetes/role/mailu-role
   ```

2. **Secretos no se generan**
   ```bash
   # Verificar políticas
   vault policy read mail-policy
   
   # Verificar secretos en Vault
   vault kv get secret/mail/mailu
   ```

3. **InitContainer no termina**
   ```bash
   # Verificar logs del initContainer
   kubectl logs deployment/mailu -c wait-for-secrets -n mail
   
   # Verificar que Vault está disponible
   kubectl exec -it vault-0 -n vault -- vault status
   ```

### **Comandos de Diagnóstico**

```bash
# Estado general del sistema de correo
kubectl get pods -n mail
kubectl get services -n mail
kubectl get ingress -n mail

# Verificar configuración de Vault
vault kv list secret/mail/
vault policy list | grep mail
vault auth list | grep kubernetes

# Verificar conectividad
kubectl exec -it deployment/mailu -n mail -- curl -s http://vault.vault.svc.cluster.local:8200/v1/sys/health
```

## 🔄 Migración desde Configuración Anterior

### **Cambios Principales**

| Aspecto | Antes | Ahora |
|---------|-------|-------|
| **Secretos** | Kubernetes Secrets | Vault Agent Sidecar |
| **Autenticación** | Manual | ServiceAccount de Kubernetes |
| **Configuración** | Hardcodeada | Templates de Vault |
| **Seguridad** | Básica | Zero Trust con auditoría |

### **Pasos de Migración**

1. **Crear ServiceAccount**
   ```bash
   kubectl apply -f config/mail/mailu-serviceaccount.yaml
   ```

2. **Configurar Vault**
   ```bash
   # Crear políticas y roles
   ./scripts/configure-vault-auth.sh
   ```

3. **Desplegar nueva configuración**
   ```bash
   kubectl apply -f config/mail/mailu-deployment.yaml
   ```

4. **Verificar migración**
   ```bash
   kubectl get pods -n mail
   kubectl logs -f deployment/mailu -c vault-agent -n mail
   ```

## 📚 Referencias

- [Vault Agent Sidecar Documentation](https://www.vaultproject.io/docs/agent)
- [Kubernetes Auth Method](https://www.vaultproject.io/docs/auth/kubernetes)
- [Mailu Documentation](https://mailu.io/)
- [Troubleshooting Guide](../docs/TROUBLESHOOTING-INSIGHTS.md) 