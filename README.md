# BlinkChamber Platform

Plataforma completa de alta disponibilidad con ZITADEL, Vault, PostgreSQL, Redis, sistema de almacenamiento distribuido para videos y **stack completo de observabilidad**.

## Características Principales

- **Identidad y Autenticación**: ZITADEL para gestión completa de identidades
- **Gestión de Secretos**: HashiCorp Vault con inyección automática
- **Base de Datos**: PostgreSQL HA con replicación
- **Cache**: Redis con arquitectura de replicación
- **Email**: Sistema completo Mailu con SMTP/IMAP
- **Storage Distribuido**: Longhorn para almacenamiento de videos
- **Ingress**: NGINX Ingress Controller
- **Certificados**: Cert-Manager para TLS automático
- **Observabilidad**: **Stack completo de monitoreo y logging**

## Almacenamiento de Videos con Longhorn

### ¿Por qué Longhorn?

Para el almacenamiento de gran cantidad de videos de 2 minutos, Longhorn proporciona:

- **Almacenamiento distribuido**: Los videos se replican automáticamente entre nodos
- **Alta disponibilidad**: 3 réplicas por defecto para máxima redundancia
- **Escalabilidad**: Volúmenes que pueden expandirse dinámicamente
- **Sin dependencias externas**: Funciona completamente on-premise
- **Gestión visual**: UI integrada para monitoreo de volúmenes

### Configuración de Volúmenes

El sistema crea automáticamente 3 tipos de volúmenes:

1. **video-uploads-pvc**: Para videos recién subidos (100Gi - 1Ti)
2. **video-processed-pvc**: Para videos procesados (500Gi - 5Ti)
3. **video-cache-pvc**: Para cache de transcodificación (50Gi - 500Gi)

### Estimación de Capacidad

Para videos de 2 minutos:
- **Calidad estándar (720p)**: ~50MB por video
- **Calidad alta (1080p)**: ~150MB por video
- **Calidad ultra (4K)**: ~500MB por video

Con 1TB de almacenamiento puedes almacenar:
- ~20,000 videos en 720p
- ~6,600 videos en 1080p
- ~2,000 videos en 4K

## 🎯 ¿Qué incluye?

### 📦 Componentes de la Plataforma:

1. **🔐 Cert-Manager** - Gestión automática de certificados TLS
2. **🌐 Nginx-Ingress** - Controlador de ingress para Kubernetes  
3. **🗄️ Vault HA** - Gestión de secretos con alta disponibilidad (3 réplicas)
4. **🐘 PostgreSQL HA** - Base de datos de alta disponibilidad (3 réplicas + 2 PgPool)
5. **🔴 Redis HA** - Cache y sesiones de alta disponibilidad (3 master + 3 réplicas + 3 Sentinel)
6. **🆔 ZITADEL** - Plataforma de identidad y autenticación con Event Streaming (2+ réplicas)
7. **📧 Mailu** - Sistema completo de email (SMTP, IMAP, Webmail) con alta disponibilidad
8. **📊 Prometheus** - Recolección y almacenamiento de métricas
9. **📈 Grafana** - Visualización de métricas y logs
10. **📝 Loki** - Almacenamiento centralizado de logs
11. **🔍 Promtail** - Recolección de logs de Kubernetes

### 🔧 Características:

- **Chart Umbrella** - Gestión unificada de todos los componentes
- **Vault Injector** - Gestión segura de secretos sin Kubernetes secrets
- **Alta Disponibilidad** - Todos los componentes críticos con múltiples réplicas
- **Event Streaming** - Publicación eficiente de eventos en colas Redis con prioridades
- **Sistema de Email Completo** - Mailu con SMTP, IMAP/POP3 y webmail integrados
- **Stack de Observabilidad** - Monitoreo completo con métricas, logs y alertas
- **Despliegue Simplificado** - Un solo comando para toda la plataforma

## 📊 Stack de Observabilidad

### 🔍 Componentes del Stack:

1. **Prometheus**: 
   - Recolección automática de métricas
   - Almacenamiento de series temporales
   - AlertManager para notificaciones
   - Kube-state-metrics y Node-exporter

2. **Grafana**:
   - Dashboards pre-configurados para todos los componentes
   - Datasources automáticos (Prometheus + Loki)
   - Visualización de métricas y logs en una sola interfaz

3. **Loki**:
   - Almacenamiento centralizado de logs
   - Indexación eficiente por labels
   - Integración nativa con Grafana

4. **Promtail**:
   - Recolección automática de logs de pods
   - Filtrado por namespace, pod, container
   - Pipeline de procesamiento configurable

### 📈 Dashboards Disponibles:

