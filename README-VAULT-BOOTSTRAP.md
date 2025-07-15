# 🚀 blinkchamber - Sistema de Bootstrap Automático con Vault

## 📋 Resumen

**blinkchamber v2.0** es un sistema de gestión de identidad y secretos completamente automatizado que utiliza **HashiCorp Vault** como backend central para la gestión de secretos. El sistema se despliega en **4 fases secuenciales** que garantizan una inicialización segura y completamente automatizada.

## 🎯 Características Principales

- ✅ **Bootstrap Automático**: Despliegue completamente automatizado en 4 fases
- 🔐 **Vault como Backend Central**: Todos los secretos se gestionan automáticamente en Vault
- 🔄 **Auto-unseal**: Soporte para auto-unseal en producción (AWS KMS, Azure Key Vault, etc.)
- 🛡️ **Seguridad por Defecto**: Políticas de seguridad, network policies, y RBAC configurados automáticamente
- 🏗️ **Infraestructura como Código**: Terraform para toda la infraestructura
- 🔍 **Monitoreo Integrado**: Grafana y métricas configuradas automáticamente

## 📊 Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────────┐
│                    FASE 1: Bootstrap Básico                     │
├─────────────────────────────────────────────────────────────────┤
│  kubernetes-base → ingress-nginx → cert-manager → vault-infra  │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                  FASE 2: Inicialización Vault                   │
├─────────────────────────────────────────────────────────────────┤
│    vault-init → kubernetes-auth → policies → auto-unseal       │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                 FASE 3: Configuración Secretos                  │
├─────────────────────────────────────────────────────────────────┤
│     kv-engine → app-secrets → vault-policies → k8s-roles       │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│              FASE 4: Aplicaciones con Vault                     │
├─────────────────────────────────────────────────────────────────┤
│   database → identity → storage → monitoring (todos con Vault)  │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 Inicio Rápido

### 1. Prerequisitos

```bash
# Herramientas requeridas
sudo apt-get update && sudo apt-get install -y \
  curl wget jq

# Instalar Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind

# Instalar kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/kubectl

# Instalar Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Instalar Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 2. Crear Cluster

```bash
# Crear cluster Kind con configuración optimizada
kind create cluster --name blinkchamber --config config/kind-config.yaml

# Verificar cluster
kubectl cluster-info --context kind-blinkchamber
```

### 3. Bootstrap Automático

```bash
# Opción 1: Bootstrap completo automático (recomendado)
./scripts/vault-bootstrap.sh all

# Opción 2: Bootstrap paso a paso (para debugging)
./scripts/vault-bootstrap.sh 1    # Fase 1: Infraestructura básica
./scripts/vault-bootstrap.sh 2    # Fase 2: Inicialización Vault
./scripts/vault-bootstrap.sh 3    # Fase 3: Configuración secretos
./scripts/vault-bootstrap.sh 4    # Fase 4: Aplicaciones
```

### 4. Verificar Estado

```bash
# Verificar estado completo
./scripts/vault-bootstrap.sh status

# Acceder a Vault UI
./scripts/vault-bootstrap.sh port-forward
# Luego abrir: http://localhost:8200/ui
```

## 📋 Comandos Principales

### 🔧 Gestión del Bootstrap

```bash
# Bootstrap completo
./scripts/vault-bootstrap.sh all

# Bootstrap por fases
./scripts/vault-bootstrap.sh 1|2|3|4

# Estado del sistema
./scripts/vault-bootstrap.sh status

# Logs de Vault
./scripts/vault-bootstrap.sh logs
```

### 🔐 Gestión de Vault

```bash
# Unseal manual (solo desarrollo)
./scripts/vault-bootstrap.sh unseal

# Port-forward para acceso local
./scripts/vault-bootstrap.sh port-forward

# Acceder a la UI
# http://localhost:8200/ui
```

### 🧪 Testing

```bash
# Test rápido
./scripts/test-vault-bootstrap.sh quick

# Test completo
./scripts/test-vault-bootstrap.sh full

# Test de fase específica
./scripts/test-vault-bootstrap.sh phase1

