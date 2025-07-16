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
- **Consul UI**: `http://localhost:8500` (via port-forward)

## 🔧 Configuración de DNS Local

```bash
# Añadir entradas DNS locales
echo '127.0.0.1 vault.blinkchamber.local' | sudo tee -a /etc/hosts
echo '127.0.0.1 grafana.blinkchamber.local' | sudo tee -a /etc/hosts
echo '127.0.0.1 zitadel.blinkchamber.local' | sudo tee -a /etc/hosts
```

## 📋 Checklist de Verificación

### ✅ Fase 1: Bootstrap
- [ ] Cluster Kind creado
- [ ] Ingress Controller desplegado
- [ ] Cert-Manager instalado
- [ ] Rook/Ceph instalado y saludable
- [ ] Consul instalado y saludable
- [ ] Vault desplegado en modo HA

### ✅ Fase 2: Vault Init
- [ ] Vault inicializado y dessellado
- [ ] Autenticación Kubernetes configurada

### ✅ Fase 3: Secretos
- [ ] Motor KV v2 habilitado
- [ ] Secretos creados en Vault

### ✅ Fase 4: Aplicaciones
- [ ] PostgreSQL cluster en HA funcionando
- [ ] Grafana funcionando
- [ ] Zitadel en HA funcionando

## 🔍 Comandos de Diagnóstico

```bash
# Estado general
kubectl get pods --all-namespaces

# Logs de Vault
kubectl logs -n vault -l app.kubernetes.io/name=vault

# Verificar secretos
kubectl exec -it vault-0 -n vault -- vault kv list secret/

# Estado de autenticación
kubectl exec -it vault-0 -n vault -- vault auth list

# Verificar políticas
kubectl exec -it vault-0 -n vault -- vault policy list

# Estado del cluster de PostgreSQL
kubectl get cluster -n database postgres-cluster

# Estado de Consul
kubectl get pods -n consul
```

## 🎯 Mejores Prácticas

1. **Usar Vault como fuente única de verdad** para credenciales
2. **Evitar configuración hardcodeada** en deployments
3. **Verificar nombres de servicios** antes de desplegar
4. **Crear políticas de Vault** antes de desplegar aplicaciones
5. **Usar templates consistentes** para variables de entorno
6. **Verificar conectividad** entre servicios antes de desplegar
7. **Zitadel siempre público** para acceso de usuarios

## 📞 Soporte

Si encuentras problemas:

1. Revisar logs: `kubectl logs -n <namespace> <pod-name>`
2. Verificar estado: `kubectl describe pod <pod-name> -n <namespace>`
3. Consultar esta guía de troubleshooting
4. Revisar documentación en `docs/`

---

> **💡 Pro Tip**: El comando `./scripts/vault-bootstrap.sh all` resuelve el 95% de los casos de uso. ¡Úsalo y luego explora! 