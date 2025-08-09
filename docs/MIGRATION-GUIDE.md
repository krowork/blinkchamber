# 🚀 Guía de Migración: Deployment Manual → Umbrella Chart

**Versión:** v2.0.0  
**Fecha:** 9 de Agosto de 2025  
**Audiencia:** DevOps Engineers, Platform Engineers

---

## 🎯 Objetivo de la Migración

Migrar desde deployments manuales de ZITADEL hacia una integración completa con el umbrella chart oficial, manteniendo la seguridad con Vault y mejorando la gestión multi-environment.

---

## 📋 Pre-requisitos

### **Sistema Actual:**
- ✅ Kubernetes cluster funcionando
- ✅ Vault desplegado y configurado
- ✅ PostgreSQL funcionando
- ✅ ZITADEL deployment manual funcionando

### **Herramientas Necesarias:**
- `kubectl` configurado
- `helm` v3.x instalado
- Acceso a Vault
- Permisos de admin en el cluster

---

## 🔄 Proceso de Migración

### **Fase 1: Backup y Preparación**

#### **1.1 Backup de Configuración Actual**
```bash
# Backup de deployment actual
kubectl get deployment zitadel -n identity -o yaml > backup/zitadel-deployment.yaml

# Backup de secretos
kubectl get secret -n identity -o yaml > backup/identity-secrets.yaml

# Backup de configuración de Vault
./manage.sh secrets list > backup/vault-secrets-list.txt
```

#### **1.2 Verificar Estado Actual**
```bash
# Verificar pods funcionando
kubectl get pods -n identity
# Esperado: zitadel pod en Running

# Verificar secretos en Vault
./manage.sh secrets verify
# Esperado: Todos los secretos presentes

# Verificar acceso a ZITADEL
kubectl port-forward -n identity svc/zitadel-svc 8080:8080
# Probar: http://localhost:8080
```

### **Fase 2: Actualización de Secretos**

#### **2.1 Sincronizar Secretos para Umbrella Chart**
```bash
# Crear secretos de Kubernetes necesarios
./manage.sh secrets sync-k8s

# Verificar sincronización
kubectl get secret zitadel-masterkey -n identity
# Esperado: Secret creado correctamente
```

#### **2.2 Validar Integración Vault + K8s**
```bash
# Verificar que ambos sistemas tienen el mismo masterkey
VAULT_KEY=$(kubectl exec -n blinkchamber vault-0 -- vault kv get -field=masterkey secret/zitadel/config)
K8S_KEY=$(kubectl get secret zitadel-masterkey -n identity -o jsonpath='{.data.masterkey}' | base64 -d)

if [ "$VAULT_KEY" = "$K8S_KEY" ]; then
    echo "✅ Secretos sincronizados correctamente"
else
    echo "❌ Error: Secretos no coinciden"
    exit 1
fi
```

### **Fase 3: Deployment del Umbrella Chart**

#### **3.1 Dry-run y Validación**
```bash
# Probar configuración con dry-run
./scripts/test-umbrella-deployment.sh development

# Verificar que no hay errores
# Esperado: "✅ Dry-run exitoso"
```

#### **3.2 Deployment Gradual**

##### **Opción A: Deployment con Downtime (Recomendado)**
```bash
# 1. Detener deployment actual
kubectl scale deployment zitadel -n identity --replicas=0

# 2. Esperar a que se detenga
kubectl wait --for=condition=available=false deployment/zitadel -n identity --timeout=300s

# 3. Desplegar umbrella chart
helm upgrade --install blinkchamber-platform . \
  -f environments/base/values.yaml \
  -f environments/development/values.yaml \
  --timeout 10m

# 4. Verificar deployment
kubectl rollout status deployment/zitadel -n identity --timeout=600s
```

##### **Opción B: Blue-Green Deployment (Avanzado)**
```bash
# 1. Desplegar con nombre temporal
helm install blinkchamber-platform-new . \
  -f environments/base/values.yaml \
  -f environments/development/values.yaml \
  --set zitadel.service.name=zitadel-new

# 2. Verificar que funciona
kubectl port-forward -n identity svc/zitadel-new 8081:8080
# Probar: http://localhost:8081

# 3. Cambiar servicio
kubectl patch service zitadel -n identity -p '{"spec":{"selector":{"app.kubernetes.io/name":"zitadel-new"}}}'

# 4. Limpiar deployment anterior
kubectl delete deployment zitadel-old -n identity
```

