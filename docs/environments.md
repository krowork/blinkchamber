# 🌍 Configuración por Entornos

## 📋 Resumen

Esta documentación describe la gestión de diferentes entornos (desarrollo, staging, producción) en la plataforma BlinkChamber, utilizando Helm y Kustomize para mantener configuraciones específicas por ambiente.

## 🎯 Estrategia de Entornos

### Filosofía de Configuración

- **Configuración base común**: Valores compartidos entre todos los entornos
- **Overlays específicos**: Configuraciones únicas por entorno
- **Gestión de secretos**: Secretos específicos por entorno en Vault
- **Despliegue automatizado**: Pipeline CI/CD para cada entorno

## 📁 Estructura de Entornos

```
environments/
├── base/                    # Configuración base común
│   ├── values.yaml         # Valores base compartidos
│   └── kustomization.yaml  # Configuración base de Kustomize
├── development/            # Entorno de desarrollo
│   ├── values.yaml         # Valores específicos de desarrollo
│   ├── kustomization.yaml  # Overlay de desarrollo
│   └── secrets/            # Secretos de desarrollo (referencias)
├── staging/                # Entorno de staging
│   ├── values.yaml         # Valores específicos de staging
│   ├── kustomization.yaml  # Overlay de staging
│   └── secrets/            # Secretos de staging (referencias)
└── production/             # Entorno de producción
    ├── values.yaml         # Valores específicos de producción
    ├── kustomization.yaml  # Overlay de producción
    └── secrets/            # Secretos de producción (referencias)
```

## 🔧 Configuración Base

### `environments/base/values.yaml`

```yaml
# Configuración base compartida entre todos los entornos
global:
  environment: base
  domain: blinkchamber.local

# Configuración base de componentes
cert-manager:
  enabled: true
  installCRDs: true

ingress-nginx:
  enabled: true
  controller:
    ingressClassResource:
      name: nginx

vault:
  enabled: true
  server:
    ha:
      enabled: true
      replicas: 3

postgresql-ha:
  enabled: true
  postgresql:
    replicaCount: 3
  pgpool:
    replicaCount: 2

redis:
  enabled: true
  architecture: replication
  master:
    replicaCount: 3
  replica:
    replicaCount: 3
  sentinel:
    enabled: true
    replicaCount: 3

zitadel:
  enabled: true
  replicaCount: 2

mailu:
  enabled: true

longhorn:
  enabled: true
  persistence:
    defaultClass: true
    defaultClassReplicaCount: 3
```

## 🚀 Entorno de Desarrollo

### Características
- **Propósito**: Desarrollo activo y testing
- **Recursos**: Mínimos para desarrollo
- **Persistencia**: Local para desarrollo rápido
- **Logs**: Detallados para debugging

### `environments/development/values.yaml`

```yaml
# Override de configuración base para desarrollo
global:
  environment: development
  domain: dev.blinkchamber.local

# Configuración específica de desarrollo
vault:
  server:
    ha:
      replicas: 1  # Una réplica para desarrollo

postgresql-ha:
  postgresql:
    replicaCount: 1  # Una réplica para desarrollo
  pgpool:
    replicaCount: 1

redis:
  master:
    replicaCount: 1  # Una réplica para desarrollo
  replica:
    replicaCount: 1
  sentinel:
    replicaCount: 1

zitadel:
  replicaCount: 1  # Una réplica para desarrollo

# Configuración de recursos mínimos
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Configuración de persistencia local
persistence:
  enabled: true
  size: 5Gi
  storageClass: local-path

# Configuración de logs detallados
logging:
  level: debug
  format: json

# Configuración de TLS para desarrollo
tls:
  enabled: false  # Sin TLS en desarrollo
  certManager:
    enabled: false
```

### `environments/development/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: blinkchamber-dev

resources:
  - ../base

patches:
  - path: patches/namespace.yaml
    target:
      kind: Namespace
      name: blinkchamber

  - path: patches/resource-quota.yaml
    target:
      kind: ResourceQuota
      name: development-quota

configMapGenerator:
  - name: environment-config
    literals:
      - ENVIRONMENT=development
      - LOG_LEVEL=debug
      - DEBUG=true

secretGenerator:
  - name: development-secrets
    envs:
      - .env.development
```

## 🧪 Entorno de Staging

### Características
- **Propósito**: Pre-producción y testing de integración
- **Recursos**: Similares a producción
- **Persistencia**: Completa para testing real
- **Monitoreo**: Completo para validación

### `environments/staging/values.yaml`

```yaml
# Override de configuración base para staging
global:
  environment: staging
  domain: staging.blinkchamber.local

