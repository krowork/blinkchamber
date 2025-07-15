# 🏗️ Terraform - blinkchamber v2.0

## 📋 Resumen

Esta es la infraestructura como código de **blinkchamber v2.0**, completamente rediseñada para usar **HashiCorp Vault** como backend central de secretos con un sistema de **bootstrap automático en 4 fases**.

## 🗂️ Estructura del Directorio

```
terraform/
├── phases/                    # Fases del bootstrap automático
│   ├── 01-bootstrap/         # Fase 1: Infraestructura básica
│   ├── 02-vault-init/        # Fase 2: Inicialización de Vault
│   ├── 03-secrets/           # Fase 3: Configuración de secretos
│   └── 04-applications/      # Fase 4: Aplicaciones con Vault
├── modules/                   # Módulos reutilizables
│   ├── vault-bootstrap/      # Módulo especializado para Vault
│   ├── cert-manager/         # Gestión de certificados TLS
│   ├── database/             # PostgreSQL con integración Vault
│   ├── identity/             # Zitadel con secretos de Vault
│   ├── ingress/              # Nginx Ingress Controller
│   ├── kubernetes-base/      # Configuración base de K8s
│   ├── storage/              # MinIO con credenciales de Vault
│   └── vault/                # Vault (legacy - usar vault-bootstrap)
└── legacy/                   # Código de la versión anterior
    ├── main-v1.tf           # Configuración monolítica v1.0
    └── README-v1.md         # Documentación v1.0
```

## 🚀 Uso Recomendado

### ❌ NO usar directamente

```bash
# ❌ NO hagas esto (era la forma antigua)
cd terraform/
terraform apply
```

### ✅ Usar el script de bootstrap

```bash
# ✅ Forma correcta (nueva)
./scripts/vault-bootstrap.sh all
```

## 🔄 Fases de Despliegue

### Fase 1: Bootstrap Básico (`phases/01-bootstrap/`)

**Descripción**: Infraestructura básica sin secretos

**Componentes**:
- `kubernetes-base`: Configuración base del cluster
- `ingress`: Nginx Ingress Controller
- `cert-manager`: Gestión automática de certificados
- `vault-infrastructure`: Vault (solo pods, sin inicialización)

**Ejecutar**:
```bash
./scripts/vault-bootstrap.sh 1
```

### Fase 2: Inicialización de Vault (`phases/02-vault-init/`)

**Descripción**: Inicialización automática y configuración de auth

**Componentes**:
- Job de inicialización automática
- Configuración de Kubernetes Authentication
- Políticas básicas de seguridad
- Auto-unseal (según entorno)

**Ejecutar**:
```bash
./scripts/vault-bootstrap.sh 2
```

### Fase 3: Configuración de Secretos (`phases/03-secrets/`)

**Descripción**: Poblado de secretos y configuración de políticas

**Componentes**:
- KV Secret Engine v2
- Secretos para todas las aplicaciones
- Políticas granulares por componente
- Roles de Kubernetes

**Ejecutar**:
```bash
./scripts/vault-bootstrap.sh 3
```

### Fase 4: Aplicaciones (`phases/04-applications/`)

**Descripción**: Despliegue de aplicaciones con integración Vault

**Componentes**:
- PostgreSQL con Vault Injector
- Zitadel con secretos de Vault
- MinIO con credenciales de Vault
- Grafana con configuración de Vault

**Ejecutar**:
```bash
./scripts/vault-bootstrap.sh 4
```

## 🔧 Módulos Especializados

### `vault-bootstrap/`

Módulo especializado para el despliegue y configuración automática de Vault.

**Características**:
- Despliegue solo de infraestructura o completo
- Soporte para auto-unseal en múltiples proveedores
- Configuración automática de auth de Kubernetes
- Políticas de seguridad integradas

**Uso**:
```hcl
module "vault_bootstrap" {
  source = "../../modules/vault-bootstrap"
  
  deploy_only_infrastructure = true  # Solo infra en fase 1
  auto_init                  = false # Sin init en fase 1
  
  auto_unseal = {
    enabled = false
    method  = "shamir"
    config  = {}
  }
}
```

### Otros Módulos