- **Vault Dashboard**: Estado, métricas de auditoría y tokens
- **PostgreSQL Dashboard**: Conexiones, consultas y replicación
- **Redis Dashboard**: Memoria, comandos y Sentinel
- **ZITADEL Dashboard**: Autenticaciones, usuarios y eventos
- **Kubernetes Dashboard**: Métricas del clúster y nodos
- **Mailu Dashboard**: SMTP, IMAP y webmail

### 🚨 Alertas Configuradas:

- **Críticas**: Vault sellado, PostgreSQL caído, Redis caído, ZITADEL caído
- **Advertencias**: CPU alto (>80%), memoria alta (>85%), disco bajo (<10%)
- **Notificaciones**: Configurables por email, Slack, webhook

### 📝 Logs Centralizados:

- **Recolección automática**: Todos los logs de pods
- **Filtrado inteligente**: Por namespace, aplicación, severidad
- **Retención por entorno**:
  - Desarrollo: 7 días
  - Staging: 15 días  
  - Producción: 30 días

## 🌐 Acceso a Servicios

| Servicio | URL | Descripción |
|----------|-----|-------------|
| Vault UI | `https://vault.blinkchamber.svc:8200` | Interfaz web de Vault |
| ZITADEL | `https://zitadel.tu-dominio.com` | Plataforma de identidad |
| PostgreSQL | `postgresql-ha-postgresql.database.svc:5432` | Base de datos |
| Redis | `redis-master.database.svc:6379` | Cache y sesiones |
| **Grafana** | `http://grafana.infra.svc:3000` | **Visualización de métricas y logs** |
| **Prometheus** | `http://prometheus-server.infra.svc:9090` | **Métricas del sistema** |
| **AlertManager** | `http://prometheus-alertmanager.infra.svc:9093` | **Gestión de alertas** |

## 📊 Monitorización

### Ver estado general:

```bash
kubectl get pods -A -l app.kubernetes.io/part-of=blinkchamber-platform
```

### Acceso a interfaces de monitoreo:

```bash
# Grafana (usuario: admin, contraseña: admin123)
kubectl port-forward -n infra svc/grafana 3000:3000

# Prometheus
kubectl port-forward -n infra svc/prometheus-server 9090:9090

# AlertManager
kubectl port-forward -n infra svc/prometheus-alertmanager 9093:9093
```

### Logs específicos:

```bash
# Logs de Vault
kubectl logs -n blinkchamber -l app.kubernetes.io/name=vault

# Logs de ZITADEL
kubectl logs -n identity -l app.kubernetes.io/name=zitadel

# Logs de PostgreSQL
kubectl logs -n database -l app.kubernetes.io/name=postgresql-ha

# Ver logs en Grafana/Loki
kubectl port-forward -n infra svc/grafana 3000:3000
# Luego ir a Explore > Loki y usar queries como:
# {namespace="blinkchamber"}
# {app="vault"}
# {app="zitadel"}
```

## 🔧 Configuración

### 📋 Configuración por Environments:

El proyecto soporta múltiples environments con configuración específica:

```bash
# Estructura de configuración
environments/
├── base/values.yaml       # Configuración común a todos los environments
├── test/values.yaml       # Configuración específica para testing
├── development/values.yaml # Configuración para desarrollo
├── staging/values.yaml    # Configuración para staging
└── production/values.yaml # Configuración para producción
```

### Personalizar valores:

La configuración usa un patrón de herencia donde `base/values.yaml` contiene la configuración común y cada environment sobrescribe valores específicos:

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

# Stack de observabilidad
monitoring:
  enabled: true
  prometheus:
    enabled: true
    server:
      retention: 30d  # Retención de métricas
  grafana:
    enabled: true
    adminPassword: "tu-password-seguro"
  loki:
    enabled: true
    persistence:
      size: 50Gi  # Tamaño de almacenamiento de logs
```

### 🚀 Deployment por Environment:

```bash
# Testing
helm upgrade --install blinkchamber-platform . \
  -f environments/base/values.yaml \
  -f environments/test/values.yaml

# Desarrollo
helm upgrade --install blinkchamber-platform . \
  -f environments/base/values.yaml \
  -f environments/development/values.yaml

# Staging
helm upgrade --install blinkchamber-platform . \
  -f environments/base/values.yaml \
  -f environments/staging/values.yaml

# Producción  
helm upgrade --install blinkchamber-platform . \
  -f environments/base/values.yaml \
  -f environments/production/values.yaml
```

### 🧪 Testing de Deployment:

```bash
# Usar script de testing con dry-run
./scripts/test-umbrella-deployment.sh development
./scripts/test-umbrella-deployment.sh staging
./scripts/test-umbrella-deployment.sh production
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

