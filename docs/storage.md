# 💾 Almacenamiento Distribuido con Longhorn

## 📋 Resumen

Esta documentación describe la configuración y uso del sistema de almacenamiento distribuido Longhorn en la plataforma BlinkChamber, diseñado específicamente para el almacenamiento de videos de alta calidad.

## 🎯 ¿Por qué Longhorn?

Para el almacenamiento de gran cantidad de videos de 2 minutos, Longhorn proporciona:

- **Almacenamiento distribuido**: Los videos se replican automáticamente entre nodos
- **Alta disponibilidad**: 3 réplicas por defecto para máxima redundancia
- **Escalabilidad**: Volúmenes que pueden expandirse dinámicamente
- **Sin dependencias externas**: Funciona completamente on-premise
- **Gestión visual**: UI integrada para monitoreo de volúmenes
- **Backup automático**: Sistema de backup integrado
- **Recuperación de desastres**: Capacidad de recuperación rápida

## 🏗️ Arquitectura de Almacenamiento

### Estructura de Volúmenes

```
┌─────────────────────────────────────────────────────────────────┐
│                    Longhorn Storage                           │
│                                                               │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐   │
│  │  Video Uploads  │  │ Video Processed │  │ Video Cache │   │
│  │   (100Gi-1Ti)   │  │   (500Gi-5Ti)   │  │ (50Gi-500Gi)│   │
│  └─────────────────┘  └─────────────────┘  └─────────────┘   │
│           │                       │                    │       │
│           ▼                       ▼                    ▼       │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                Kubernetes Nodes                            │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │ │
│  │  │   Node 1    │  │   Node 2    │  │   Node 3    │        │ │
│  │  │ (Replica 1) │  │ (Replica 2) │  │ (Replica 3) │        │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘        │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Configuración de Alta Disponibilidad

```yaml
longhorn:
  enabled: true
  persistence:
    defaultClass: true
    defaultClassReplicaCount: 3
  defaultSettings:
    backupTarget: ""
    backupTargetCredentialSecret: ""
    allowRecurringJobWhileVolumeDetached: "true"
    createDefaultDiskLabeledNodes: "true"
    defaultDataPath: "/var/lib/longhorn"
    replicaAutoBalance: "enabled"
    storageOverProvisioningPercentage: "100"
    storageMinimalAvailablePercentage: "25"
    upgradeChecker: "true"
    defaultReplicaCount: "3"
    guaranteedEngineManagerCPU: "12"
    guaranteedReplicaManagerCPU: "12"
```

## 📦 Tipos de Volúmenes

### 1. **video-uploads-pvc** - Videos Recién Subidos
- **Tamaño**: 100Gi - 1Ti
- **Propósito**: Almacenamiento temporal de videos recién subidos
- **Retención**: Hasta procesamiento completo
- **Acceso**: Lectura/escritura para upload y procesamiento

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: video-uploads-pvc
  namespace: video-processing
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: longhorn
  resources:
    requests:
      storage: 500Gi
```

### 2. **video-processed-pvc** - Videos Procesados
- **Tamaño**: 500Gi - 5Ti
- **Propósito**: Almacenamiento permanente de videos procesados
- **Retención**: Largo plazo
- **Acceso**: Lectura para streaming, escritura para actualizaciones

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: video-processed-pvc
  namespace: video-processing
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: longhorn
  resources:
    requests:
      storage: 2Ti
```

### 3. **video-cache-pvc** - Cache de Transcodificación
- **Tamaño**: 50Gi - 500Gi
- **Propósito**: Cache temporal para transcodificación
- **Retención**: Temporal, se limpia automáticamente
- **Acceso**: Lectura/escritura para transcodificación

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: video-cache-pvc
  namespace: video-processing
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: longhorn
  resources:
    requests:
      storage: 200Gi
```

## 📊 Estimación de Capacidad

### Tamaños de Video por Calidad

Para videos de 2 minutos:

| Calidad | Tamaño por Video | Videos por 1TB | Videos por 5TB |
|---------|------------------|----------------|----------------|
| **720p** | ~50MB | ~20,000 | ~100,000 |
| **1080p** | ~150MB | ~6,600 | ~33,000 |
| **4K** | ~500MB | ~2,000 | ~10,000 |

### Configuración Recomendada por Entorno

#### Desarrollo
```yaml
video-uploads-pvc: 100Gi
video-processed-pvc: 500Gi
video-cache-pvc: 50Gi
```

#### Staging
```yaml
video-uploads-pvc: 500Gi
video-processed-pvc: 2Ti
video-cache-pvc: 200Gi
```

#### Producción
```yaml
video-uploads-pvc: 1Ti
video-processed-pvc: 5Ti
video-cache-pvc: 500Gi
```

## 🔧 Configuración

### 1. Habilitar Longhorn

```yaml
# En values.yaml
longhorn:
  enabled: true
  persistence:
    defaultClass: true
    defaultClassReplicaCount: 3
```

### 2. Configurar Storage Classes

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-video-storage
provisioner: driver.longhorn.io
allowVolumeExpansion: true
parameters:
  numberOfReplicas: "3"
  staleReplicaTimeout: "2880"
  fromBackup: ""
```

### 3. Configurar Persistent Volumes

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: video-storage-pvc
  namespace: video-processing
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: longhorn-video-storage
  resources:
    requests:
      storage: 1Ti
```

## 🚀 Despliegue

### 1. Instalar Longhorn

```bash
# Desplegar con el chart umbrella
./scripts/deploy-umbrella.sh install

# O instalar solo Longhorn
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace
```

### 2. Verificar Instalación

