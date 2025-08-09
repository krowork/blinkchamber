# 📊 Stack de Observabilidad - BlinkChamber Platform

## 📋 Resumen

Esta documentación describe el stack completo de observabilidad implementado en la plataforma BlinkChamber, que incluye Prometheus para métricas, Grafana para visualización, Loki para logs centralizados y Promtail para recolección de logs.

## 🎯 Componentes del Stack

### 📈 Prometheus - Recolección de Métricas

**Propósito**: Recolección, almacenamiento y consulta de métricas de series temporales.

**Características**:
- Recolección automática de métricas de todos los componentes
- Almacenamiento persistente con Longhorn
- AlertManager para notificaciones
- Kube-state-metrics para métricas de Kubernetes
- Node-exporter para métricas de nodos

**Configuración**:
```yaml
prometheus:
  enabled: true
  alertmanager:
    enabled: true
    persistentVolume:
      enabled: true
      size: 10Gi
      storageClass: longhorn
  server:
    persistentVolume:
      enabled: true
      size: 50Gi
      storageClass: longhorn
    retention: 30d
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: 1
        memory: 2Gi
```

### 📊 Grafana - Visualización

**Propósito**: Visualización unificada de métricas y logs.

**Características**:
- Dashboards pre-configurados para todos los componentes
- Datasources automáticos (Prometheus + Loki)
- Persistencia de configuración y dashboards
- Autenticación configurable

**Configuración**:
```yaml
grafana:
  enabled: true
  adminPassword: "admin123"  # Cambiar en producción
  persistence:
    enabled: true
    size: 10Gi
    storageClass: longhorn
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

### 📝 Loki - Logs Centralizados

**Propósito**: Almacenamiento y consulta de logs centralizados.

**Características**:
- Almacenamiento eficiente de logs
- Indexación por labels
- Integración nativa con Grafana
- Retención configurable por entorno

**Configuración**:
```yaml
loki:
  enabled: true
  loki:
    auth_enabled: false
    commonConfig:
      path_prefix: /var/loki
      replication_factor: 1
    storage:
      type: filesystem
      filesystem:
        chunks_directory: /var/loki/chunks
        rules_directory: /var/loki/rules
  persistence:
    enabled: true
    size: 20Gi
    storageClass: longhorn
```

### 🔍 Promtail - Recolección de Logs

**Propósito**: Recolección automática de logs de pods de Kubernetes.

**Características**:
- Recolección automática de logs de todos los pods
- Filtrado por namespace, pod, container
- Pipeline de procesamiento configurable
- Labels automáticos para facilitar consultas

**Configuración**:
```yaml
promtail:
  enabled: true
  config:
    server:
      http_listen_port: 9080
    positions:
      filename: /tmp/positions.yaml
    clients:
      - url: http://loki:3100/loki/api/v1/push
    scrape_configs:
      - job_name: kubernetes-pods-name
        pipeline_stages:
          - docker: {}
        kubernetes_sd_configs:
          - role: pod
```

## 📈 Dashboards Disponibles

### 🔐 Vault Dashboard

**Métricas incluidas**:
- Estado de Vault (sellado/desellado)
- Tokens creados/revocados
- Autenticaciones exitosas/fallidas
- Latencia de operaciones
- Uso de memoria y CPU

**Paneles principales**:
- Vault Status (estado general)
- Authentication Metrics (métricas de autenticación)
- Token Operations (operaciones de tokens)
- System Resources (recursos del sistema)

### 🐘 PostgreSQL Dashboard

**Métricas incluidas**:
- Conexiones activas/inactivas
- Consultas por segundo
- Tiempo de respuesta
- Estado de replicación
- Uso de disco y memoria

**Paneles principales**:
- PostgreSQL Connections (conexiones)
- Query Performance (rendimiento de consultas)
- Replication Status (estado de replicación)
- Database Size (tamaño de base de datos)

### 🔴 Redis Dashboard

**Métricas incluidas**:
- Memoria utilizada/disponible
- Comandos procesados
- Conexiones activas
- Estado de Sentinel
- Hit/miss ratio

**Paneles principales**:
- Redis Memory Usage (uso de memoria)
- Commands per Second (comandos por segundo)
- Connected Clients (clientes conectados)
- Sentinel Status (estado de Sentinel)

### 🆔 ZITADEL Dashboard

**Métricas incluidas**:
- Autenticaciones exitosas/fallidas
- Usuarios activos
- Eventos publicados
- Latencia de API
- Uso de recursos

**Paneles principales**:
- Authentication Metrics (métricas de autenticación)
- User Activity (actividad de usuarios)
- API Performance (rendimiento de API)
- Event Streaming (streaming de eventos)

### 🖥️ Kubernetes Dashboard

**Métricas incluidas**:
- Estado de pods
- Uso de CPU y memoria por nodo
- Espacio en disco
- Network I/O
- Estado de servicios

**Paneles principales**:
- Node Resources (recursos de nodos)
- Pod Status (estado de pods)
- Cluster Overview (vista general del clúster)
- Network Traffic (tráfico de red)

## 🚨 Alertas Configuradas

### 🔴 Alertas Críticas

```yaml
- alert: VaultUnsealed
  expr: vault_core_unsealed == 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "Vault is sealed"
    description: "Vault instance {{ $labels.instance }} is sealed"