### 4. Configurar Grafana:

```bash
# Acceder a Grafana
kubectl port-forward -n infra svc/grafana 3000:3000

# Ir a http://localhost:3000
# Usuario: admin
# Contraseña: admin123

# Los datasources (Prometheus y Loki) se configuran automáticamente
# Los dashboards se cargan automáticamente
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

# Ver eventos en Grafana/Loki
# Query: {app="zitadel"} |= "event"
```

## 🔄 Actualizaciones

### Actualizar dependencias:

```bash
helm dependency update
```

### Actualizar la plataforma:

```bash
./scripts/deploy-umbrella.sh upgrade
```

## 🗑️ Desinstalación

```bash
./scripts/deploy-umbrella.sh uninstall
```

**⚠️ Advertencia**: Esto eliminará todos los datos. Asegúrate de hacer backup antes.

## 📁 Estructura del Proyecto

```
.
├── Chart.yaml              # Metadatos y dependencias del chart umbrella
├── values.yaml             # Configuración principal
├── scripts/                # Scripts de automatización
│   ├── deploy-umbrella.sh      # Script de despliegue simplificado
│   ├── create-kind-cluster.sh  # Script para crear clúster Kind
│   ├── deploy-environments.sh  # Script de despliegue por entornos
│   ├── setup-mailu-secrets.sh  # Script de configuración de Mailu
│   └── verify-longhorn.sh      # Script de verificación de Longhorn
├── deploy.sh               # Script de conveniencia (redirige a scripts/)
└── create-cluster.sh       # Script de conveniencia (redirige a scripts/)
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
4. **Grafana no carga dashboards**: Verifica que los datasources estén configurados correctamente
5. **Prometheus no recopila métricas**: Verifica que los ServiceMonitors estén creados

### Logs de debug:

```bash
# Ver todos los eventos
kubectl get events -A --sort-by='.lastTimestamp'

# Ver logs detallados
kubectl logs -n blinkchamber vault-0 --previous

# Ver logs en Grafana/Loki
kubectl port-forward -n infra svc/grafana 3000:3000
# Query: {namespace="blinkchamber"} |= "error"
```

## 🧪 Pruebas

Para ejecutar las pruebas de BATS:

```bash
bats tests/test_exhaustive.bats
```

## 📚 Documentación

Para documentación completa y detallada, consulta el [**Índice de Documentación**](docs/README.md) que incluye:

- [**Arquitectura de Alta Disponibilidad**](docs/arquitectura.md) - Arquitectura detallada de ZITADEL y Vault
- [**Integración Redis-ZITADEL**](docs/redis-integration.md) - Configuración y uso de Redis con ZITADEL
- [**Sistema de Email Mailu**](docs/mailu-integration.md) - Configuración completa del sistema de email
- [**CI/CD Pipeline**](docs/ci-cd.md) - Pipeline de CI/CD con ArgoCD y Tekton
- [**Almacenamiento Longhorn**](docs/storage.md) - Configuración de almacenamiento distribuido
- [**Configuración por Entornos**](docs/environments.md) - Gestión de diferentes entornos

### 📋 Cambios Recientes (v2.0.0)

**🔄 Integración Umbrella Chart Completada** - *9 de Agosto de 2025*

#### **Cambios Principales:**
- ✅ **Configuración Multi-Environment:** Soporte completo para test, development, staging y production
- ✅ **Gestión Híbrida de Secretos:** Integración Vault + Kubernetes para compatibilidad con charts oficiales
- ✅ **Scripts Mejorados:** Nuevas funcionalidades en `./manage.sh` para gestión avanzada
- ✅ **Deployment Unificado:** Un comando para desplegar toda la plataforma por environment

#### **Nuevos Comandos:**
```bash
# Sincronización de secretos
./manage.sh secrets sync-k8s

# Testing de deployment
./scripts/test-umbrella-deployment.sh [environment]
```

#### **Documentación de Cambios:**
- 📋 [Changelog Detallado](docs/CHANGELOG-UMBRELLA-INTEGRATION.md)
- 🔧 [Análisis Técnico](docs/TECHNICAL-CHANGES-ANALYSIS.md)  
- 🚀 [Guía de Migración](docs/MIGRATION-GUIDE.md)

### Referencias Externas
- [Configuración de Vault](https://www.vaultproject.io/docs)
- [Documentación de ZITADEL](https://zitadel.com/docs)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)

## 🤝 Contribuir

1. Fork el repositorio
2. Crea una rama para tu feature
3. Commit tus cambios
4. Push a la rama
5. Abre un Pull Request

---

**🎉 ¡Disfruta de tu plataforma de alta disponibilidad con observabilidad completa!**
