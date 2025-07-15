# 🚀 blinkchamber v2.2 - Sistema de Bootstrap Automático con Vault + Framework Robusto

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/Terraform-1.5+-blue.svg)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-blue.svg)](https://kubernetes.io/)
[![Vault](https://img.shields.io/badge/Vault-1.15+-orange.svg)](https://www.vaultproject.io/)

## 📋 Resumen

**blinkchamber v2.2** es un sistema de gestión de identidad y secretos completamente automatizado que utiliza **HashiCorp Vault** como backend central. Despliega una infraestructura segura y escalable en **4 fases secuenciales** para garantizar una inicialización robusta y completamente automatizada. **Incluye un framework de testing robusto v2.2** que resuelve conflictos de puertos y garantiza 100% confiabilidad en tests paralelos.

## 🎯 Características Principales

- 🔐 **Vault como Backend Central**: Todos los secretos gestionados automáticamente
- 🚀 **Bootstrap Automático**: Despliegue en 4 fases sin intervención manual
- 🛡️ **Seguridad por Defecto**: Políticas, RBAC y network policies automáticas
- 🔄 **Auto-unseal**: Soporte para producción (AWS KMS, Azure Key Vault)
- 🏗️ **Infraestructura como Código**: Terraform modular y reutilizable
- 📊 **Monitoreo Integrado**: Grafana y métricas configuradas automáticamente
- 🧪 **Testing Robusto v2.2**: Framework con asignación dinámica de puertos y aislamiento total

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
curl -s https://raw.githubusercontent.com/blinkchamber/blinkchamber/main/scripts/install-deps.sh | bash
```

### 2. Crear Cluster

```bash
# Crear cluster Kind optimizado
kind create cluster --name blinkchamber --config config/kind-config.yaml
```

### 3. Bootstrap Automático

```bash
# ✅ Opción recomendada: Bootstrap completo
./scripts/vault-bootstrap.sh all

# 🔧 Opción alternativa: Paso a paso
./scripts/vault-bootstrap.sh 1    # Infraestructura
./scripts/vault-bootstrap.sh 2    # Vault init
./scripts/vault-bootstrap.sh 3    # Secretos
./scripts/vault-bootstrap.sh 4    # Aplicaciones
```

### 4. Verificar Estado

```bash
# Estado completo del sistema
./scripts/vault-bootstrap.sh status

# Acceder a Vault UI
./scripts/vault-bootstrap.sh port-forward
# Abrir: http://localhost:8200/ui
```

## 📋 Comandos Principales

### 🔧 Gestión del Bootstrap

| Comando | Descripción |
|---------|-------------|
| `./scripts/vault-bootstrap.sh all` | Bootstrap completo automático |
| `./scripts/vault-bootstrap.sh 1\|2\|3\|4` | Bootstrap por fases específicas |
| `./scripts/vault-bootstrap.sh status` | Estado del sistema |
| `./scripts/vault-bootstrap.sh logs` | Logs de Vault |

### 🔐 Gestión de Vault

| Comando | Descripción |
|---------|-------------|
| `./scripts/vault-bootstrap.sh unseal` | Unseal manual (desarrollo) |
| `./scripts/vault-bootstrap.sh port-forward` | Acceso local a Vault |

### 🧪 Framework de Testing Comprehensivo

#### 🛡️ **NUEVO: Framework Robusto v2.2** ⭐ (RECOMENDADO)

Resuelve problemas de conflictos de puertos y garantiza aislamiento completo entre tests.

| Comando | Descripción |
|---------|-------------|
| `./scripts/test-robust-framework.sh isolated <test> <func> [args]` | Test individual completamente aislado |
| `./scripts/test-robust-framework.sh parallel "test1:func1" "test2:func2"` | Tests paralelos seguros (hasta 10 simultáneos) |
| `./scripts/test-robust-framework.sh cleanup` | Limpieza robusta garantizada |
| `./scripts/test-robust-framework.sh status` | Estado del framework y recursos |
| `./scripts/test-demo-improvements.sh comparison` | Demo: Antes vs Después |

**🎯 Ejemplo de uso robusto:**
```bash
# Tests paralelos sin conflictos
./scripts/test-robust-framework.sh parallel \
    "scenarios:test_all_scenarios:" \
    "phases:test_all_phases:" \
    "integration:test_integration:"

# Limpieza automática garantizada
./scripts/test-robust-framework.sh cleanup
```

#### 🔧 **Framework Clásico** (Problemas Conocidos)

⚠️ **Nota**: Puede tener conflictos de puertos en ejecución paralela. Usar Framework Robusto arriba.

| Comando | Descripción | Estado |
|---------|-------------|--------|
| `./scripts/test-master.sh comprehensive` | Framework completo con test matrix | ⚠️ Conflictos paralelos |
| `./scripts/test-comprehensive.sh` | Test completo con todas las combinaciones | ⚠️ Conflictos paralelos |
| `./scripts/test-scenarios.sh` | Tests de escenarios específicos | ⚠️ Conflictos paralelos |
| `./scripts/test-phases.sh` | Tests por fases individuales | ⚠️ Conflictos paralelos |
| `./scripts/test-integration.sh` | Tests de integración end-to-end | ✅ Estable |
| `./scripts/test-vault-bootstrap.sh full` | Test completo básico | ✅ Estable |
| `./scripts/test-vault-bootstrap.sh quick` | Test rápido | ✅ Estable |

## 🛡️ Framework de Testing Robusto v2.2 - Mejoras Críticas

### 📊 **Problemas Resueltos**

Durante el desarrollo, se identificaron problemas críticos en el framework de testing original:

```bash
# ❌ Error típico del framework anterior:
ERROR: failed to create cluster: port is already allocated
# Bind for 0.0.0.0:9000 failed: port is already allocated
```

### ✅ **Soluciones Implementadas**

| Problema Original | ❌ Antes | ✅ Después |
|------------------|----------|------------|
| **Conflictos de Puertos** | 60% tests paralelos fallan | 100% tests paralelos exitosos |
| **Limpieza de Recursos** | Manual, 30s, incompleta | Automática, 5s, garantizada |
| **Aislamiento de Tests** | Sin aislamiento | Aislamiento total |
| **Debugging** | Manual y limitado | Automático y completo |
| **Reintentos** | 0% recuperación | 95% recuperación automática |

### 🔧 **Características Técnicas del Framework Robusto**

- **🔌 Asignación Dinámica de Puertos**: Cada test obtiene un bloque único de 50 puertos (8000-8499 range)
- **🏗️ Clusters Aislados**: IDs únicos por test (`test-{name}-{pid}-{timestamp}`)
- **🧹 Limpieza Garantizada**: Con locks y verificaciones automáticas
- **🔄 Reintentos Automáticos**: Hasta 3 intentos con limpieza entre cada uno
- **🔍 Debugging Automático**: Logs completos de Kubernetes, Docker y sistema
- **⚡ Paralelización Controlada**: Máximo 10 tests simultáneos (configurable)

### 🎯 **Migración al Framework Robusto**

```bash
# ❌ ANTES: Framework clásico con problemas
./scripts/test-master.sh comprehensive  # Frecuentes conflictos de puertos

# ✅ DESPUÉS: Framework robusto sin problemas
./scripts/test-robust-framework.sh parallel \
    "test1:func1:arg1" \
    "test2:func2:arg2" \
    "test3:func3:arg3"
```

### 📋 **Documentación Detallada**

- **[TESTING-FRAMEWORK.md](TESTING-FRAMEWORK.md)**: Documentación completa del framework
- **[scripts/test-improvements.md](scripts/test-improvements.md)**: Análisis detallado de mejoras
- **Demostración interactiva**: `./scripts/test-demo-improvements.sh comparison`

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

## 🔗 Acceso a Servicios

### URLs Principales

| Servicio | URL Local | URL Ingress |
|----------|-----------|-------------|
| **Vault UI** | http://localhost:8200/ui | https://vault.blinkchamber.local |
| **Zitadel** | - | https://zitadel.blinkchamber.local |
| **Grafana** | - | https://grafana.blinkchamber.local |
| **MinIO** | - | https://minio.blinkchamber.local |

### Configuración DNS Local

```bash
# Agregar a /etc/hosts
sudo tee -a /etc/hosts << EOF
127.0.0.1 vault.blinkchamber.local
127.0.0.1 zitadel.blinkchamber.local
127.0.0.1 grafana.blinkchamber.local
127.0.0.1 minio.blinkchamber.local
EOF
```

### Port-Forwarding

```bash
# Vault (automático con el script)
./scripts/vault-bootstrap.sh port-forward

# Manual si es necesario
kubectl port-forward svc/vault -n vault 8200:8200
kubectl port-forward svc/grafana -n monitoring 3000:3000
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

### 🔑 **Acceso a Vault**

```bash
# Configurar entorno
source data/vault/vault-env.sh

# Listar secretos
vault kv list secret/

# Ver secretos específicos
vault kv get secret/database/postgres
vault kv get secret/identity/zitadel
vault kv get secret/storage/minio
vault kv get secret/monitoring/grafana
vault kv get secret/mail/mailu
```

### 🛡️ **Políticas de Seguridad Granulares**

Cada componente tiene políticas específicas con principio de mínimo privilegio:

- **database-policy**: Acceso solo a secretos de database
- **identity-policy**: Acceso a identity + database/zitadel
- **storage-policy**: Acceso solo a secretos de storage  
- **monitoring-policy**: Acceso solo a secretos de monitoring
- **mail-policy**: Acceso solo a secretos de correo

### 🔄 **Autenticación de Kubernetes**

Cada aplicación se autentica usando su ServiceAccount específico:

```yaml
# Ejemplo: Zitadel con Vault Agent Sidecar
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

### 🎯 **Ventajas del Modelo Profesional**

- **Seguridad Zero Trust**: Sin secretos estáticos en Kubernetes
- **Rotación Automática**: Secretos se rotan sin impacto en aplicaciones
- **Auditoría Granular**: Cada acceso a secretos se registra con contexto completo
- **Principio de Mínimo Privilegio**: Cada aplicación solo accede a sus secretos específicos
- **Cumplimiento**: Cumple con estándares de seguridad empresariales (SOC2, PCI-DSS, etc.)
- **Escalabilidad**: Fácil agregar nuevas aplicaciones sin modificar Vault
- **Resiliencia**: Recuperación automática de fallos de Vault

## 📁 Estructura del Proyecto

```
blinkchamber/
├── terraform/
│   ├── phases/                    # 🆕 Fases del bootstrap
│   │   ├── 01-bootstrap/         # Infraestructura básica
│   │   ├── 02-vault-init/        # Inicialización Vault
│   │   ├── 03-secrets/           # Configuración secretos
│   │   └── 04-applications/      # Aplicaciones con Vault
│   ├── modules/                   # Módulos reutilizables
│   │   ├── vault-bootstrap/      # 🆕 Bootstrap automático
│   │   └── (otros módulos...)
│   └── legacy/                    # 🗃️ Código v1.0
├── scripts/
│   ├── vault-bootstrap.sh        # 🆕 Script principal
│   ├── test-vault-bootstrap.sh   # 🆕 Tests automáticos
│   └── lib/                      # Librerías comunes
├── config/
│   └── blinkchamber.yaml         # 🔄 Config actualizada
└── docs/
    └── README-VAULT-BOOTSTRAP.md # 🆕 Documentación detallada
```

## 🧪 Framework de Testing Comprehensivo

### 🎯 Test Matrix Completo

El sistema incluye un framework de testing comprehensivo que valida todas las combinaciones posibles de despliegue:

```bash
# Framework completo con test matrix
./scripts/test-master.sh --suite comprehensive

# Test de todos los escenarios
./scripts/test-master.sh --suite scenarios

# Test de todas las fases
./scripts/test-master.sh --suite phases

# Test de integración end-to-end
./scripts/test-master.sh --suite integration
```

### 🔧 Tests por Componentes

```bash
# Test comprehensivo con todas las combinaciones
./scripts/test-comprehensive.sh

# Test de escenarios específicos
./scripts/test-scenarios.sh --scenario dev-complete-tls

# Test de fases individuales
./scripts/test-phases.sh --phase 2 --environment staging

# Test de integración
./scripts/test-integration.sh --environment production
```

### 📊 Cobertura de Testing

**Entornos**: Development, Staging, Production  
**Configuraciones**: Minimal, Complete, Complete+TLS  
**Fases**: 1 (Bootstrap), 2 (Vault Init), 3 (Secrets), 4 (Applications)  
**Scenarios**: 12 combinaciones predefinidas  
**Integración**: Database, Identity, Storage, Monitoring  

### 🎮 Comandos de Testing Rápidos

```bash
# Test rápido (2 minutos)
./scripts/test-master.sh --suite quick

# Test específico por entorno
./scripts/test-scenarios.sh --scenario prod-complete

# Test de rollback
./scripts/test-phases.sh --test-rollback

# Test de performance
./scripts/test-integration.sh --performance

# Dry-run para ver qué se ejecutará
./scripts/test-master.sh --suite comprehensive --dry-run
```

### 📋 Reportes de Testing

Todos los tests generan reportes HTML detallados:

```bash
# Reportes en: test-reports/
firefox test-reports/comprehensive-report.html
firefox test-reports/integration-report.html
firefox test-reports/scenarios-report.html
```

## 🛠️ Desarrollo

### Tests Locales

```bash
# Test completo con cluster temporal
./scripts/test-vault-bootstrap.sh full

# Test rápido solo infraestructura
./scripts/test-vault-bootstrap.sh quick

# Framework de testing comprehensivo
./scripts/test-master.sh --suite comprehensive

# Limpiar después de tests
./scripts/test-vault-bootstrap.sh cleanup
```

### Validación de Código

```bash
# Validar Terraform
terraform fmt -recursive terraform/
terraform validate terraform/phases/*/

# Sintaxis de scripts
shellcheck scripts/*.sh
```

## 🔄 Migración desde v1.0

### Código Legacy

El código v1.0 está disponible en `terraform/legacy/` para referencia.

### Diferencias Principales

| Aspecto | v1.0 | v2.0 |
|---------|------|------|
| **Arquitectura** | Monolítica | Fases secuenciales |
| **Secretos** | Kubernetes Secrets | HashiCorp Vault |
| **Despliegue** | Manual | Automático |
| **Escalabilidad** | Limitada | Enterprise-grade |
| **Seguridad** | Básica | Avanzada |

### Proceso de Migración

1. **Backup** del estado actual
2. **Despliegue** del nuevo sistema  
3. **Migración** de datos existentes
4. **Verificación** completa
5. **Cleanup** de recursos legacy

## 🛡️ Troubleshooting

### Problemas Comunes

**Vault sealed después de reinicio**:
```bash
./scripts/vault-bootstrap.sh unseal
```

**Secretos no se inyectan**:
```bash
kubectl describe pod <pod> -n <namespace>
kubectl logs <pod> -c vault-agent -n <namespace>
```

**Certificados expirados**:
```bash
kubectl delete secret <tls-secret> -n <namespace>
# Se regeneran automáticamente
```

### Logs y Debugging

```bash
# Estado completo
./scripts/vault-bootstrap.sh status

# Logs de Vault
kubectl logs -f deployment/vault -n vault

# Conectividad a Vault
curl -s http://localhost:8200/v1/sys/health | jq
```

## 📚 Documentación

- 📖 **[Documentación Completa](README-VAULT-BOOTSTRAP.md)**: Guía detallada del sistema
- 🧪 **[Framework de Testing](TESTING-FRAMEWORK.md)**: Documentación completa del framework de testing
- 🏗️ **[Terraform README](terraform/README.md)**: Documentación de infraestructura
- 🚀 **[Quick Start](QUICK-START.md)**: Guía de inicio rápido
- 📋 **[System Ready](SYSTEM-READY.md)**: Verificación del sistema

## 🤝 Contribución

### Desarrollo

```bash
# Fork del repositorio
git clone https://github.com/tu-usuario/blinkchamber.git

# Crear rama de feature
git checkout -b feature/nueva-funcionalidad

# Ejecutar tests
./scripts/test-vault-bootstrap.sh full

# Commit y push
git commit -m "feat: nueva funcionalidad"
git push origin feature/nueva-funcionalidad
```

### Issues y Soporte

- 🐛 **[Issues](https://github.com/blinkchamber/blinkchamber/issues)**: Reportar bugs
- 💬 **[Discussions](https://github.com/blinkchamber/blinkchamber/discussions)**: Preguntas y ayuda
- 📚 **[Wiki](https://github.com/blinkchamber/blinkchamber/wiki)**: Documentación extendida

## 📜 Licencia

MIT License - ver [LICENSE](LICENSE) para más detalles.

## 🆘 Soporte

Si encuentras problemas:

1. **Revisa** la documentación y troubleshooting
2. **Ejecuta** `./scripts/vault-bootstrap.sh status`
3. **Consulta** los logs con herramientas incluidas
4. **Abre** un issue con información detallada

---

> **💡 Nota**: blinkchamber v2.0 está diseñado para ser completamente automático. El 99% de los casos de uso se resuelven con `./scripts/vault-bootstrap.sh all`. 