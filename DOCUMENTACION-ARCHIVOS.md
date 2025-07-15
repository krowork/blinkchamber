# DOCUMENTACIÓN DE ARCHIVOS DEL PROYECTO BLINKCHAMBER

Este documento describe en detalle el propósito, la lógica y la estructura de los principales archivos de configuración, charts de Helm, templates, scripts y archivos de Terraform del proyecto **BlinkChamber**.

## Índice

1. [Archivos de Configuración (`config/`)](#archivos-de-configuración-config)
2. [Charts y Templates de Helm (`blinkchamber/`)](#charts-y-templates-de-helm-blinkchamber)
3. [Scripts (`scripts/`)](#scripts-scripts)
4. [Infraestructura como Código - Terraform (`terraform/`)](#infraestructura-como-código---terraform-terraform)

---

## Archivos de Configuración (`config/`)

### `config/blinkchamber.yaml`
Archivo central de configuración del proyecto. Define:
- **Fases de despliegue**: bootstrap, inicialización de Vault, configuración de secretos y despliegue de aplicaciones.
- **Componentes**: habilita/deshabilita servicios como Vault, base de datos, identidad, correo, almacenamiento, monitoreo.
- **Parámetros de red, dominios, almacenamiento y seguridad**.
- **Configuración específica de cada componente** (ejemplo: integración de Vault con PostgreSQL, MinIO, Zitadel, Mailu, Grafana).
- **Políticas y roles de Vault**: define políticas de acceso y plantillas de secretos iniciales.
- **Ejemplo de estructura**:

```yaml
project:
  name: "blinkchamber"
  version: "2.0.0"
phases:
  phase1:
    name: "bootstrap"
    components:
      - "kubernetes-base"
      - "vault-infrastructure"
# ...
```

### `config/environment.example`
Plantilla de variables de entorno para despliegue local o personalizado. Incluye:
- Nombres de cluster y entorno
- Credenciales por defecto (Vault, PostgreSQL, MinIO, Grafana)
- Dominios locales
- Parámetros de almacenamiento y réplicas
- Flags de debug

### `config/kind-config.yaml`
Configuración para crear un cluster local con [kind](https://kind.sigs.k8s.io/):
- Define nodos control-plane y workers
- Mapea puertos del host a contenedores (Vault, PostgreSQL, Grafana, etc.)
- Monta volúmenes locales
- Configura subredes de pods y servicios

### `config/identity/README.md` y `config/mail/README.md`
Documentación específica sobre la configuración de identidad y correo.

---

## Charts y Templates de Helm (`blinkchamber/`)

### `blinkchamber/Chart.yaml`
Metadatos del chart principal de Helm:
- Nombre, descripción, versión, dependencias (Vault, PostgreSQL)

### `blinkchamber/values.yaml`
Valores por defecto para todos los componentes:
- Configuración global (dominio, recursos, TLS)
- Parámetros de Vault, PostgreSQL, Zitadel, Mailu, Grafana, Prometheus
- Ejemplo de sección:

```yaml
global:
  environment: local
  domain: blinkchamber.local
vault:
  enabled: true
  server:
    standalone:
      enabled: true
```

### `blinkchamber/charts/`
Contiene los charts empaquetados de dependencias:
- `postgresql-13.2.30.tgz`: Chart oficial de Bitnami para PostgreSQL
- `vault-0.27.0.tgz`: Chart oficial de HashiCorp para Vault

### Templates (`blinkchamber/templates/`)
Plantillas de recursos de Kubernetes para cada componente:

- **`_helpers.tpl`**: Funciones auxiliares de Helm para nombres, labels y service accounts.
- **`prometheus-deployment.yaml`**: Despliegue de Prometheus, con integración de Vault Agent Sidecar para inyectar secretos.
- **`grafana-deployment.yaml`**: Despliegue de Grafana, con Vault Agent para credenciales seguras.
- **`mailu-deployment.yaml`**: Despliegue de Mailu, con inyección de secretos desde Vault.
- **`zitadel-deployment.yaml`**: Despliegue de Zitadel, gestión de identidad, con integración de Vault para claves y credenciales.
- **`vault-init-job.yaml`**: Job de inicialización automática de Vault, que:
  - Espera a que Vault esté listo
  - Inicializa y desella Vault
  - Configura autenticación Kubernetes y motores de secretos
  - Crea secretos y políticas para cada aplicación
- **`NOTES.txt`**: Instrucciones post-instalación (acceso a servicios, port-forward, DNS local, logs, etc.)

---

## Scripts (`scripts/`)

Scripts Bash para automatizar despliegue, pruebas y gestión:

- **`blinkchamber-helm.sh`**: Script principal para instalar, actualizar, desinstalar, hacer port-forward y gestionar el chart de Helm. Incluye validaciones, ayuda interactiva y soporte para valores personalizados.
- **`vault-bootstrap.sh`**: Automatiza el bootstrap de Vault, inicialización segura y backup de claves.
- **`test-infrastructure-exhaustive.sh`**: Pruebas exhaustivas de la infraestructura desplegada.
- **`run-exhaustive-tests.sh`**: Ejecuta todos los tests de aplicaciones e infraestructura.
- **`deploy-robust.sh`**: Despliegue robusto de todos los componentes, con manejo de errores y reintentos.
- **`setup-vault-verbose.sh`**: Inicialización detallada de Vault para debugging.
- **`blinkchamber.sh`**: Script de gestión general del stack (instalación, pruebas, limpieza, etc.).
- **`secure-vault-init.sh`**: Inicialización segura de Vault con generación de claves y tokens.
- **`access-control.sh`**: Configuración de control de acceso y roles en Kubernetes.
- **`setup-access.sh`**: Automatiza la configuración de acceso a los servicios.
- **`vault-connectivity.sh`**: Pruebas de conectividad y salud de Vault.

#### Subcarpeta `scripts/lib/`
- **`common.sh`**: Funciones comunes reutilizables (logs, validaciones, helpers Bash).
- **`k8s.sh`**: Funciones para interacción con Kubernetes (kubectl, port-forward, etc.).
- **`application-tests.sh`**: Pruebas automatizadas de aplicaciones.
- **`infrastructure-tests.sh`**: Pruebas automatizadas de infraestructura.
- **`vault-agent-tests.sh`**: Pruebas específicas de integración con Vault Agent.

---

## Infraestructura como Código - Terraform (`terraform/`)

Estructura modular para gestionar toda la infraestructura:

### Fases (`terraform/phases/`)
- **`01-bootstrap/`**: Provisión de la infraestructura base (Kubernetes, ingress, cert-manager, Vault base).
- **`02-vault-init/`**: Inicialización y configuración automática de Vault (auth, policies, motores de secretos).
- **`03-secrets/`**: Carga y gestión de secretos en Vault.
- **`04-applications/`**: Despliegue de aplicaciones integradas con Vault (base de datos, identidad, almacenamiento, monitoreo). Incluye variables de entorno para dev/prod (`environments/dev.tfvars`, `environments/prod.tfvars`).

Cada fase contiene:
- `main.tf`: Recursos principales
- `tfplan`: Plan de ejecución
- `.terraform.lock.hcl`: Lockfile de dependencias
- `variables.tf` (cuando aplica): Variables de entrada

### Módulos (`terraform/modules/`)
- **`vault-bootstrap/`**: Lógica de bootstrap de Vault (main.tf, variables.tf, outputs.tf)
- **`database/`, `identity/`, `storage/`, `vault/`, `cert-manager/`, `ingress/`, `kubernetes-base/`**: Módulos reutilizables para cada componente de infraestructura.

---

## Notas Finales

- Consulta los archivos `README.md` en cada subdirectorio para detalles adicionales y ejemplos de uso.
- La integración entre Helm, scripts y Terraform permite un despliegue reproducible, seguro y automatizado de todo el stack BlinkChamber.
- Para troubleshooting y pruebas, revisa los scripts y los archivos de documentación en la raíz del proyecto. 