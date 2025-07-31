# Entornos de Despliegue

Esta estructura permite gestionar múltiples entornos con configuraciones específicas para CI/CD.

## Estructura de Directorios

```
environments/
├── base/                    # Configuración base común
├── test/                    # Entorno de pruebas
├── development/             # Entorno de desarrollo
├── staging/                 # Entorno de pre-producción
└── production/              # Entorno de producción
```

## Configuración por Entorno

### Test
- Recursos mínimos
- Sin persistencia de datos
- Logs detallados
- Acceso directo para debugging
- Sistema de email Mailu básico

### Development
- Recursos moderados
- Persistencia local
- Hot reload habilitado
- Acceso de desarrolladores
- Mailu con webmail habilitado (mail.dev.blinkchamber.local)

### Staging
- Recursos similares a producción
- Datos de prueba
- Monitoreo completo
- Validación de configuración
- Mailu con webmail habilitado (mail.staging.blinkchamber.com)

### Production
- Recursos optimizados
- Alta disponibilidad
- Seguridad máxima
- Backup automático
- Mailu con webmail habilitado (mail.blinkchamber.com)

## Herramientas de CI/CD

### ArgoCD
- GitOps para gestión declarativa
- Sincronización automática
- Rollbacks controlados

### Tekton
- Pipelines nativas de Kubernetes
- Integración con ArgoCD
- Escalabilidad

### Helmfile
- Gestión de múltiples charts
- Diferenciación por entornos
- Rollbacks controlados 