Los módulos existentes han sido **actualizados** para trabajar con **Vault como backend de secretos**:

- `database/`: PostgreSQL con integración Vault
- `identity/`: Zitadel usando secretos de Vault
- `storage/`: MinIO con credenciales de Vault
- `ingress/`: Nginx con certificados automáticos
- `cert-manager/`: Gestión de certificados TLS

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

### 🔑 **Backend Centralizado**

Todos los secretos se gestionan centralmente en **Vault**:

```
secret/
├── data/
│   ├── database/
│   │   ├── postgres      # Credenciales PostgreSQL
│   │   └── zitadel       # Credenciales DB para Zitadel
│   ├── identity/
│   │   └── zitadel       # Configuración Zitadel
│   ├── storage/
│   │   └── minio         # Credenciales MinIO
│   ├── monitoring/
│   │   ├── grafana       # Credenciales Grafana
│   │   └── prometheus    # Credenciales Prometheus
│   └── mail/
│       └── mailu         # Configuración Mailu
```

### 🛡️ **Políticas de Seguridad Granulares**

Cada componente tiene políticas específicas con principio de mínimo privilegio:

```hcl
# database-policy: Solo acceso a secretos de database
# identity-policy: Acceso a identity + database/zitadel
# storage-policy: Solo acceso a secretos de storage
# monitoring-policy: Solo acceso a secretos de monitoring
# mail-policy: Solo acceso a secretos de correo
```

### 🔄 **Autenticación de Kubernetes**

Los pods se configuran automáticamente con ServiceAccounts específicos y Vault Agent Sidecar:

```yaml
# Ejemplo de configuración automática
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

### Development (Local)

```bash
ENVIRONMENT=development ./scripts/vault-bootstrap.sh all
```

- **Auto-unseal**: Deshabilitado (Shamir)
- **Backup**: Deshabilitado
- **HA**: Deshabilitado

### Staging

```bash
ENVIRONMENT=staging ./scripts/vault-bootstrap.sh all
```

- **Auto-unseal**: Transit Engine
- **Backup**: Habilitado
- **HA**: Deshabilitado

### Production

```bash
ENVIRONMENT=production ./scripts/vault-bootstrap.sh all --auto-unseal awskms
```

- **Auto-unseal**: AWS KMS
- **Backup**: Habilitado
- **HA**: Habilitado

## 🛠️ Desarrollo y Testing

### Validación

```bash
# Validar sintaxis
terraform fmt -recursive .
terraform validate phases/*/

# Test de configuración
./scripts/test-vault-bootstrap.sh quick
```

### Debugging

```bash
# Ver estado de fases
./scripts/vault-bootstrap.sh status

# Ver outputs de una fase específica
cd phases/01-bootstrap/
terraform output

# Ver logs
kubectl logs -f deployment/vault -n vault
```

## 📊 Outputs y Estado

Cada fase proporciona outputs para la siguiente:

```hcl
# Fase 1 → Fase 2
output "next_phase" {
  value = {
    phase = 2
    vault_endpoint = "..."
    prerequisites_met = true
  }
}
```

## 🔄 Migración desde v1.0

### Código Legacy

El código anterior está disponible en `legacy/` para referencia:

```
legacy/
├── main-v1.tf      # Configuración monolítica anterior
└── README-v1.md    # Documentación v1.0
```

### Diferencias Principales

| Aspecto | v1.0 | v2.0 |
|---------|------|------|
| Arquitectura | Monolítica | Fases secuenciales |
| Secretos | Kubernetes Secrets | HashiCorp Vault |
| Despliegue | Manual | Automático |
| Escalabilidad | Limitada | Alta |
| Seguridad | Básica | Enterprise-grade |

### Proceso de Migración

1. **Backup** de estado actual
2. **Ejecutar** nuevo bootstrap
3. **Migrar** secretos existentes a Vault
4. **Verificar** funcionamiento
5. **Eliminar** recursos legacy

## 📜 Licencia

MIT License - ver [LICENSE](../LICENSE) para más detalles.

---

> **Nota**: Esta infraestructura está diseñada para ser gestionada a través de los scripts de bootstrap. No ejecutes Terraform directamente a menos que sepas exactamente lo que estás haciendo. 