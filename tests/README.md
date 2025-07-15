# Tests de Infraestructura y Aplicaciones — blinkchamber

Este directorio contiene la batería de tests automatizados para la infraestructura y aplicaciones del proyecto **blinkchamber**, implementados con [Bats](https://github.com/bats-core/bats-core), un framework de testing para Bash.

## Estructura de los tests

- `infrastructure.bats`: Tests básicos de recursos de Kubernetes (nodos, pods, servicios, etc.)
- `vault.bats`: Tests de despliegue y estado de Vault y su integración con Kubernetes
- `applications.bats`: Tests de despliegue de aplicaciones principales (Mailu, Zitadel, Grafana)
- `security.bats`: Tests de políticas, roles y seguridad de Vault y Kubernetes
- `performance.bats`: Tests de rendimiento y recursos
- `integration.bats`: Tests de integración y comunicación entre servicios
- `chaos.bats`: Tests de resiliencia y recuperación ante fallos
- `compliance.bats`: Tests de cumplimiento, logs y certificados
- `syntax.bats`: Validación de sintaxis y herramientas

## Requisitos previos

- Tener acceso a un clúster Kubernetes con los recursos desplegados
- Herramientas instaladas: `kubectl`, `vault`, `helm`, `terraform`, `yamllint`, `jq`, `bats`

## Ejecución de los tests

Para ejecutar **todos los tests**:

```bash
bats tests/
```

Para ejecutar solo una categoría:

```bash
bats tests/infrastructure.bats
```

## Reporting avanzado

Puedes obtener reporting en formato **TAP** (por defecto), **JUnit XML** o **HTML** usando extensiones de Bats:

### 1. JUnit XML (para CI/CD)

Instala el plugin:

```bash
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local
bats --formatter junit tests/ > tests/results.xml
```

### 2. HTML (usando bats-html-reporter)

Instala el reporter:

```bash
git clone https://github.com/ztombol/bats-html-reporter.git
cd bats-html-reporter
sudo cp bats-html-report /usr/local/bin/
```

Ejecuta y genera el HTML:

```bash
bats tests/ | bats-html-report > tests/results.html
```

Abre `tests/results.html` en tu navegador para ver el reporte visual.

## Buenas prácticas

- Añade nuevos tests en el archivo correspondiente.
- Usa aserciones claras y mensajes descriptivos.
- Mantén los tests independientes y reproducibles.
- Integra los tests en tu pipeline de CI/CD para asegurar calidad continua.

## Referencias
- [Bats-core](https://github.com/bats-core/bats-core)
- [bats-assert](https://github.com/bats-core/bats-assert)
- [bats-html-reporter](https://github.com/ztombol/bats-html-reporter) 