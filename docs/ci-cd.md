# 🔄 Pipeline de CI/CD

## 📋 Resumen

Esta documentación describe la configuración completa de CI/CD para múltiples entornos usando GitOps con ArgoCD, Tekton y Helmfile. El pipeline proporciona automatización completa desde el desarrollo hasta la producción.

## 🏗️ Arquitectura de CI/CD

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub Repo   │───▶│   Tekton CI     │───▶│   ArgoCD CD     │
│                 │    │   (Build/Test)  │    │   (Deploy)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │                        │
                              ▼                        ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   Container     │    │   Kubernetes    │
                       │   Registry      │    │   Clusters      │
                       └─────────────────┘    └─────────────────┘
```

## 🛠️ Herramientas Utilizadas

### 1. **ArgoCD** - GitOps CD
- **Propósito**: Gestión declarativa de despliegues
- **Ventajas**: 
  - Sincronización automática con Git
  - Rollbacks automáticos
  - Multi-tenant para diferentes entornos
  - Interfaz web para monitoreo

### 2. **Tekton** - Pipelines Nativas de Kubernetes
- **Propósito**: Automatización de CI/CD
- **Ventajas**:
  - Pipelines nativas de Kubernetes
  - Escalabilidad y portabilidad
  - Integración con ArgoCD
  - Reutilización de tareas

### 3. **Helmfile** - Gestión de Charts de Helm
- **Propósito**: Orquestación de múltiples charts
- **Ventajas**:
  - Gestión declarativa de releases
  - Diferenciación por entornos
  - Rollbacks controlados
  - Integración con ArgoCD

### 4. **Kustomize** - Personalización de Manifiestos
- **Propósito**: Overlays para diferentes configuraciones
- **Ventajas**:
  - Personalización sin modificar charts base
  - Gestión de secretos por entorno
  - Configuración específica por ambiente

## 📁 Estructura del Proyecto

```
blinkchamber/
├── environments/              # Configuraciones por entorno
│   ├── base/                 # Configuración base común
│   ├── test/                 # Entorno de pruebas
│   ├── development/          # Entorno de desarrollo
│   ├── staging/              # Entorno de pre-producción
│   └── production/           # Entorno de producción
├── argocd/                   # Configuración de ArgoCD
│   ├── applications/         # Definiciones de aplicaciones
│   └── projects/             # Definiciones de proyectos
├── tekton/                   # Pipelines de Tekton
│   ├── pipelines/            # Definiciones de pipelines
│   ├── tasks/                # Tareas reutilizables
│   └── triggers/             # Configuración de triggers
├── scripts/                  # Scripts de automatización
├── helmfile.yaml             # Configuración principal de Helmfile
└── docs/                     # Documentación
```

## 🚀 Flujo de CI/CD

### 1. **Desarrollo Local**
```bash
# Clonar repositorio
git clone https://github.com/blinkchamber/platform.git
cd platform

# Crear rama de desarrollo
git checkout -b feature/nueva-funcionalidad

# Hacer cambios y commit
git add .
git commit -m "feat: nueva funcionalidad"
git push origin feature/nueva-funcionalidad
```

### 2. **Pipeline de CI (Tekton)**
```yaml
# Activado por: Push a develop o Pull Request
Pipeline:
  1. Build Code
  2. Run Unit Tests
  3. Security Scan
  4. Build Docker Image
  5. Push to Registry
  6. Deploy to Test (automático)
```

### 3. **Pipeline de CD (ArgoCD)**
```yaml
# Activado por: Merge a main
Pipeline:
  1. Deploy to Staging (automático)
  2. Run Integration Tests
  3. Manual Approval (producción)
  4. Deploy to Production
  5. Health Checks
