# BlinkChamber - Quick Start Guide

## 🚀 Inicio Rápido

### Prerrequisitos

- **Docker** y **Docker Compose** instalados
- **Kind** (Kubernetes in Docker) instalado
- **Terraform** >= 1.5.0 instalado
- **kubectl** configurado

### Despliegue Automático

```bash
# 1. Clonar el repositorio
git clone <repository-url>
cd blinkchamber

# 2. Ejecutar despliegue completo
./scripts/vault-bootstrap.sh all

# 3. Verificar estado
kubectl get pods --all-namespaces
```

### URLs de Acceso

- **Vault UI**: `https://vault.blinkchamber.local`
- **Grafana**: `https://grafana.blinkchamber.local`
- **Zitadel**: `https://zitadel.blinkchamber.local`

## 🔧 Configuración de DNS Local

```bash
# Añadir entradas DNS locales
echo '127.0.0.1 vault.blinkchamber.local' | sudo tee -a /etc/hosts
echo '127.0.0.1 grafana.blinkchamber.local' | sudo tee -a /etc/hosts
echo '127.0.0.1 zitadel.blinkchamber.local' | sudo tee -a /etc/hosts
```

## 🌍 Control de Acceso por Entorno

El sistema permite configurar el acceso a servicios basado en el entorno:

### **Zitadel**: Siempre Público
- **Desarrollo**: `https://zitadel.blinkchamber.local`
- **Testing**: `https://zitadel.blinkchamber.local`
- **Producción**: `https://zitadel.blinkchamber.local`

### **Otros Servicios**: Solo en Desarrollo/Testing
- **Vault**: Port-forward `localhost:8200` (solo dev/test)
- **Grafana**: `https://grafana.blinkchamber.local` (solo dev/test)
- **PostgreSQL**: Port-forward `localhost:5432` (solo dev/test)

### Configuración por Entorno

```bash
# Desarrollo (acceso completo)
./scripts/access-control.sh setup dev

# Testing (acceso completo)
./scripts/access-control.sh setup test

# Producción (solo Zitadel público)
./scripts/access-control.sh setup prod

# Configurar port-forwards para servicios internos
./scripts/access-control.sh port-forward

# Ver estado actual
./scripts/access-control.sh status

# Detener port-forwards
./scripts/access-control.sh stop
```

### Configuración Manual con Terraform

```bash
# Desarrollo
cd terraform/phases/04-applications
terraform apply -var-file="environments/dev.tfvars"

# Producción
terraform apply -var-file="environments/prod.tfvars"
```

## 🚨 Problemas Comunes y Soluciones

### 1. **Problema: Configuración Hardcodeada**

**Síntomas:**
- Pods en CrashLoopBackOff
- Errores de autenticación de base de datos
- Variables de entorno vacías

**Causa:** Uso de credenciales hardcodeadas en lugar de Vault

**Solución:**
```bash
# Verificar que Vault esté dessellado
kubectl exec -it vault-0 -n vault -- vault status

# Si está sellado, dessellar
./scripts/vault-bootstrap.sh unseal

# Verificar secretos en Vault
source data/vault/vault-env.sh
kubectl exec -it vault-0 -n vault -- vault kv get secret/database/postgres
```

### 2. **Problema: Nombres de Servicios Incorrectos**

**Síntomas:**
- `nc: bad address 'postgresql.database.svc.cluster.local'`
- Init containers fallando

**Causa:** Nombres de servicios hardcodeados incorrectos

**Solución:**
```bash
# Verificar nombres correctos
kubectl get services -n database
# Debe ser: postgres.database.svc.cluster.local

# Corregir en configuración
# Usar: postgres.database.svc.cluster.local
# En lugar de: postgresql.database.svc.cluster.local
```

### 3. **Problema: Políticas de Vault Faltantes**

**Síntomas:**
- `permission denied` en logs de vault-agent
- Pods no pueden obtener secretos

**Causa:** Roles y políticas de Vault no creados

**Solución:**
```bash
# Crear políticas necesarias
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_TOKEN=hvs.$(cat vault-init.json | jq -r '.root_token') && 
vault policy write identity-policy - <<EOF
path \"secret/data/identity/*\" {
  capabilities = [\"read\"]
}
path \"secret/data/database/*\" {
  capabilities = [\"read\"]
}
EOF

# Crear roles
vault write auth/kubernetes/role/identity-role \
  bound_service_account_names=zitadel \
  bound_service_account_namespaces=identity \
  policies=identity-policy ttl=1h
"
```

### 4. **Problema: Credenciales Inconsistentes**