```bash
# Verificar pods de Longhorn
kubectl get pods -n longhorn-system

# Verificar storage classes
kubectl get storageclass

# Verificar volúmenes
kubectl get pv
kubectl get pvc -A
```

### 3. Acceder a la UI

```bash
# Port-forward para acceder a la UI
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80

# Acceder en el navegador
# http://localhost:8080
```

## 📊 Monitorización

### Métricas de Longhorn

```bash
# Verificar estado de volúmenes
kubectl get volumes -n longhorn-system

# Verificar réplicas
kubectl get replicas -n longhorn-system

# Verificar nodos
kubectl get nodes -l longhorn.io/node=true

# Verificar backups
kubectl get backups -n longhorn-system
```

### Comandos de Monitorización

```bash
# Verificar uso de almacenamiento
kubectl get pvc -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,CAPACITY:.spec.resources.requests.storage

# Verificar eventos de volúmenes
kubectl get events -n longhorn-system --sort-by='.lastTimestamp'

# Verificar logs de Longhorn
kubectl logs -n longhorn-system -l app=longhorn-manager
```

## 🔄 Backup y Recuperación

### Configuración de Backup

```yaml
apiVersion: longhorn.io/v1beta1
kind: BackupTarget
metadata:
  name: default
  namespace: longhorn-system
spec:
  backupTargetURL: s3://backup-bucket/longhorn
  credentialSecret: backup-secret
  pollInterval: 5m
  syncRequestedAt: "2023-01-01T00:00:00Z"
```

### Crear Backup

```bash
# Crear backup manual
kubectl create -f - <<EOF
apiVersion: longhorn.io/v1beta1
kind: Backup
metadata:
  name: video-backup-$(date +%Y%m%d)
  namespace: longhorn-system
spec:
  volumeName: video-storage-pv
EOF

# Verificar backups
kubectl get backups -n longhorn-system
```

### Restaurar desde Backup

```bash
# Restaurar volumen desde backup
kubectl create -f - <<EOF
apiVersion: longhorn.io/v1beta1
kind: Volume
metadata:
  name: video-storage-restored
  namespace: longhorn-system
spec:
  fromBackup: backup://video-backup-20230101
  numberOfReplicas: 3
  size: 1Ti
EOF
```

## 🔧 Troubleshooting

### Problemas Comunes

#### 1. Volumen no se crea
```bash
# Verificar storage class
kubectl get storageclass longhorn

# Verificar provisioner
kubectl get pods -n longhorn-system -l app=longhorn-provisioner

# Verificar logs
kubectl logs -n longhorn-system -l app=longhorn-provisioner
```

#### 2. Réplicas no sincronizadas
```bash
# Verificar estado de réplicas
kubectl get replicas -n longhorn-system

# Verificar nodos disponibles
kubectl get nodes -l longhorn.io/node=true

# Verificar espacio en disco
kubectl describe node <node-name> | grep -A 10 "Allocated resources"
```

#### 3. Volumen no se monta
```bash
# Verificar PVC
kubectl get pvc -n <namespace>

# Verificar PV
kubectl get pv

# Verificar eventos
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Comandos de Diagnóstico

```bash
# Verificar estado general
kubectl get pods,svc,pvc,pv -n longhorn-system

# Verificar configuración
kubectl get configmap -n longhorn-system

# Verificar secretos
kubectl get secrets -n longhorn-system

# Verificar logs detallados
kubectl logs -n longhorn-system -l app=longhorn-manager --tail=100
```

## 📈 Optimización de Rendimiento

### Configuración de Rendimiento

```yaml
longhorn:
  defaultSettings:
    # Optimización de CPU
    guaranteedEngineManagerCPU: "12"
    guaranteedReplicaManagerCPU: "12"
    
    # Optimización de red
    replicaSoftAntiAffinity: "true"
    replicaAutoBalance: "enabled"
    
    # Optimización de almacenamiento
    storageOverProvisioningPercentage: "100"
    storageMinimalAvailablePercentage: "25"
    
    # Optimización de backup
    backupTarget: ""
    backupTargetCredentialSecret: ""
    allowRecurringJobWhileVolumeDetached: "true"
```

### Recomendaciones de Hardware

#### Mínimo
- **CPU**: 4 cores por nodo
- **RAM**: 8GB por nodo
- **Almacenamiento**: 100GB SSD por nodo
- **Red**: 1Gbps

#### Recomendado
- **CPU**: 8+ cores por nodo
- **RAM**: 16GB+ por nodo
- **Almacenamiento**: 500GB+ NVMe SSD por nodo
- **Red**: 10Gbps

#### Producción
- **CPU**: 16+ cores por nodo
- **RAM**: 32GB+ por nodo
- **Almacenamiento**: 1TB+ NVMe SSD por nodo
- **Red**: 25Gbps+

## 🔒 Seguridad

### Configuraciones de Seguridad

1. **Aislamiento de red**: Longhorn usa su propia red overlay
2. **Encriptación**: Soporte para encriptación en tránsito
3. **RBAC**: Control de acceso basado en roles
4. **Auditoría**: Logs de todas las operaciones

### Configuración de Seguridad

```yaml
longhorn:
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
  
  networkPolicy:
    enabled: true
    
  tls:
    enabled: true
    certManager:
      enabled: true
```

## 📚 Referencias

- [Documentación oficial de Longhorn](https://longhorn.io/docs/)
- [Guía de instalación](https://longhorn.io/docs/1.4.0/deploy/install/)
- [Configuración de backup](https://longhorn.io/docs/1.4.0/snapshots-and-backups/)
- [Troubleshooting](https://longhorn.io/docs/1.4.0/troubleshooting/)

---

**🎉 ¡Longhorn proporciona almacenamiento distribuido robusto y escalable para tu plataforma de videos!**
