# ArgoCD Configuration

Esta configuración permite gestionar múltiples entornos usando GitOps con ArgoCD.

## Estructura de Aplicaciones

```
argocd/
├── applications/
│   ├── test.yaml
│   ├── development.yaml
│   ├── staging.yaml
│   └── production.yaml
└── projects/
    └── blinkchamber-project.yaml
```

## Instalación de ArgoCD

```bash
# Instalar ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Obtener contraseña inicial
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Configuración de Proyectos

Cada entorno tiene su propio proyecto en ArgoCD con políticas de seguridad específicas:

- **test**: Acceso completo para desarrolladores
- **development**: Acceso para desarrolladores y DevOps
- **staging**: Acceso limitado para DevOps y QA
- **production**: Acceso restringido solo para DevOps senior

## Configuración de Aplicaciones

Cada aplicación apunta a un branch específico del repositorio:

- **test**: branch `develop`
- **development**: branch `develop`
- **staging**: branch `main`
- **production**: branch `main` con aprobación manual

## Comandos Útiles

```bash
# Desplegar todos los entornos
helmfile apply

# Desplegar solo un entorno
helmfile apply --selector environment=test

# Verificar estado
helmfile status

# Rollback
helmfile rollback
``` 