# 🔴 Integración de Redis con ZITADEL

## 📋 Resumen

Esta documentación describe la integración completa de Redis con ZITADEL en la plataforma BlinkChamber. Redis se utiliza como sistema de cache, almacenamiento de sesiones y event streaming para mejorar el rendimiento y la escalabilidad de ZITADEL.

## 🎯 Propósito de Redis en ZITADEL

### 🔄 Cache de Sesiones
- **Sesiones de usuario**: Almacena sesiones activas de usuarios autenticados
- **Tokens de acceso**: Cachea tokens JWT y OAuth para validación rápida
- **Sesiones de administración**: Mantiene sesiones de administradores del sistema

### ⚡ Cache de Consultas
- **Resultados de consultas**: Cachea resultados de consultas frecuentes a la base de datos
- **Configuraciones**: Almacena configuraciones del sistema para acceso rápido
- **Metadatos**: Cachea metadatos de usuarios y organizaciones

### 🚦 Rate Limiting
- **Control de velocidad**: Implementa límites de velocidad para APIs
- **Protección DDoS**: Previene ataques de denegación de servicio
- **Cuotas de API**: Gestiona límites de uso de APIs por usuario/organización

### 📊 Event Store
- **Eventos temporales**: Almacena eventos del sistema para procesamiento
- **Cola de trabajos**: Gestiona trabajos en segundo plano
- **Métricas en tiempo real**: Almacena métricas de rendimiento

## 🏗️ Arquitectura de Redis

### 📦 Configuración de Alta Disponibilidad

```yaml
redis:
  enabled: true
  architecture: replication
  auth:
    enabled: true
    sentinel: true
  master:
    replicaCount: 3
  replica:
    replicaCount: 3
  sentinel:
    enabled: true
    replicaCount: 3
```

### 🔐 Seguridad con Vault

Redis utiliza el patrón Vault Injector para gestión segura de secretos:

```yaml
podAnnotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "redis-role"
  vault.hashicorp.com/agent-inject-secret-REDIS_PASSWORD: "secret/data/redis#password"
```

### 🏗️ Estructura de Alta Disponibilidad

```
┌─────────────────────────────────────────────────────────────┐
│                    Redis Cluster                           │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Master    │  │   Master    │  │   Master    │        │
│  │   Node 1    │  │   Node 2    │  │   Node 3    │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│         │                │                │               │
│         ▼                ▼                ▼               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │  Replica    │  │  Replica    │  │  Replica    │        │
│  │   Node 1    │  │   Node 2    │  │   Node 3    │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │  Sentinel   │  │  Sentinel   │  │  Sentinel   │        │
│  │   Node 1    │  │   Node 2    │  │   Node 3    │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 Configuración de ZITADEL con Redis

### 📝 Configuración de Cache

```yaml
zitadel:
  config:
    cache:
      redis:
        enabled: true
        host: redis-master.database.svc.cluster.local
        port: 6379
        password:
          valueFromFile: /vault/secrets/REDIS_PASSWORD
        database: 0
        poolSize: 10
        maxRetries: 3
        dialTimeout: 5s
        readTimeout: 3s
        writeTimeout: 3s
        poolTimeout: 4s
        idleTimeout: 5m
```

### 🔑 Parámetros de Configuración

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| `host` | `redis-master.database.svc.cluster.local` | Servidor Redis master |
| `port` | `6379` | Puerto estándar de Redis |
| `database` | `0` | Base de datos Redis (0-15) |
| `poolSize` | `10` | Número máximo de conexiones en pool |
| `maxRetries` | `3` | Intentos de reconexión |
| `dialTimeout` | `5s` | Timeout para conexión inicial |
| `readTimeout` | `3s` | Timeout para operaciones de lectura |
| `writeTimeout` | `3s` | Timeout para operaciones de escritura |
| `poolTimeout` | `4s` | Timeout para obtener conexión del pool |
| `idleTimeout` | `5m` | Timeout para conexiones inactivas |
| `maxConnAge` | `30m` | Tiempo máximo de vida de conexiones |

## 🚀 Event Streaming con Redis

### Configuración Completa

```yaml
zitadel:
  config:
    cache:
      redis:
        enabled: true
        host: redis-master.database.svc.cluster.local
        port: 6379
        password:
          valueFromFile: /vault/secrets/REDIS_PASSWORD
        database: 0
        poolSize: 10
        maxRetries: 3
        dialTimeout: 5s
        readTimeout: 3s
        writeTimeout: 3s
        poolTimeout: 4s
        idleTimeout: 5m
        maxConnAge: 30m
    
    # Event Streaming Configuration
    events:
      enabled: true
      redis:
        enabled: true
        host: redis-master.database.svc.cluster.local
        port: 6379
        password:
          valueFromFile: /vault/secrets/REDIS_PASSWORD
        database: 1  # Separate database for events
        poolSize: 20  # Larger pool for event publishing
        maxRetries: 5
        dialTimeout: 3s
        readTimeout: 2s
        writeTimeout: 2s
        poolTimeout: 3s
        idleTimeout: 10m
        maxConnAge: 1h
      publishing:
        enabled: true
        batchSize: 100
        batchTimeout: 1s
        maxRetries: 3
        retryDelay: 100ms
        compression: true
      types:
        - "user.created"
        - "user.updated"
        - "user.deleted"
        - "org.created"
        - "org.updated"
        - "org.deleted"
        - "project.created"
        - "project.updated"
        - "project.deleted"
        - "app.created"
        - "app.updated"
        - "app.deleted"
        - "auth.login"
        - "auth.logout"
        - "auth.failed"
        - "policy.created"
        - "policy.updated"
        - "policy.deleted"
        - "role.created"
        - "role.updated"
        - "role.deleted"
      queues:
        high_priority: "zitadel:events:high"
        normal_priority: "zitadel:events:normal"
        low_priority: "zitadel:events:low"
        dead_letter: "zitadel:events:dead_letter"
      performance:
        workerCount: 10
        maxConcurrentEvents: 1000
        eventBufferSize: 5000
        flushInterval: 500ms
        enableMetrics: true
```

### 🎯 Tipos de Eventos

#### High Priority Events
- `auth.login` - Inicio de sesión exitoso
- `auth.logout` - Cierre de sesión
- `auth.failed` - Intento de autenticación fallido
- `auth.password_changed` - Cambio de contraseña
- `auth.mfa_enabled` - Activación de MFA

#### Normal Priority Events
- `user.created` - Creación de usuario
- `user.updated` - Actualización de usuario
- `user.deleted` - Eliminación de usuario
- `org.created` - Creación de organización
- `org.updated` - Actualización de organización
- `org.deleted` - Eliminación de organización
- `project.created` - Creación de proyecto
- `
