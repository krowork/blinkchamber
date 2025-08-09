# 🏗️ Arquitectura de Alta Disponibilidad

## 📋 Resumen

Esta documentación describe la arquitectura de alta disponibilidad (HA) de la plataforma BlinkChamber, que incluye ZITADEL, HashiCorp Vault, PostgreSQL, Redis, Mailu y Longhorn. El objetivo es proporcionar un sistema robusto, tolerante a fallos y escalable.

## 🎯 Componentes Principales

### 🔐 ZITADEL - Plataforma de Identidad
- **Propósito**: Gestión completa de identidades y autenticación
- **Arquitectura**: Clúster de al menos 2 nodos con balanceador de carga
- **Base de datos**: PostgreSQL HA con replicación en streaming
- **Cache**: Redis para sesiones y consultas frecuentes
- **Eventos**: Sistema de event streaming con colas de prioridad

### 🗄️ Vault - Gestión de Secretos
- **Propósito**: Gestión segura de secretos y credenciales
- **Arquitectura**: Clúster de al menos 3 nodos con backend Raft
- **Almacenamiento**: Backend integrado Raft para alta disponibilidad
- **Inyección**: Vault Injector para inyección automática de secretos
- **Autenticación**: Integración con Kubernetes para autenticación

### 🐘 PostgreSQL - Base de Datos
- **Propósito**: Almacenamiento persistente de datos
- **Arquitectura**: 3 réplicas principales + 2 PgPool para balanceo
- **Replicación**: Streaming replication con failover automático
- **Seguridad**: Secretos gestionados por Vault
- **Backup**: Sistema automático de backups

### 🔴 Redis - Cache y Sesiones
- **Propósito**: Cache de sesiones y consultas frecuentes
- **Arquitectura**: 3 master + 3 réplicas + 3 Sentinel
- **Alta disponibilidad**: Failover automático con Sentinel
- **Eventos**: Colas de eventos con prioridades (high, normal, low)
- **Persistencia**: Datos persistentes en volúmenes

### 📧 Mailu - Sistema de Email
- **Propósito**: Sistema completo de email (SMTP, IMAP, Webmail)
- **Componentes**: Postfix (SMTP), Dovecot (IMAP/POP3), Roundcube (Webmail)
- **Proxy**: Nginx como proxy reverso
- **Base de datos**: PostgreSQL para usuarios y configuración
- **Cache**: Redis para sesiones de webmail

### 💾 Longhorn - Almacenamiento Distribuido
- **Propósito**: Almacenamiento distribuido para videos
- **Arquitectura**: Volúmenes replicados entre nodos
- **Alta disponibilidad**: 3 réplicas por defecto
- **Escalabilidad**: Expansión dinámica de volúmenes
- **UI**: Interfaz web para gestión de volúmenes

## 🏗️ Diagrama de Arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                          │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │   Ingress       │    │   Cert-Manager  │    │   Longhorn  │ │
│  │   Controller    │    │   (TLS)         │    │   (Storage) │ │
│  └─────────────────┘    └─────────────────┘    └─────────────┘ │
│           │                       │                    │        │
│           ▼                       ▼                    ▼        │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    Applications Layer                       │ │
│  │                                                             │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │ │
│  │  │   ZITADEL   │  │    Mailu    │  │   Custom Apps       │ │ │
│  │  │ (Identity)  │  │   (Email)   │  │   (Video Processing)│ │ │
│  │  └─────────────┘  └─────────────┘  └─────────────────────┘ │ │
│  │           │               │                    │            │ │
│  │           ▼               ▼                    ▼            │ │
│  └─────────────────────────────────────────────────────────────┘ │
│           │               │                    │                │
│           ▼               ▼                    ▼                │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                   Data Layer                               │ │
│  │                                                             │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │ │
│  │  │ PostgreSQL  │  │    Redis    │  │      Vault          │ │ │
│  │  │    (DB)     │  │   (Cache)   │  │   (Secrets)         │ │ │
│  │  └─────────────┘  └─────────────┘  └─────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 🔐 Seguridad y Secretos

