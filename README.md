# 🚀 BlinkChamber Platform - Arquitectura de Alta Disponibilidad

Este proyecto contiene un **chart umbrella de Helm** que despliega una arquitectura completa de alta disponibilidad con ZITADEL, HashiCorp Vault y PostgreSQL en Kubernetes, con gestión segura de secretos mediante Vault Injector.

## 🎯 ¿Qué incluye?

### 📦 Componentes de la Plataforma:

1. **🔐 Cert-Manager** - Gestión automática de certificados TLS
2. **🌐 Nginx-Ingress** - Controlador de ingress para Kubernetes  
3. **🗄️ Vault HA** - Gestión de secretos con alta disponibilidad (3 réplicas)
4. **🐘 PostgreSQL HA** - Base de datos de alta disponibilidad (3 réplicas + 2 PgPool)
5. **🔴 Redis HA** - Cache y sesiones de alta disponibilidad (3 master + 3 réplicas + 3 Sentinel)
6. **🆔 ZITADEL** - Plataforma de identidad y autenticación con Event Streaming (2+ réplicas)

### 🔧 Características:

- **Chart Umbrella** - Gestión unificada de todos los componentes
- **Vault Injector** - Gestión segura de secretos sin Kubernetes secrets
- **Alta Disponibilidad** - Todos los componentes críticos con múltiples réplicas
- **Event Streaming** - Publicación eficiente de eventos en colas Redis con prioridades
- **Despliegue Simplificado** - Un solo comando para toda la plataforma

## 🚀 Despliegue Rápido

### 1. Crear clúster Kind (opcional):

```bash
./create-kind-cluster.sh
```

### 2. Instalar la plataforma completa:

```bash
./deploy-umbrella.sh install
```

### 3. Verificar el estado:

```bash
./deploy-umbrella.sh status
```

## 📋 Comandos Disponibles

| Comando | Descripción |
|---------|-------------|
| `install` | Instalar la plataforma completa |
| `upgrade` | Actualizar la plataforma |
| `uninstall` | Desinstalar la plataforma |
| `status` | Ver estado de todos los componentes |
| `logs` | Ver logs de todos los componentes |
| `help` | Mostrar ayuda |

## 🔧 Configuración

### Personalizar valores:

Edita el archivo `values.yaml` para ajustar la configuración:

```yaml
# Habilitar/deshabilitar componentes
cert-manager:
  enabled: true

vault:
  enabled: true
  server:
    ha:
      replicas: 3  # Número de réplicas de Vault

zitadel:
  enabled: true
  replicaCount: 2  # Número de réplicas de ZITADEL
```

### Configuración por entorno:

```bash
# Desarrollo
helm upgrade --install blinkchamber . -f values.yaml -f values-dev.yaml

# Producción  
helm upgrade --install blinkchamber . -f values.yaml -f values-prod.yaml
```

## 🔐 Configuración Post-Despliegue

### 1. Inicializar Vault:

```bash
# Inicializar Vault (guarda las claves de desello)
kubectl exec -n blinkchamber vault-0 -- vault operator init

# Desellar Vault (necesitarás las claves del paso anterior)
kubectl exec -n blinkchamber vault-0 -- vault operator unseal
```

### 2. Configurar autenticación de Kubernetes:

```bash
# Habilitar auth de Kubernetes
kubectl exec -n blinkchamber vault-0 -- vault auth enable kubernetes

# Configurar policies (usando los ConfigMaps creados)
kubectl exec -n blinkchamber vault-0 -- vault policy write postgres-policy /tmp/postgres-policy.hcl
kubectl exec -n blinkchamber vault-0 -- vault policy write zitadel-policy /tmp/zitadel-policy.hcl
```

### 3. Crear secretos en Vault:

```bash
# Secretos para PostgreSQL
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/postgres password="tu-password-seguro"

# Secretos para Redis
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/redis password="tu-password-redis"

# Secretos para ZITADEL
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/zitadel/postgres password="tu-password-zitadel"
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/zitadel/vault token="tu-token-vault"
```

## 🌐 Acceso a Servicios

| Servicio | URL | Descripción |
|----------|-----|-------------|
| Vault UI | `https://vault.blinkchamber.svc:8200` | Interfaz web de Vault |
| ZITADEL | `https://zitadel.tu-dominio.com` | Plataforma de identidad |
| PostgreSQL | `postgresql-ha-postgresql.database.svc:5432` | Base de datos |
| Redis | `redis-master.database.svc:6379` | Cache y sesiones |