# Limpiar recursos de test
./scripts/test-vault-bootstrap.sh cleanup
```

## 📁 Estructura del Proyecto

```
blinkchamber/
├── terraform/
│   ├── phases/                    # Fases del bootstrap
│   │   ├── 01-bootstrap/         # Infraestructura básica
│   │   ├── 02-vault-init/        # Inicialización Vault
│   │   ├── 03-secrets/           # Configuración secretos
│   │   └── 04-applications/      # Aplicaciones con Vault
│   └── modules/                   # Módulos especializados
│       ├── vault-bootstrap/      # Bootstrap automático de Vault
│       ├── vault-secrets/        # Gestión de secretos
│       └── vault-integration/    # Integración con aplicaciones
├── scripts/
│   ├── vault-bootstrap.sh        # Script principal
│   ├── test-vault-bootstrap.sh   # Script de pruebas
│   └── lib/                      # Librerías comunes
├── config/
│   └── blinkchamber.yaml         # Configuración centralizada
└── data/
    └── vault/                    # Datos de Vault
```

## 🔐 Gestión de Secretos Profesional

### 🛡️ **Vault Agent Sidecar Architecture**

El sistema implementa el modelo profesional de gestión de secretos utilizando **Vault Agent Sidecar** con autenticación nativa de Kubernetes:

#### **Arquitectura de Seguridad**
```
┌─────────────────────────────────────────────────────────────────┐
│                    Pod de Aplicación                            │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   App Container │  │  Vault Agent    │  │  Init Container │ │
│  │                 │  │   Sidecar       │  │                 │ │
│  │ - Lee secretos  │  │ - Auth con K8s  │  │ - Espera        │ │
│  │   desde archivo │  │ - Descarga      │  │   secretos      │ │
│  │ - Sin acceso    │  │   secretos      │  │ - Bloquea       │ │
│  │   directo a     │  │ - Escribe a     │  │   arranque      │ │
│  │   Vault         │  │   archivo       │  │                 │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    HashiCorp Vault                              │
├─────────────────────────────────────────────────────────────────┤
│  - KV Secret Engine v2                                          │
│  - Kubernetes Auth Method                                       │
│  - Políticas granulares por aplicación                          │
│  - Auditoría completa de accesos                                │
└─────────────────────────────────────────────────────────────────┘
```

### 🔑 **Secretos Automáticos**

El sistema genera automáticamente secretos seguros para:

- **Database**: PostgreSQL admin y usuarios de aplicaciones
- **Identity**: Zitadel admin y configuración
- **Storage**: MinIO access/secret keys
- **Monitoring**: Grafana admin credentials
- **Mail**: Mailu SMTP y configuración de correo

### 🔐 **Acceso a Secretos**

```bash
# Configurar acceso a Vault
source data/vault/vault-env.sh

# Listar secretos
vault kv list secret/

# Leer secreto específico
vault kv get secret/database/postgres
vault kv get secret/identity/zitadel
vault kv get secret/storage/minio
vault kv get secret/monitoring/grafana
vault kv get secret/mail/mailu
```

### 🛡️ **Políticas de Seguridad Granulares**

Cada componente tiene políticas específicas con principio de mínimo privilegio:

- `database-policy`: Acceso solo a secretos de database
- `identity-policy`: Acceso a secretos de identity y database
- `storage-policy`: Acceso solo a secretos de storage
- `monitoring-policy`: Acceso solo a secretos de monitoring
- `mail-policy`: Acceso solo a secretos de correo

### 🔄 **Autenticación de Kubernetes**

Cada aplicación se autentica usando su ServiceAccount específico:

```yaml
# Ejemplo: Mailu con Vault Agent Sidecar
apiVersion: v1
kind: ServiceAccount
metadata:
  name: mailu-sa
  namespace: mail
---
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

### 🎯 **Ventajas del Modelo Profesional**

- **Seguridad Zero Trust**: Sin secretos estáticos en Kubernetes
- **Rotación Automática**: Secretos se rotan sin impacto en aplicaciones
- **Auditoría Granular**: Cada acceso a secretos se registra con contexto completo
- **Principio de Mínimo Privilegio**: Cada aplicación solo accede a sus secretos específicos
- **Cumplimiento**: Cumple con estándares de seguridad empresariales (SOC2, PCI-DSS, etc.)
- **Escalabilidad**: Fácil agregar nuevas aplicaciones sin modificar Vault
- **Resiliencia**: Recuperación automática de fallos de Vault