```

## 🔧 Configuración por Entorno

### **Test Environment**
- **Propósito**: Pruebas automáticas
- **Características**:
  - Recursos mínimos
  - Sin persistencia de datos
  - Logs detallados
  - Acceso directo para debugging
- **Configuración**:
  ```yaml
  replicas: 1
  persistence: false
  tls: false
  resources: minimal
  ```

### **Development Environment**
- **Propósito**: Desarrollo activo
- **Características**:
  - Recursos moderados
  - Persistencia local
  - Hot reload habilitado
  - Acceso de desarrolladores
- **Configuración**:
  ```yaml
  replicas: 1
  persistence: true (5Gi)
  tls: true (staging)
  resources: moderate
  ```

### **Staging Environment**
- **Propósito**: Pre-producción
- **Características**:
  - Recursos similares a producción
  - Datos de prueba
  - Monitoreo completo
  - Validación de configuración
- **Configuración**:
  ```yaml
  replicas: 2
  persistence: true (20Gi)
  tls: true (staging)
  resources: production-like
  ```

### **Production Environment**
- **Propósito**: Producción
- **Características**:
  - Recursos optimizados
  - Alta disponibilidad
  - Seguridad máxima
  - Backup automático
- **Configuración**:
  ```yaml
  replicas: 3-5
  persistence: true (50-100Gi)
  tls: true (production)
  resources: optimized
  ```

## 🚀 Comandos de Despliegue

### **Despliegue Manual**
```bash
# Desplegar entorno específico
./scripts/deploy-environments.sh test
./scripts/deploy-environments.sh development
./scripts/deploy-environments.sh staging
./scripts/deploy-environments.sh production

# Desplegar todos los entornos
./scripts/deploy-environments.sh all

# Modo dry-run
./scripts/deploy-environments.sh production --dry-run

# Forzar despliegue sin confirmación
./scripts/deploy-environments.sh test --force
```

### **Gestión con Helmfile**
```bash
# Aplicar cambios
helmfile apply

# Aplicar solo un entorno
helmfile apply --selector environment=test

# Verificar estado
helmfile status

# Rollback
helmfile rollback

# Diferencias
helmfile diff
```

### **Gestión con ArgoCD**
```bash
# Verificar estado de aplicaciones
argocd app list

# Sincronizar aplicación
argocd app sync blinkchamber-test

# Ver logs
argocd app logs blinkchamber-test

# Rollback
argocd app rollback blinkchamber-test
```

## 🔐 Seguridad y Secretos

### **Gestión de Secretos con Vault**
- **Patrón**: Vault Sidecar Injector
- **Ventajas**:
  - Secretos dinámicos
  - Rotación automática
  - Auditoría completa
  - Sin secretos en Git

### **Configuración por Entorno**
```yaml
# Test: Secretos de prueba
vault:
  secrets:
    - path: "secret/test"
      policies: ["test-policy"]

# Development: Secretos de desarrollo
vault:
  secrets:
    - path: "secret/dev"
      policies: ["dev-policy"]

# Staging: Secretos de staging
vault:
  secrets:
    - path: "secret/staging"
      policies: ["staging-policy"]

# Production: Secretos de producción
vault:
  secrets:
    - path: "secret/prod"
      policies: ["prod-policy"]
```

## 📊 Monitoreo y Observabilidad

### **Métricas por Entorno**
- **Test**: Métricas básicas de salud
- **Development**: Métricas de desarrollo
- **Staging**: Métricas completas
- **Production**: Métricas detalladas + alertas

### **Logs Centralizados**
- **Fluentd/Fluent Bit**: Recolección de logs
- **Elasticsearch**: Almacenamiento
- **Kibana**: Visualización
- **Retención por entorno**:
  - Test: 7 días
  - Development: 30 días
  - Staging: 90 días
  - Production: 1 año

## 🔄 Rollback y Recuperación

### **Rollback Automático**
```yaml
# ArgoCD: Rollback automático en fallo
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### **Rollback Manual**
```bash
# Rollback con Helmfile
helmfile rollback --selector environment=production

# Rollback con ArgoCD
argocd app rollback blinkchamber-prod

# Rollback específico
argocd app rollback blinkchamber-prod 2
```

## 🧪 Testing Strategy

### **Test Pyramid**
```
    ┌─────────────┐
    │   E2E Tests │ ← 10%
    ├─────────────┤
    │Integration  │ ← 20%
    │   Tests     │
    ├─────────────┤
    │  Unit Tests │ ← 70%
    └─────────────┘
```

### **Entornos de Testing**
- **Unit Tests**: Ejecutados en CI
- **Integration Tests**: Entorno de test
- **E2E Tests**: Entorno de staging
- **Performance Tests**: Entorno de staging