### **Fase 4: Verificación Post-Migración**

#### **4.1 Verificación Funcional**
```bash
# Verificar pods
kubectl get pods -n identity -l app.kubernetes.io/name=zitadel
# Esperado: Pod en Running con 2/2 containers (zitadel + vault-agent)

# Verificar logs
kubectl logs -n identity -l app.kubernetes.io/name=zitadel -c zitadel --tail=20
# Esperado: "server is listening on [::]:8080"

# Verificar Vault injection
kubectl exec -n identity -l app.kubernetes.io/name=zitadel -c vault-agent -- ls /vault/secrets/
# Esperado: masterkey, db-password
```

#### **4.2 Verificación de Acceso**
```bash
# Port-forward
kubectl port-forward -n identity svc/zitadel 8080:8080

# Probar acceso web
curl -I http://localhost:8080
# Esperado: HTTP 200 OK

# Probar login con credenciales de admin
# Usuario: zitadel-admin
# Password: (obtener con ./manage.sh secrets list)
```

#### **4.3 Verificación de Configuración**
```bash
# Verificar variables de entorno
kubectl exec -n identity -l app.kubernetes.io/name=zitadel -c zitadel -- env | grep ZITADEL_
# Verificar que todas las variables están configuradas

# Verificar dominio configurado
kubectl exec -n identity -l app.kubernetes.io/name=zitadel -c zitadel -- env | grep EXTERNALDOMAIN
# Esperado: ZITADEL_EXTERNALDOMAIN=zitadel.dev.blinkchamber.local
```

---

## 🔧 Troubleshooting

### **Problema 1: Pod en CrashLoopBackOff**

#### **Diagnóstico:**
```bash
kubectl describe pod -n identity -l app.kubernetes.io/name=zitadel
kubectl logs -n identity -l app.kubernetes.io/name=zitadel -c zitadel --tail=50
```

#### **Posibles Causas y Soluciones:**

##### **A. Error de Masterkey**
```bash
# Error: masterkey must be 32 bytes, but is X
./manage.sh secrets sync-k8s  # Regenerar masterkey correcto
kubectl delete pod -n identity -l app.kubernetes.io/name=zitadel  # Reiniciar pod
```

##### **B. Error de Base de Datos**
```bash
# Error: password authentication failed
./manage.sh secrets verify  # Verificar secretos
./manage.sh pods restart-postgres  # Reiniciar PostgreSQL si es necesario

# Verificar password en BD
kubectl exec -n database postgres-xxx -c postgres -- psql -U postgres -c "ALTER USER zitadel PASSWORD 'NEW_PASSWORD';"
```

##### **C. Error de Vault Injection**
```bash
# Error: Vault agent no puede autenticarse
kubectl logs -n identity -l app.kubernetes.io/name=zitadel -c vault-agent-init

# Verificar role de Vault
kubectl exec -n blinkchamber vault-0 -- vault list auth/kubernetes/role
# Debe incluir: zitadel-role
```

### **Problema 2: Helm Deployment Failed**

#### **Error: Template Parsing**
```bash
# Error: cannot parse template
# Causa: Templates de Vault no escapados

# Solución: Verificar que templates usan {{`...`}}
grep -r "{{- with secret" environments/
# Todos deben estar dentro de {{`...`}}
```

#### **Error: Missing Values**
```bash
# Error: nil pointer evaluating interface{}.enabled
# Causa: Valor requerido no definido

# Solución: Agregar valor faltante
echo "videoStorage:
  enabled: false" >> environments/base/values.yaml
```

### **Problema 3: Secretos No Sincronizados**

#### **Diagnóstico:**
```bash
# Verificar secretos en ambos sistemas
./manage.sh secrets list
kubectl get secrets -n identity
```