- alert: PostgreSQLDown
  expr: postgresql_up == 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "PostgreSQL is down"
    description: "PostgreSQL instance {{ $labels.instance }} is down"

- alert: RedisDown
  expr: redis_up == 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "Redis is down"
    description: "Redis instance {{ $labels.instance }} is down"

- alert: ZitadelDown
  expr: zitadel_up == 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "ZITADEL is down"
    description: "ZITADEL instance {{ $labels.instance }} is down"
```

### ⚠️ Alertas de Advertencia

```yaml
- alert: HighCPUUsage
  expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High CPU usage"
    description: "CPU usage is above 80% on {{ $labels.instance }}"

- alert: HighMemoryUsage
  expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High memory usage"
    description: "Memory usage is above 85% on {{ $labels.instance }}"

- alert: DiskSpaceLow
  expr: (node_filesystem_avail_bytes{mountpoint="/"} * 100) / node_filesystem_size_bytes{mountpoint="/"} < 10
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Low disk space"
    description: "Disk space is below 10% on {{ $labels.instance }}"
```

## 📝 Logs Centralizados

### 🔍 Consultas de Logs

**Logs por namespace**:
```logql
{namespace="blinkchamber"}
```

**Logs por aplicación**:
```logql
{app="vault"}
{app="zitadel"}
{app="postgresql"}
{app="redis"}
```

**Logs de errores**:
```logql
{namespace="blinkchamber"} |= "error"
{namespace="blinkchamber"} |= "ERROR"
```

**Logs de autenticación**:
```logql
{app="zitadel"} |= "auth"
{app="vault"} |= "authentication"
```

**Logs de eventos**:
```logql
{app="zitadel"} |= "event"
{app="redis"} |= "event"
```

### 📊 Retención por Entorno

| Entorno | Retención de Métricas | Retención de Logs |
|---------|----------------------|-------------------|
| Desarrollo | 7 días | 7 días |
| Staging | 15 días | 15 días |
| Producción | 30 días | 30 días |

## 🌐 Acceso a Interfaces

### 🔗 URLs de Acceso

| Servicio | URL Interna | URL Externa |
|----------|-------------|-------------|
| Grafana | `http://grafana.infra.svc:3000` | `http://grafana.tu-dominio.com` |
| Prometheus | `http://prometheus-server.infra.svc:9090` | `http://prometheus.tu-dominio.com` |
| AlertManager | `http://prometheus-alertmanager.infra.svc:9093` | `http://alerts.tu-dominio.com` |

### 🔐 Credenciales

**Grafana**:
- Usuario: `admin`
- Contraseña: `admin123` (cambiar en producción)

**Prometheus**: Sin autenticación (configurar en producción)

**AlertManager**: Sin autenticación (configurar en producción)

## 🚀 Comandos Útiles

### 📊 Acceso a Interfaces

```bash
# Grafana
kubectl port-forward -n infra svc/grafana 3000:3000

# Prometheus
kubectl port-forward -n infra svc/prometheus-server 9090:9090

# AlertManager
kubectl port-forward -n infra svc/prometheus-alertmanager 9093:9093
```

### 🔍 Verificación de Estado

```bash
# Verificar pods de monitoreo
kubectl get pods -n infra -l app.kubernetes.io/part-of=blinkchamber-platform

# Verificar ServiceMonitors
kubectl get servicemonitor -n infra

# Verificar PrometheusRules
kubectl get prometheusrule -n infra

# Verificar AlertManager
kubectl get alertmanager -n infra
```