# Configuración específica de staging
vault:
  server:
    ha:
      replicas: 3  # Alta disponibilidad

postgresql-ha:
  postgresql:
    replicaCount: 3
  pgpool:
    replicaCount: 2

redis:
  master:
    replicaCount: 3
  replica:
    replicaCount: 3
  sentinel:
    replicaCount: 3

zitadel:
  replicaCount: 2

# Configuración de recursos moderados
resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 2Gi

# Configuración de persistencia completa
persistence:
  enabled: true
  size: 20Gi
  storageClass: longhorn

# Configuración de logs moderados
logging:
  level: info
  format: json

# Configuración de TLS para staging
tls:
  enabled: true
  certManager:
    enabled: true
    issuer: letsencrypt-staging

# Configuración de monitoreo completo
monitoring:
  enabled: true
  prometheus:
    enabled: true
  grafana:
    enabled: true
  alerting:
    enabled: true
```

### `environments/staging/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: blinkchamber-staging

resources:
  - ../base

patches:
  - path: patches/namespace.yaml
    target:
      kind: Namespace
      name: blinkchamber

  - path: patches/resource-quota.yaml
    target:
      kind: ResourceQuota
      name: staging-quota

  - path: patches/monitoring.yaml
    target:
      kind: ServiceMonitor

configMapGenerator:
  - name: environment-config
    literals:
      - ENVIRONMENT=staging
      - LOG_LEVEL=info
      - DEBUG=false

secretGenerator:
  - name: staging-secrets
    envs:
      - .env.staging
```

## 🏭 Entorno de Producción

### Características
- **Propósito**: Producción real
- **Recursos**: Optimizados para rendimiento
- **Persistencia**: Alta disponibilidad
- **Seguridad**: Máxima seguridad

### `environments/production/values.yaml`

```yaml
# Override de configuración base para producción
global:
  environment: production
  domain: blinkchamber.com

# Configuración específica de producción
vault:
  server:
    ha:
      replicas: 5  # Máxima disponibilidad

postgresql-ha:
  postgresql:
    replicaCount: 5
  pgpool:
    replicaCount: 3

redis:
  master:
    replicaCount: 5
  replica:
    replicaCount: 5
  sentinel:
    replicaCount: 5

zitadel:
  replicaCount: 3

# Configuración de recursos optimizados
resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2000m
    memory: 4Gi

# Configuración de persistencia de alta disponibilidad
persistence:
  enabled: true
  size: 100Gi
  storageClass: longhorn
  replicaCount: 3

# Configuración de logs de producción
logging:
  level: warn
  format: json
  retention: 30d

# Configuración de TLS para producción
tls:
  enabled: true
  certManager:
    enabled: true
    issuer: letsencrypt-prod

# Configuración de monitoreo completo
monitoring:
  enabled: true
  prometheus:
    enabled: true
    retention: 30d
  grafana:
    enabled: true
  alerting:
    enabled: true
    slack:
      enabled: true

# Configuración de seguridad máxima
security:
  networkPolicies:
    enabled: true
  podSecurityPolicies:
    enabled: true
  rbac:
    enabled: true

# Configuración de backup automático
backup:
  enabled: true
  schedule: "0 2 * * *"  # Diario a las 2 AM
  retention: 30d
```

### `environments/production/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: blinkchamber-prod

resources:
  - ../base

patches:
  - path: patches/namespace.yaml
    target:
      kind: Namespace
      name: blinkchamber

  - path: patches/resource-quota.yaml
    target:
      kind: ResourceQuota
      name: production-quota

  - path: patches/security.yaml
    target:
      kind: NetworkPolicy

  - path: patches/monitoring.yaml
    target:
      kind: ServiceMonitor

configMapGenerator:
  - name: environment-config
    literals:
      - ENVIRONMENT=production
      - LOG_LEVEL=warn
      - DEBUG=false

secretGenerator:
  - name: production-secrets
    envs:
      - .env.production
```

## 🔐 Gestión de Secretos por Entorno

### Configuración de Vault

```bash
# Secretos para desarrollo
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/dev/postgres password="dev-password"
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/dev/redis password="dev-redis-password"
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/dev/zitadel password="dev-zitadel-password"

# Secretos para staging
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/staging/postgres password="staging-password"
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/staging/redis password="staging-redis-password"
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/staging/zitadel password="staging-zitadel-password"

# Secretos para producción
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/prod/postgres password="prod-password"
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/prod/redis password="prod-redis-password"
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/prod/zitadel password="prod-zitadel-password"
```

### Políticas de Vault por Entorno

```hcl
# Política para desarrollo
path "secret/data/dev/*" {
  capabilities = ["read"]
}