### Patrón Vault Injector

Utilizamos el patrón Vault Sidecar Injector para gestión segura de secretos:

```yaml
podAnnotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "app-role"
  vault.hashicorp.com/agent-inject-secret-DB_PASSWORD: "secret/data/postgres#password"
```

### Flujo de Trabajo

1. **Habilitar Vault Injector**: Configurado automáticamente en el chart
2. **Anotaciones en Pods**: Los deployments incluyen anotaciones para Vault
3. **Montaje de Volumen**: Volumen `emptyDir` montado en `/vault/secrets`
4. **Consumo de Secretos**: Aplicaciones leen secretos desde archivos

### Políticas de Seguridad

```hcl
# Política para PostgreSQL
path "secret/data/postgres/*" {
  capabilities = ["read"]
}

# Política para ZITADEL
path "secret/data/zitadel/*" {
  capabilities = ["read"]
}

# Política para Redis
path "secret/data/redis/*" {
  capabilities = ["read"]
}
```

## 📊 Alta Disponibilidad

### Estrategias de HA por Componente

| Componente | Estrategia | Réplicas | Failover |
|------------|------------|----------|----------|
| **ZITADEL** | Load Balancing | 2+ | Manual/Auto |
| **Vault** | Raft Consensus | 3+ | Automático |
| **PostgreSQL** | Streaming Replication | 3+ | Automático |
| **Redis** | Sentinel | 3+ | Automático |
| **Mailu** | Load Balancing | 2+ | Manual |
| **Longhorn** | Distributed Storage | 3+ | Automático |

### Configuración de Redundancia

```yaml
# ZITADEL
zitadel:
  replicaCount: 2
  podDisruptionBudget:
    minAvailable: 1

# Vault
vault:
  server:
    ha:
      replicas: 3
      config: |
        ui = true
        listener "tcp" {
          tls_disable = 1
          address = "[::]:8200"
          cluster_address = "[::]:8201"
        }
        storage "raft" {
          path = "/vault/data"
          node_id = "vault-${POD_NAME}"
          retry_join {
            leader_api_addr = "http://vault-0.vault-internal:8200"
          }
        }

# PostgreSQL
postgresql-ha:
  postgresql:
    replicaCount: 3
  pgpool:
    replicaCount: 2

# Redis
redis:
  architecture: replication
  master:
    replicaCount: 3
  replica:
    replicaCount: 3
  sentinel:
    enabled: true
    replicaCount: 3
```

## 🔄 Event Streaming

### Arquitectura de Eventos

ZITADEL publica eventos en colas Redis con diferentes prioridades:

```yaml
zitadel:
  config:
    events:
      enabled: true
      redis:
        enabled: true
        host: redis-master.database.svc.cluster.local
        port: 6379
        database: 1  # Base de datos separada para eventos
      publishing:
        batchSize: 100
        batchTimeout: 1s
        compression: true
      queues:
        high_priority: "zitadel:events:high"     # Auth events
        normal_priority: "zitadel:events:normal"  # CRUD events
        low_priority: "zitadel:events:low"       # Analytics events
```

### Tipos de Eventos

- **High Priority**: `auth.login`, `auth.logout`, `auth.failed`
- **Normal Priority**: `user.created`, `org.created`, `project.created`
- **Low Priority**: `user.profile_viewed`, `analytics.page_viewed`

## 📈 Monitorización

### Métricas por Componente

#### ZITADEL
```bash
# Métricas de autenticación
zitadel_auth_requests_total
zitadel_auth_failures_total
zitadel_users_total

# Métricas de rendimiento
zitadel_http_requests_duration_seconds
zitadel_grpc_requests_duration_seconds
```

#### Vault
```bash
# Estado del sistema
vault_core_unsealed
vault_core_ha_mode
vault_raft_storage_is_leader

# Métricas de auditoría
vault_audit_log_request_count
vault_token_create_count
```

