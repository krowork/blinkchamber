# BlinkChamber Helm Chart

Sistema de gestión de identidad y secretos autocontenido con Vault, PostgreSQL, Zitadel, Mailu, Grafana y Prometheus.

## Descripción

BlinkChamber es un stack completo de herramientas para gestión de identidad y secretos en Kubernetes, incluyendo:

- **Vault**: Gestión de secretos y autenticación
- **PostgreSQL**: Base de datos para aplicaciones
- **Zitadel**: Gestión de identidad y acceso
- **Mailu**: Sistema de correo completo
- **Grafana**: Monitoreo y visualización
- **Prometheus**: Recopilación de métricas

## Instalación

### Prerrequisitos

- Kubernetes 1.19+
- Helm 3.0+
- Ingress Controller (NGINX)
- Cert Manager (opcional, para TLS)

### Instalación rápida

```bash
# Agregar repositorios
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Instalar el chart
helm install blinkchamber ./blinkchamber -n blinkchamber --create-namespace --wait
```

### Instalación con valores personalizados

```bash
# Crear archivo de valores personalizado
cat > custom-values.yaml << EOF
global:
  domain: mi-dominio.local

vault:
  enabled: true

postgresql:
  enabled: true
  auth:
    password: "mi-password-seguro"

zitadel:
  enabled: true
  config:
    admin:
      password: "admin-seguro"
EOF

# Instalar con valores personalizados
helm install blinkchamber ./blinkchamber -f custom-values.yaml -n blinkchamber --create-namespace
```

## Configuración

### Valores principales

| Parámetro | Descripción | Valor por defecto |
|-----------|-------------|-------------------|
| `global.domain` | Dominio base para todos los servicios | `blinkchamber.local` |
| `vault.enabled` | Habilitar Vault | `true` |
| `postgresql.enabled` | Habilitar PostgreSQL | `true` |
| `zitadel.enabled` | Habilitar Zitadel | `true` |
| `mailu.enabled` | Habilitar Mailu | `true` |
| `grafana.enabled` | Habilitar Grafana | `true` |
| `prometheus.enabled` | Habilitar Prometheus | `true` |

### Configuración de Vault

```yaml
vault:
  enabled: true
  init:
    enabled: true  # Inicialización automática
  server:
    standalone:
      enabled: true
    persistence:
      enabled: true
      size: 10Gi
```

### Configuración de PostgreSQL

```yaml
postgresql:
  enabled: true
  auth:
    postgresPassword: "postgres123"
    database: "zitadel"
    username: "postgres"
    password: "postgres123"
  primary:
    persistence:
      enabled: true
      size: 10Gi
```

### Configuración de Zitadel

```yaml
zitadel:
  enabled: true
  config:
    masterkey: "masterkey123"
    admin:
      username: "admin"
      password: "admin123"
    database:
      postgres:
        host: "blinkchamber-postgresql"
        port: 5432
        database: "zitadel"
        username: "postgres"
        password: "postgres123"
```

## Uso

### Acceso a los servicios

Después de la instalación, los servicios estarán disponibles en:

- **Vault**: https://vault.blinkchamber.local
- **Zitadel**: https://zitadel.blinkchamber.local
- **Mailu**: https://mail.blinkchamber.local
- **Grafana**: https://grafana.blinkchamber.local
- **Prometheus**: https://prometheus.blinkchamber.local

### Configuración de DNS local

Agrega las siguientes entradas a tu `/etc/hosts`:

```bash
# BlinkChamber Services
127.0.0.1 vault.blinkchamber.local
127.0.0.1 zitadel.blinkchamber.local
127.0.0.1 mail.blinkchamber.local
127.0.0.1 grafana.blinkchamber.local
127.0.0.1 prometheus.blinkchamber.local
```

### Port-forwarding (alternativa)

Si no tienes Ingress configurado, puedes usar port-forwarding:

```bash
# Vault
kubectl port-forward svc/blinkchamber-vault 8200:8200 -n blinkchamber

# Zitadel
kubectl port-forward svc/blinkchamber-zitadel 8080:8080 -n blinkchamber

# Mailu
kubectl port-forward svc/blinkchamber-mailu 80:80 -n blinkchamber

# Grafana
kubectl port-forward svc/blinkchamber-grafana 3000:3000 -n blinkchamber

# Prometheus
kubectl port-forward svc/blinkchamber-prometheus 9090:9090 -n blinkchamber
```

## Gestión

### Actualizar el release

```bash
helm upgrade blinkchamber ./blinkchamber -n blinkchamber
```

### Ver estado del release

```bash
helm status blinkchamber -n blinkchamber
```

### Ver valores actuales

```bash
helm get values blinkchamber -n blinkchamber
```

### Desinstalar

```bash
helm uninstall blinkchamber -n blinkchamber
```

## Troubleshooting

### Vault no se inicializa

```bash
# Verificar logs del job de inicialización
kubectl logs job/blinkchamber-vault-init -n blinkchamber

# Verificar estado de Vault
kubectl exec -it deployment/blinkchamber-vault -- vault status
```

### PostgreSQL no inicia

```bash
# Verificar logs de PostgreSQL
kubectl logs deployment/blinkchamber-postgresql -n blinkchamber

# Verificar PVC
kubectl get pvc -n blinkchamber
```

### Zitadel no se conecta a la base de datos

```bash
# Verificar logs de Zitadel
kubectl logs deployment/blinkchamber-zitadel -n blinkchamber

# Verificar conectividad a PostgreSQL
kubectl exec -it deployment/blinkchamber-zitadel -- nc -zv blinkchamber-postgresql 5432
```

## Desarrollo

### Estructura del chart

```
blinkchamber/
├── Chart.yaml              # Metadatos del chart
├── values.yaml             # Valores por defecto
├── templates/              # Templates de Kubernetes
│   ├── _helpers.tpl        # Funciones helper
│   ├── mailu-deployment.yaml
│   ├── zitadel-deployment.yaml
│   ├── grafana-deployment.yaml
│   ├── prometheus-deployment.yaml
│   └── vault-init-job.yaml
├── charts/                 # Subcharts
│   ├── vault/              # Chart oficial de Vault
│   └── postgresql/         # Chart oficial de PostgreSQL
└── README.md               # Esta documentación
```

### Agregar nuevos componentes

1. Crear template en `templates/`
2. Agregar configuración en `values.yaml`
3. Actualizar documentación

### Testing

```bash
# Validar el chart
helm lint ./blinkchamber

# Generar templates sin instalar
helm template blinkchamber ./blinkchamber --dry-run

# Instalar en modo dry-run
helm install blinkchamber ./blinkchamber --dry-run --debug
```

## Contribuir

1. Fork el repositorio
2. Crear una rama para tu feature
3. Hacer commit de tus cambios
4. Crear un Pull Request

## Licencia

Este proyecto está bajo la licencia MIT. Ver el archivo LICENSE para más detalles. 