# Política para staging
path "secret/data/staging/*" {
  capabilities = ["read"]
}

# Política para producción
path "secret/data/prod/*" {
  capabilities = ["read"]
}
```

## 🚀 Comandos de Despliegue

### Despliegue por Entorno

```bash
# Desplegar entorno de desarrollo
./scripts/deploy-environments.sh development

# Desplegar entorno de staging
./scripts/deploy-environments.sh staging

# Desplegar entorno de producción
./scripts/deploy-environments.sh production

# Desplegar todos los entornos
./scripts/deploy-environments.sh all
```

### Gestión con Helm

```bash
# Desplegar con valores específicos del entorno
helm upgrade --install blinkchamber-dev . \
  -f values.yaml \
  -f environments/development/values.yaml \
  --namespace blinkchamber-dev \
  --create-namespace

helm upgrade --install blinkchamber-staging . \
  -f values.yaml \
  -f environments/staging/values.yaml \
  --namespace blinkchamber-staging \
  --create-namespace

helm upgrade --install blinkchamber-prod . \
  -f values.yaml \
  -f environments/production/values.yaml \
  --namespace blinkchamber-prod \
  --create-namespace
```

### Gestión con Kustomize

```bash
# Aplicar configuración de desarrollo
kubectl apply -k environments/development/

# Aplicar configuración de staging
kubectl apply -k environments/staging/

# Aplicar configuración de producción
kubectl apply -k environments/production/
```

## 📊 Monitorización por Entorno

### Métricas Específicas

```yaml
# Configuración de Prometheus por entorno
prometheus:
  development:
    retention: 7d
    scrapeInterval: 30s
  staging:
    retention: 15d
    scrapeInterval: 15s
  production:
    retention: 30d
    scrapeInterval: 10s
```

### Alertas por Entorno

```yaml
# Alertas específicas por entorno
alerts:
  development:
    - name: "dev-pod-down"
      severity: "warning"
      threshold: 1m
  staging:
    - name: "staging-pod-down"
      severity: "critical"
      threshold: 30s
  production:
    - name: "prod-pod-down"
      severity: "critical"
      threshold: 15s
```

## 🔄 Promoción entre Entornos

### Flujo de Promoción

```yaml
# Pipeline de promoción
promotion:
  development:
    triggers:
      - push_to_develop
    auto_deploy: true
    tests:
      - unit_tests
      - integration_tests
  
  staging:
    triggers:
      - merge_to_main
    auto_deploy: true
    tests:
      - integration_tests
      - e2e_tests
      - performance_tests
  
  production:
    triggers:
      - manual_approval
    auto_deploy: false
    tests:
      - smoke_tests
      - security_tests
```

### Scripts de Promoción

```bash
#!/bin/bash
# promote-to-staging.sh

# Promover de desarrollo a staging
helm upgrade --install blinkchamber-staging . \
  -f values.yaml \
  -f environments/staging/values.yaml \
  --set global.imageTag=$(git rev-parse HEAD) \
  --namespace blinkchamber-staging

# Ejecutar tests de staging
./scripts/run-staging-tests.sh

# Notificar resultado
./scripts/notify-promotion.sh staging
```

## 🔧 Troubleshooting por Entorno

### Problemas Comunes por Entorno

#### Desarrollo
```bash
# Verificar recursos mínimos
kubectl describe resourcequota -n blinkchamber-dev

# Verificar logs detallados
kubectl logs -n blinkchamber-dev -l app=zitadel --tail=100

# Verificar configuración
kubectl get configmap -n blinkchamber-dev environment-config -o yaml
```

#### Staging
```bash
# Verificar monitoreo
kubectl get servicemonitor -n blinkchamber-staging

# Verificar métricas
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Verificar alertas
kubectl get prometheusrules -n blinkchamber-staging
```

#### Producción
```bash
# Verificar seguridad
kubectl get networkpolicies -n blinkchamber-prod

# Verificar backup
kubectl get cronjob -n blinkchamber-prod

# Verificar certificados
kubectl get certificates -n blinkchamber-prod
```

## 📚 Referencias

- [Helm Documentation](https://helm.sh/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [Vault Documentation](https://www.vaultproject.io/docs)
- [Kubernetes Multi-tenancy](https://kubernetes.io/docs/concepts/security/pod-security-standards/)

---

**🎯 Esta configuración por entornos permite gestionar eficientemente diferentes ambientes manteniendo la consistencia y seguridad.**