## 🌍 Configuración por Entorno

### Development (por defecto)

```bash
ENVIRONMENT=development ./scripts/vault-bootstrap.sh all
```

- Auto-unseal: Deshabilitado (Shamir secret sharing)
- Backup: Deshabilitado
- Audit: Habilitado
- Alta disponibilidad: Deshabilitada

### Staging

```bash
ENVIRONMENT=staging ./scripts/vault-bootstrap.sh all
```

- Auto-unseal: Transit secret engine
- Backup: Habilitado
- Audit: Habilitado
- Alta disponibilidad: Deshabilitada

### Production

```bash
ENVIRONMENT=production ./scripts/vault-bootstrap.sh all --auto-unseal awskms
```

- Auto-unseal: AWS KMS
- Backup: Habilitado
- Audit: Habilitado
- Alta disponibilidad: Habilitada

## 🔗 Acceso a Servicios

### URLs de Acceso

- **Vault UI**: http://localhost:8200/ui
- **Zitadel**: https://zitadel.blinkchamber.local
- **Grafana**: https://grafana.blinkchamber.local
- **MinIO**: https://minio.blinkchamber.local

### Configuración de DNS Local

```bash
# Agregar a /etc/hosts
echo "127.0.0.1 vault.blinkchamber.local" | sudo tee -a /etc/hosts
echo "127.0.0.1 zitadel.blinkchamber.local" | sudo tee -a /etc/hosts
echo "127.0.0.1 grafana.blinkchamber.local" | sudo tee -a /etc/hosts
echo "127.0.0.1 minio.blinkchamber.local" | sudo tee -a /etc/hosts
```

### Port-Forwarding

```bash
# Vault
kubectl port-forward svc/vault -n vault 8200:8200

# Grafana
kubectl port-forward svc/grafana -n monitoring 3000:3000

# MinIO
kubectl port-forward svc/minio -n storage 9000:9000 9001:9001
```

## 🛠️ Troubleshooting

### Problemas Comunes

1. **Vault sealed después de reinicio**
   ```bash
   ./scripts/vault-bootstrap.sh unseal
   ```

2. **Secretos no se inyectan**
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   kubectl logs <pod-name> -c vault-agent -n <namespace>
   ```

3. **Certificados TLS expirados**
   ```bash
   kubectl delete secret <tls-secret-name> -n <namespace>
   # Los certificados se regenerarán automáticamente
   ```

### Logs y Debugging

```bash
# Logs de Vault
kubectl logs -f deployment/vault -n vault

# Logs de Vault Agent (en pods de aplicaciones)
kubectl logs <pod-name> -c vault-agent -n <namespace>

# Estado de Vault
./scripts/vault-bootstrap.sh status

# Verificar conectividad
curl -s http://localhost:8200/v1/sys/health | jq
```

## 📊 Monitoreo

### Métricas de Vault

- **Endpoint**: http://localhost:8200/v1/sys/metrics
- **Prometheus**: Configurado automáticamente
- **Grafana**: Dashboards predefinidos

### Audit Logs

```bash
# Ver logs de auditoría
kubectl exec -it vault-0 -n vault -- cat /vault/audit/audit.log | jq
```

## 🔄 Backup y Restauración

### Backup Automático

```bash
# Configurar backup (solo en staging/production)
vault write sys/storage/raft/snapshot
```

### Restauración Manual

```bash
# Restaurar desde snapshot
vault write sys/storage/raft/snapshot-restore @snapshot.snap
```

## 🤝 Contribución

### Desarrollo

```bash
# Ejecutar tests
./scripts/test-vault-bootstrap.sh full

# Verificar sintaxis Terraform
terraform fmt -recursive terraform/
terraform validate terraform/phases/*/
```

### Estructura de Commits

```
feat: nueva funcionalidad
fix: corrección de bug
docs: documentación
test: pruebas
refactor: refactorización
```

## 📜 Licencia

MIT License - ver [LICENSE](LICENSE) para más detalles.

## 🆘 Soporte

- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
- **Documentation**: [docs/](docs/)

---

> **Nota**: Este sistema está diseñado para ser completamente automático. Si encuentras algún problema durante el bootstrap, revisa los logs y utiliza las herramientas de troubleshooting incluidas. 