### 📝 Consultas de Logs

```bash
# Logs de Promtail
kubectl logs -n infra -l app=promtail

# Logs de Loki
kubectl logs -n infra -l app=loki

# Logs de Grafana
kubectl logs -n infra -l app=grafana

# Logs de Prometheus
kubectl logs -n infra -l app=prometheus
```

### 🔧 Configuración

```bash
# Ver configuración de Prometheus
kubectl get configmap -n infra prometheus-server -o yaml

# Ver configuración de AlertManager
kubectl get configmap -n infra prometheus-alertmanager -o yaml

# Ver configuración de Promtail
kubectl get configmap -n infra promtail -o yaml
```

## 🔧 Configuración Avanzada

### 📊 Métricas Personalizadas

Para agregar métricas personalizadas:

```yaml
# En values.yaml
prometheus:
  serverFiles:
    prometheus.yml:
      scrape_configs:
        - job_name: 'custom-metrics'
          static_configs:
            - targets: ['custom-app:8080']
          metrics_path: '/metrics'
```

### 🚨 Alertas Personalizadas

Para agregar alertas personalizadas:

```yaml
# En values.yaml
prometheus:
  serverFiles:
    alerts:
      groups:
        - name: custom-alerts
          rules:
            - alert: CustomAlert
              expr: custom_metric > threshold
              for: 1m
              labels:
                severity: warning
              annotations:
                summary: "Custom alert"
                description: "Custom alert description"
```

### 📝 Logs Personalizados

Para configurar logs personalizados:

```yaml
# En values.yaml
promtail:
  config:
    scrape_configs:
      - job_name: 'custom-logs'
        static_configs:
          - targets:
              - localhost
            labels:
              job: custom-app
              __path__: /var/log/custom-app/*.log
```

## 🔒 Seguridad

### 🔐 Autenticación

**Recomendaciones para producción**:

1. **Grafana**:
   ```yaml
   grafana:
     auth:
       enabled: true
     adminPassword: "password-seguro"
   ```

2. **Prometheus**:
   ```yaml
   prometheus:
     server:
       basicAuth:
         enabled: true
         username: "prometheus"
         password: "password-seguro"
   ```

3. **AlertManager**:
   ```yaml
   prometheus:
     alertmanager:
       basicAuth:
         enabled: true
         username: "alertmanager"
         password: "password-seguro"
   ```

### 🌐 TLS/HTTPS

Para habilitar HTTPS:

```yaml
# En values.yaml
grafana:
  ingress:
    enabled: true
    tls:
      enabled: true
      secretName: grafana-tls
    hosts:
      - host: grafana.tu-dominio.com
        paths:
          - path: /
            pathType: Prefix

prometheus:
  server:
    ingress:
      enabled: true
      tls:
        enabled: true
        secretName: prometheus-tls
      hosts:
        - host: prometheus.tu-dominio.com
          paths:
            - path: /
              pathType: Prefix
```

## 🔄 Mantenimiento

### 📊 Backup de Configuración

```bash
# Backup de dashboards de Grafana
kubectl get configmap -n infra grafana-dashboards -o yaml > grafana-dashboards-backup.yaml

# Backup de configuración de Prometheus
kubectl get configmap -n infra prometheus-server -o yaml > prometheus-config-backup.yaml

# Backup de alertas
kubectl get prometheusrule -n infra -o yaml > prometheus-rules-backup.yaml
```

### 🔄 Actualización

```bash
# Actualizar dependencias
helm dependency update

# Actualizar la plataforma
helm upgrade blinkchamber . -f values.yaml

# Verificar estado
kubectl get pods -n infra
```

### 🗑️ Limpieza

```bash
# Limpiar logs antiguos
kubectl exec -n infra loki-0 -- loki-cli query '{job="kubernetes-pods"}' --since=7d --delete

# Limpiar métricas antiguas
# Prometheus limpia automáticamente según la configuración de retention
```

## 📚 Referencias

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [Promtail Documentation](https://grafana.com/docs/loki/latest/clients/promtail/)
- [AlertManager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)

---

**🎯 Este stack de observabilidad proporciona visibilidad completa sobre la plataforma BlinkChamber, permitiendo monitoreo proactivo y resolución rápida de problemas.**