#### PostgreSQL
```bash
# Métricas de base de datos
postgresql_connections_active
postgresql_connections_idle
postgresql_queries_total

# Métricas de replicación
postgresql_replication_lag_seconds
postgresql_replication_status
```

#### Redis
```bash
# Métricas de rendimiento
redis_connected_clients
redis_used_memory_bytes
redis_commands_processed_total

# Métricas de Sentinel
redis_sentinel_masters
redis_sentinel_slaves
```

### Alertas Configuradas

```yaml
# Alertas críticas
- alert: VaultUnsealed
  expr: vault_core_unsealed == 0
  for: 1m
  labels:
    severity: critical

- alert: PostgreSQLDown
  expr: postgresql_up == 0
  for: 1m
  labels:
    severity: critical

- alert: RedisDown
  expr: redis_up == 0
  for: 1m
  labels:
    severity: critical
```

## 🔧 Procedimientos Operativos

### Despliegue

1. **Preparación del Clúster**
   ```bash
   ./scripts/create-kind-cluster.sh
   ```

2. **Despliegue de la Plataforma**
   ```bash
   ./scripts/deploy-umbrella.sh install
   ```

3. **Inicialización de Vault**
   ```bash
   kubectl exec -n blinkchamber vault-0 -- vault operator init
   kubectl exec -n blinkchamber vault-0 -- vault operator unseal
   ```

4. **Configuración de Secretos**
   ```bash
   ./scripts/setup-mailu-secrets.sh
   ```

### Backup y Recuperación

#### PostgreSQL
```bash
# Backup automático
pg_dump -h postgresql-ha-postgresql.database.svc -U postgres -d zitadel > backup.sql

# Restauración
psql -h postgresql-ha-postgresql.database.svc -U postgres -d zitadel < backup.sql
```

#### Vault
```bash
# Backup de configuración
kubectl exec -n blinkchamber vault-0 -- vault operator raft snapshot save backup.snap

# Restauración
kubectl exec -n blinkchamber vault-0 -- vault operator raft snapshot restore backup.snap
```

### Escalado

#### Escalar ZITADEL
```bash
kubectl scale deployment zitadel -n identity --replicas=3
```

#### Escalar PostgreSQL
```bash
helm upgrade blinkchamber . --set postgresql-ha.postgresql.replicaCount=5
```

#### Escalar Redis
```bash
helm upgrade blinkchamber . --set redis.master.replicaCount=5
```

## 🛠️ Troubleshooting

### Problemas Comunes

#### 1. Vault no se inicializa
```bash
# Verificar estado
kubectl exec -n blinkchamber vault-0 -- vault status

# Reinicializar si es necesario
kubectl exec -n blinkchamber vault-0 -- vault operator init
```

#### 2. PostgreSQL no arranca
```bash
# Verificar secretos
kubectl exec -n blinkchamber vault-0 -- vault kv get secret/data/postgres

# Verificar logs
kubectl logs -n database postgresql-ha-postgresql-0
```

#### 3. Redis no conecta
```bash
# Verificar Sentinel
kubectl exec -n database redis-sentinel-0 -- redis-cli -p 26379 sentinel masters

# Verificar conectividad
kubectl exec -n database redis-master-0 -- redis-cli ping
```

### Comandos de Diagnóstico

```bash
# Estado general del clúster
kubectl get pods -A -l app.kubernetes.io/part-of=blinkchamber-platform

# Eventos del clúster
kubectl get events -A --sort-by='.lastTimestamp'

# Uso de recursos
kubectl top pods -A
```

## 📚 Referencias

- [Documentación de ZITADEL](https://zitadel.com/docs)
- [Documentación de Vault](https://www.vaultproject.io/docs)
- [Documentación de PostgreSQL](https://www.postgresql.org/docs/)
- [Documentación de Redis](https://redis.io/documentation)
- [Documentación de Longhorn](https://longhorn.io/docs/)

---

**🎯 Esta arquitectura proporciona una base sólida para un sistema de alta disponibilidad con gestión segura de secretos y escalabilidad horizontal.**