## 📈 Escalabilidad

### **Auto-scaling por Entorno**
```yaml
# Test: Sin auto-scaling
autoscaling:
  enabled: false

# Development: Auto-scaling básico
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 3

# Staging: Auto-scaling moderado
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5

# Production: Auto-scaling completo
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
```

## 🔧 Troubleshooting

### **Problemas Comunes**

1. **Despliegue Fallido**
   ```bash
   # Verificar logs
   kubectl logs -n blinkchamber-test deployment/vault
   
   # Verificar eventos
   kubectl get events -n blinkchamber-test
   
   # Verificar recursos
   kubectl describe pod -n blinkchamber-test
   ```

2. **Sincronización de ArgoCD**
   ```bash
   # Verificar estado
   argocd app get blinkchamber-test
   
   # Forzar sincronización
   argocd app sync blinkchamber-test --force
   
   # Ver diferencias
   argocd app diff blinkchamber-test
   ```

3. **Problemas de Recursos**
   ```bash
   # Verificar uso de recursos
   kubectl top pods -n blinkchamber-test
   
   # Verificar límites
   kubectl describe resourcequota -n blinkchamber-test
   ```

### **Comandos de Diagnóstico**
```bash
# Verificar estado general
kubectl get pods,svc,ingress -A -l app.kubernetes.io/part-of=blinkchamber-platform

# Verificar eventos
kubectl get events -A --sort-by='.lastTimestamp'

# Verificar logs de ArgoCD
kubectl logs -n argocd deployment/argocd-server

# Verificar logs de Tekton
kubectl logs -n tekton-pipelines deployment/tekton-pipelines-controller
```

## 📋 Configuración de ArgoCD

### **Aplicación de ArgoCD**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: blinkchamber-test
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/blinkchamber/platform.git
    targetRevision: HEAD
    path: environments/test
  destination:
    server: https://kubernetes.default.svc
    namespace: blinkchamber-test
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### **Proyecto de ArgoCD**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: blinkchamber
  namespace: argocd
spec:
  description: BlinkChamber Platform
  sourceRepos:
    - 'https://github.com/blinkchamber/platform.git'
  destinations:
    - namespace: blinkchamber-*
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
  namespaceResourceWhitelist:
    - group: ''
      kind: ConfigMap
    - group: ''
      kind: Secret
    - group: ''
      kind: Service
    - group: ''
      kind: Deployment
```

## 📋 Configuración de Tekton

### **Pipeline de Tekton**
```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: blinkchamber-pipeline
spec:
  params:
    - name: git-url
    - name: git-revision
    - name: environment
  tasks:
    - name: fetch-repository
      taskRef:
        name: git-clone
      params:
        - name: url
          value: $(params.git-url)
        - name: revision
          value: $(params.git-revision)
    - name: run-tests
      runAfter: ["fetch-repository"]
      taskRef:
        name: bats-test
      params:
        - name: test-path
          value: "tests/"
    - name: build-image
      runAfter: ["run-tests"]
      taskRef:
        name: kaniko
      params:
        - name: IMAGE
          value: "registry.example.com/blinkchamber:$(params.git-revision)"
    - name: deploy
      runAfter: ["build-image"]
      taskRef:
        name: helm-upgrade-from-source
      params:
        - name: release_name
          value: "blinkchamber-$(params.environment)"
        - name: namespace
          value: "blinkchamber-$(params.environment)"
```

## 📚 Recursos Adicionales

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Tekton Documentation](https://tekton.dev/docs/)
- [Helmfile Documentation](https://helmfile.readthedocs.io/)
- [Vault Documentation](https://www.vaultproject.io/docs)
- [ZITADEL Documentation](https://zitadel.com/docs/)

## 🤝 Contribución

Para contribuir al pipeline de CI/CD:

1. Crear una rama feature
2. Implementar cambios
3. Ejecutar tests localmente
4. Crear Pull Request
5. Revisión y aprobación
6. Merge a main

---

**Nota**: Este pipeline está diseñado para mantener la seguridad y estabilidad de la plataforma BlinkChamber siguiendo las mejores prácticas de GitOps y DevOps.