**Síntomas:**
- `FATAL: password authentication failed for user "postgres"`
- Diferentes contraseñas entre servicios

**Causa:** Diferentes fuentes de credenciales

**Solución:**
```bash
# Usar credenciales de Vault consistentemente
kubectl exec -it postgres-xxx -n database -c vault-agent -- cat /vault/secrets/postgres

# Asegurar que Zitadel use las mismas credenciales
# Verificar que use: secret/data/database/postgres
# En lugar de: secret/data/database/zitadel
```

### 5. **Problema: Templates de Vault Malformados**

**Síntomas:**
- `syntax error: unexpected end of file`
- Variables de entorno vacías

**Causa:** Templates sin salto de línea final

**Solución:**
```hcl
# En templates de Vault, usar:
"vault.hashicorp.com/agent-inject-template-postgres" = <<-EOT
  {{- with secret "secret/data/database/postgres" -}}
  POSTGRES_USER={{ .Data.data.username }}
  POSTGRES_PASSWORD={{ .Data.data.password }}
  POSTGRES_DB={{ .Data.data.database }}
  {{- end }}
EOT
# NOTA: {{- end }} sin guiones para mantener salto de línea
```

### 6. **Problema: Acceso Incorrecto por Entorno**

**Síntomas:**
- Servicios no accesibles según el entorno
- Port-forwards no funcionando
- Ingress no configurado correctamente

**Causa:** Configuración de entorno incorrecta

**Solución:**
```bash
# Verificar configuración actual
./scripts/access-control.sh status

# Reconfigurar para el entorno correcto
./scripts/access-control.sh setup dev    # Para desarrollo
./scripts/access-control.sh setup prod   # Para producción

# Configurar port-forwards manualmente
./scripts/access-control.sh port-forward
```

## 📋 Checklist de Verificación

### ✅ Fase 1: Bootstrap
- [ ] Cluster Kind creado
- [ ] Ingress Controller desplegado
- [ ] Cert-Manager instalado
- [ ] Vault desplegado

### ✅ Fase 2: Vault Init
- [ ] Vault inicializado
- [ ] Vault dessellado
- [ ] Autenticación Kubernetes configurada

### ✅ Fase 3: Secretos
- [ ] Motor KV v2 habilitado
- [ ] Secretos creados en Vault
- [ ] Políticas configuradas
- [ ] Roles de autenticación creados

### ✅ Fase 4: Aplicaciones
- [ ] PostgreSQL funcionando (2/2 Running)
- [ ] Grafana funcionando (2/2 Running)
- [ ] Zitadel funcionando (1/1 Running)
- [ ] Ingress configurado según entorno

### ✅ Control de Acceso
- [ ] Zitadel accesible públicamente
- [ ] Otros servicios configurados según entorno
- [ ] Port-forwards funcionando (dev/test)
- [ ] URLs de acceso verificadas

## 🔍 Comandos de Diagnóstico

```bash
# Estado general
kubectl get pods --all-namespaces

# Logs de Vault
kubectl logs -n vault vault-0

# Verificar secretos
kubectl exec -it vault-0 -n vault -- vault kv list secret/

# Estado de autenticación
kubectl exec -it vault-0 -n vault -- vault auth list

# Verificar políticas
kubectl exec -it vault-0 -n vault -- vault policy list

# Estado de acceso
./scripts/access-control.sh status

# Verificar Ingress
kubectl get ingress --all-namespaces
```

## 🎯 Mejores Prácticas

1. **Usar Vault como fuente única de verdad** para credenciales
2. **Evitar configuración hardcodeada** en deployments
3. **Verificar nombres de servicios** antes de desplegar
4. **Crear políticas de Vault** antes de desplegar aplicaciones
5. **Usar templates consistentes** para variables de entorno
6. **Verificar conectividad** entre servicios antes de desplegar
7. **Configurar acceso según entorno** usando los scripts proporcionados
8. **Zitadel siempre público** para acceso de usuarios
9. **Servicios internos solo en dev/test** para seguridad

## 📞 Soporte

Si encuentras problemas:

1. Revisar logs: `kubectl logs -n <namespace> <pod-name>`
2. Verificar estado: `kubectl describe pod <pod-name> -n <namespace>`
3. Consultar esta guía de troubleshooting
4. Revisar documentación en `docs/`
5. Usar: `./scripts/access-control.sh status` para diagnóstico

---

> **💡 Pro Tip**: El comando `./scripts/vault-bootstrap.sh all` resuelve el 95% de los casos de uso. ¡Úsalo y luego explora! 