#### **Solución:**
```bash
# Forzar sincronización
./manage.sh secrets sync-k8s

# Verificar que coinciden
VAULT_KEY=$(kubectl exec -n blinkchamber vault-0 -- vault kv get -field=masterkey secret/zitadel/config)
K8S_KEY=$(kubectl get secret zitadel-masterkey -n identity -o jsonpath='{.data.masterkey}' | base64 -d)
echo "Vault: $VAULT_KEY"
echo "K8s: $K8S_KEY"
```

---

## 🔄 Rollback Plan

### **Si la migración falla, seguir estos pasos:**

#### **1. Rollback Inmediato**
```bash
# Detener umbrella chart
helm uninstall blinkchamber-platform

# Restaurar deployment manual
kubectl apply -f backup/zitadel-deployment.yaml
kubectl apply -f backup/identity-secrets.yaml

# Verificar que funciona
kubectl get pods -n identity
kubectl port-forward -n identity svc/zitadel-svc 8080:8080
```

#### **2. Restaurar Secretos**
```bash
# Si hay problemas con secretos
kubectl apply -f backup/identity-secrets.yaml

# Verificar Vault (no debería cambiar)
./manage.sh secrets verify
```

#### **3. Verificación Post-Rollback**
```bash
# Verificar acceso
curl -I http://localhost:8080

# Verificar logs
kubectl logs -n identity -l app=zitadel --tail=20
```

---

## 📊 Validación de Migración Exitosa

### **Checklist Post-Migración:**

#### **✅ Infraestructura**
- [ ] Pod ZITADEL en estado Running (2/2 containers)
- [ ] Vault Agent inyectando secretos correctamente
- [ ] Base de datos conectada sin errores
- [ ] Logs sin errores críticos

#### **✅ Funcionalidad**
- [ ] Interfaz web accesible
- [ ] Login con usuario admin funcional
- [ ] Configuración de dominio correcta
- [ ] Variables de entorno configuradas

#### **✅ Secretos**
- [ ] Masterkey sincronizado entre Vault y K8s
- [ ] Password de BD correcto
- [ ] Secretos de admin disponibles
- [ ] Vault injection funcionando

#### **✅ Configuración**
- [ ] Environment values aplicados
- [ ] Ingress configurado (si aplica)
- [ ] Recursos asignados correctamente
- [ ] Réplicas según environment

---

## 📚 Comandos de Referencia Post-Migración

### **Gestión Diaria:**
```bash
# Ver estado general
./manage.sh pods status

# Verificar secretos
./manage.sh secrets list

# Reiniciar ZITADEL si es necesario
kubectl rollout restart deployment/zitadel -n identity

# Ver logs
kubectl logs -n identity -l app.kubernetes.io/name=zitadel -c zitadel -f
```

### **Deployment a Otros Environments:**
```bash
# Staging
helm upgrade --install blinkchamber-platform . \
  -f environments/base/values.yaml \
  -f environments/staging/values.yaml

# Production
helm upgrade --install blinkchamber-platform . \
  -f environments/base/values.yaml \
  -f environments/production/values.yaml
```

### **Actualizaciones:**
```bash
# Actualizar configuración
helm upgrade blinkchamber-platform . \
  -f environments/base/values.yaml \
  -f environments/development/values.yaml

# Actualizar secretos
./manage.sh secrets create-zitadel  # Regenera secretos
./manage.sh secrets sync-k8s       # Sincroniza con K8s
```

---

## 🎯 Beneficios Post-Migración

### **Operacionales:**
- ✅ **Deployment Unificado:** Un comando para todos los components
- ✅ **Gestión Multi-Environment:** Configuración específica por entorno
- ✅ **Rollback Automático:** Helm maneja rollbacks automáticamente
- ✅ **Versionado:** Historial de releases con Helm

### **Técnicos:**
- ✅ **Chart Oficial:** Compatibilidad con ecosystem de ZITADEL
- ✅ **Configuración Centralizada:** Base + overrides por environment
- ✅ **Secretos Híbridos:** Vault + Kubernetes para máxima compatibilidad
- ✅ **Automatización:** Scripts mejorados para gestión diaria

---

**Estado:** ✅ **READY FOR PRODUCTION** - Migración validada y documentada
