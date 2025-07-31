# Tekton Pipelines Configuration

Esta configuración define pipelines de CI/CD nativas de Kubernetes para automatizar el despliegue.

## Estructura de Pipelines

```
tekton/
├── pipelines/
│   ├── build-and-test.yaml
│   ├── deploy-test.yaml
│   ├── deploy-staging.yaml
│   └── deploy-production.yaml
├── tasks/
│   ├── build.yaml
│   ├── test.yaml
│   ├── security-scan.yaml
│   └── deploy.yaml
└── triggers/
    ├── webhook.yaml
    └── eventlistener.yaml
```

## Pipeline de CI/CD

### 1. Build and Test Pipeline
- Compilación del código
- Ejecución de tests unitarios
- Análisis de seguridad
- Generación de imagen Docker
- Push a registry

### 2. Deploy Test Pipeline
- Despliegue automático a entorno de test
- Validación de funcionalidad
- Tests de integración

### 3. Deploy Staging Pipeline
- Despliegue manual a staging
- Tests de rendimiento
- Validación de configuración

### 4. Deploy Production Pipeline
- Despliegue manual a producción
- Aprobación requerida
- Rollback automático en caso de fallo

## Instalación de Tekton

```bash
# Instalar Tekton
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# Instalar Tekton Triggers
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml

# Instalar Tekton Dashboard
kubectl apply -f https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml
```

## Configuración de Webhooks

Cada pipeline se activa mediante webhooks de GitHub:

- **Push a develop**: Ejecuta build-and-test + deploy-test
- **Pull Request a main**: Ejecuta build-and-test + deploy-staging
- **Merge a main**: Ejecuta deploy-production (con aprobación)

## Variables de Entorno

```yaml
# Configuración por entorno
environments:
  test:
    namespace: blinkchamber-test
    domain: test.blinkchamber.local
    replicas: 1
  development:
    namespace: blinkchamber-dev
    domain: dev.blinkchamber.local
    replicas: 1
  staging:
    namespace: blinkchamber-staging
    domain: staging.blinkchamber.com
    replicas: 2
  production:
    namespace: blinkchamber-prod
    domain: blinkchamber.com
    replicas: 3
``` 