## 📊 Monitorización

### Ver estado general:

```bash
kubectl get pods -A -l app.kubernetes.io/part-of=blinkchamber-platform
```

### Logs específicos:

```bash
# Logs de Vault
kubectl logs -n blinkchamber -l app.kubernetes.io/name=vault

# Logs de ZITADEL
kubectl logs -n identity -l app.kubernetes.io/name=zitadel

# Logs de PostgreSQL
kubectl logs -n database -l app.kubernetes.io/name=postgresql-ha
```

## 🚀 Event Streaming

### 📊 Configuración de Eventos

ZITADEL está configurado para publicar eventos en colas Redis con diferentes prioridades:

```yaml
zitadel:
  config:
    events:
      enabled: true
      publishing:
        batchSize: 100
        batchTimeout: 1s
        compression: true
      queues:
        high_priority: "zitadel:events:high"     # Auth events
        normal_priority: "zitadel:events:normal"  # CRUD events
        low_priority: "zitadel:events:low"       # Analytics events
```

### 🎯 Tipos de Eventos

- **High Priority**: `auth.login`, `auth.logout`, `auth.failed`
- **Normal Priority**: `user.created`, `org.created`, `project.created`
- **Low Priority**: `user.profile_viewed`, `analytics.page_viewed`

### 📈 Monitorización de Eventos

```bash
# Ver eventos en colas
kubectl exec -n database redis-master-0 -- redis-cli LRANGE zitadel:events:high 0 -1

# Ver métricas de eventos
kubectl exec -n identity zitadel-0 -- curl -s localhost:8080/metrics | grep event

# Monitorizar rendimiento
kubectl exec -n database redis-master-0 -- redis-cli info stats
```

## 🔄 Actualizaciones

### Actualizar dependencias:

```bash
helm dependency update
```

### Actualizar la plataforma:

```bash
./deploy-umbrella.sh upgrade
```

## 🗑️ Desinstalación

```bash
./deploy-umbrella.sh uninstall
```

**⚠️ Advertencia**: Esto eliminará todos los datos. Asegúrate de hacer backup antes.

## 📁 Estructura del Proyecto

```
.
├── Chart.yaml              # Metadatos y dependencias del chart umbrella
├── values.yaml             # Configuración principal
├── deploy-umbrella.sh      # Script de despliegue simplificado
├── create-kind-cluster.sh  # Script para crear clúster Kind
├── templates/
│   ├── namespaces.yaml     # Namespaces necesarios
│   ├── vault-policies.yaml # Policies y roles de Vault
│   ├── postgresql-entrypoint-configmap.yaml # Entrypoint para PostgreSQL
│   └── notes.txt           # Notas post-instalación
├── tests/                  # Pruebas BATS
└── charts/                 # Subcharts descargados automáticamente
```

## 🔧 Troubleshooting

### Problemas comunes:

1. **Vault no se inicializa**: Verifica que el pod esté corriendo y ejecuta `vault operator init`
2. **PostgreSQL no arranca**: Verifica que Vault esté desellado y los secretos estén creados
3. **ZITADEL no se conecta**: Verifica la configuración de la base de datos y los tokens de Vault

### Logs de debug:

```bash
# Ver todos los eventos
kubectl get events -A --sort-by='.lastTimestamp'

# Ver logs detallados
kubectl logs -n blinkchamber vault-0 --previous
```

## 🧪 Pruebas

Para ejecutar las pruebas de BATS:

```bash
bats tests/test_exhaustive.bats
```

## 📚 Documentación

- [Documentación detallada del Chart Umbrella](README-UMBRELLA.md)
- [Arquitectura detallada](arquitectura_ha_zitadel_vault.md)
- [Integración Redis-ZITADEL](REDIS-ZITADEL-INTEGRATION.md)
- [Resumen de integración Redis](REDIS-INTEGRATION-SUMMARY.md)
- [Configuración de Vault](https://www.vaultproject.io/docs)
- [Documentación de ZITADEL](https://zitadel.com/docs)

## 🤝 Contribuir

1. Fork el repositorio
2. Crea una rama para tu feature
3. Commit tus cambios
4. Push a la rama
5. Abre un Pull Request

---

**🎉 ¡Disfruta de tu plataforma de alta disponibilidad!**
