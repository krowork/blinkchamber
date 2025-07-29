# 🔴 Integración de Redis con ZITADEL

## 📋 Resumen

Esta documentación describe la integración de Redis con ZITADEL en la plataforma BlinkChamber. Redis se utiliza como sistema de cache y almacenamiento de sesiones para mejorar el rendimiento y la escalabilidad de ZITADEL.

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
        maxConnAge: 30m
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

### Configuración recomendada en values.yaml

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

### Beneficios
- Publicación eficiente de eventos en lotes (batch)
- Uso de colas de prioridad para distintos tipos de eventos
- Pool de conexiones dedicado para eventos
- Métricas y monitorización integradas
- Separación de base de datos Redis para eventos y cache

### Comandos útiles

```bash
# Ver eventos en colas
kubectl exec -n database redis-master-0 -- redis-cli LRANGE zitadel:events:high 0 -1

# Ver métricas de eventos
kubectl exec -n identity zitadel-0 -- curl -s localhost:8080/metrics | grep event

# Monitorizar rendimiento
kubectl exec -n database redis-master-0 -- redis-cli info stats
```

## 🚀 Beneficios de la Integración

### ⚡ Rendimiento Mejorado
- **Reducción de latencia**: Cache local reduce tiempo de respuesta
- **Menos carga en BD**: Consultas frecuentes se sirven desde cache
- **Escalabilidad**: Múltiples instancias comparten cache

### 🔒 Seguridad
- **Gestión segura de secretos**: Contraseñas gestionadas por Vault
- **Aislamiento**: Redis en namespace separado
- **Encriptación**: Comunicación TLS entre servicios

### 📈 Alta Disponibilidad
- **Replicación**: 3 master + 3 réplicas + 3 Sentinel
- **Failover automático**: Sentinel gestiona conmutación por error
- **Persistencia**: Datos persistentes en volúmenes

## 🔍 Monitorización

### 📊 Métricas de Redis

```bash
# Ver estado de Redis
kubectl get pods -n database -l app.kubernetes.io/name=redis

# Logs de Redis master
kubectl logs -n database redis-master-0

# Logs de Sentinel
kubectl logs -n database redis-sentinel-0
```

### 📈 Métricas de ZITADEL con Redis

```bash
# Ver logs de ZITADEL con Redis
kubectl logs -n identity -l app.kubernetes.io/name=zitadel | grep -i redis

# Verificar conexión a Redis
kubectl exec -n identity zitadel-0 -- curl -s localhost:8080/healthz
```

## 🛠️ Troubleshooting

### ❌ Problemas Comunes

#### 1. ZITADEL no puede conectar a Redis
```bash
# Verificar que Redis esté corriendo
kubectl get pods -n database -l app.kubernetes.io/name=redis

# Verificar secretos de Vault
kubectl exec -n blinkchamber vault-0 -- vault kv get secret/data/redis

# Verificar conectividad de red
kubectl exec -n identity zitadel-0 -- nc -zv redis-master.database.svc.cluster.local 6379
```

#### 2. Redis no puede obtener contraseña de Vault
```bash
# Verificar que Vault esté desellado
kubectl exec -n blinkchamber vault-0 -- vault status

# Verificar policies de Redis
kubectl exec -n blinkchamber vault-0 -- vault policy read redis-policy

# Verificar roles de Kubernetes
kubectl exec -n blinkchamber vault-0 -- vault read auth/kubernetes/role/redis-role
```

#### 3. Bajo rendimiento de cache
```bash
# Verificar uso de memoria de Redis
kubectl exec -n database redis-master-0 -- redis-cli info memory

# Verificar estadísticas de cache
kubectl exec -n database redis-master-0 -- redis-cli info stats

# Verificar conexiones activas
kubectl exec -n database redis-master-0 -- redis-cli info clients
```

### 🔧 Soluciones

#### 1. Reiniciar Redis
```bash
kubectl delete pod -n database redis-master-0
kubectl delete pod -n database redis-replica-0
```

#### 2. Limpiar cache de Redis
```bash
kubectl exec -n database redis-master-0 -- redis-cli flushall
```

#### 3. Verificar configuración de ZITADEL
```bash
kubectl get configmap -n identity zitadel-config -o yaml
```

## 📚 Referencias

- [Documentación oficial de ZITADEL](https://zitadel.com/docs)
- [Redis en Kubernetes](https://redis.io/docs/stack/get-started/tutorials/redis-kubernetes/)
- [Vault Injector](https://www.vaultproject.io/docs/platform/k8s/injector)
- [Bitnami Redis Chart](https://github.com/bitnami/charts/tree/main/bitnami/redis)

## 🤝 Contribuir

Para contribuir a la integración de Redis con ZITADEL:

1. Fork el repositorio
2. Crea una rama para tu feature
3. Implementa los cambios
4. Añade tests
5. Documenta los cambios
6. Abre un Pull Request

---

**🎉 ¡Disfruta de tu plataforma con cache de alta disponibilidad!** 