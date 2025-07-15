# 🔍 Validación de Sintaxis - blinkchamber v2.2

## 📋 Resumen

Este documento describe la nueva funcionalidad de **validación de sintaxis** agregada al sistema de tests exhaustivos de blinkchamber. Esta funcionalidad permite validar la sintaxis de todos los archivos de configuración antes de ejecutar los tests de infraestructura.

## 🎯 Objetivo

La validación de sintaxis tiene como objetivo:

- **Detectar errores temprano**: Encontrar problemas de sintaxis antes de ejecutar tests costosos
- **Mejorar la calidad del código**: Asegurar que todos los archivos de configuración sean válidos
- **Prevenir fallos en producción**: Evitar despliegues con archivos malformados
- **Mantener consistencia**: Asegurar que todos los archivos sigan las mejores prácticas

## 🛠️ Herramientas de Validación

### Herramientas Principales

| Herramienta | Propósito | Archivos Validados |
|-------------|-----------|-------------------|
| **terraform** | Validación de configuración Terraform | `.tf`, `.tfvars` |
| **helm** | Validación de charts de Helm | `Chart.yaml`, `values.yaml`, templates |
| **yamllint** | Validación de sintaxis YAML | `.yaml`, `.yml` |
| **jq** | Validación de sintaxis JSON | `.json` |
| **bash** | Validación de sintaxis Bash | `.sh` |

### Herramientas Opcionales

| Herramienta | Propósito | Archivos Validados |
|-------------|-----------|-------------------|
| **shellcheck** | Análisis estático de scripts Bash | `.sh` |
| **terraform fmt** | Formato de código Terraform | `.tf` |

## 🚀 Uso

### 1. Instalar Herramientas

```bash
# Instalar todas las herramientas
./scripts/install-syntax-tools.sh --all

# Instalar herramientas específicas
./scripts/install-syntax-tools.sh --terraform --helm --yamllint

# Verificar herramientas instaladas
./scripts/install-syntax-tools.sh --check
```

### 2. Ejecutar Tests de Sintaxis

```bash
# Ejecutar solo tests de sintaxis
./scripts/test-infrastructure-exhaustive.sh syntax

# Ejecutar todos los tests incluyendo sintaxis
./scripts/test-infrastructure-exhaustive.sh all

# Simular tests de sintaxis (dry-run)
./scripts/test-infrastructure-exhaustive.sh syntax --dry-run

# Tests de sintaxis con modo verbose
./scripts/test-infrastructure-exhaustive.sh syntax --verbose
```

### 3. Usar el Script de Ejemplo

```bash
# Mostrar ayuda y información
./scripts/test-syntax-example.sh

# Instalar herramientas y ejecutar tests
./scripts/test-syntax-example.sh --install-tools --run-syntax

# Verificar herramientas instaladas
./scripts/test-syntax-example.sh --check-tools
```

## 📁 Archivos Validados

### Terraform

```bash
# Validación de todas las fases
terraform/phases/01-bootstrap/
terraform/phases/02-vault-init/
terraform/phases/03-secrets/
terraform/phases/04-applications/

# Validación de módulos
terraform/modules/*/
```

**Tests incluidos:**
- `terraform validate` en cada fase
- `terraform fmt -check` para formato
- Validación de sintaxis de variables y outputs

### Helm Charts

```bash
# Validación del chart principal
blinkchamber/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── *.yaml
    └── *.tpl
```

**Tests incluidos:**
- `helm lint` para validación de sintaxis
- `helm template --dry-run` para validación de templates

### YAML

```bash
# Archivos de configuración
config/
├── blinkchamber.yaml
├── kind-config.yaml
└── environment.example

# Charts de Helm
blinkchamber/
├── values.yaml
└── templates/*.yaml

# Terraform
terraform/**/*.yaml
```

**Tests incluidos:**
- `yamllint` con configuración personalizada
- Validación de indentación y formato
- Verificación de valores booleanos

### JSON

```bash
# Archivos de resultados de tests
test-results/*.json

# Archivos de Terraform
terraform/**/*.json
```

**Tests incluidos:**
- `jq` para validación de sintaxis
- Verificación de estructura JSON válida

### Bash Scripts

```bash
# Scripts principales
scripts/
├── *.sh
└── lib/
    └── *.sh
```

**Tests incluidos:**
- `bash -n` para validación de sintaxis
- Verificación de sintaxis sin ejecución

## ⚙️ Configuración

### Configuración de yamllint

El archivo `.yamllint` en la raíz del proyecto define las reglas de validación:

```yaml
extends: default

rules:
  line-length:
    max: 120
    level: warning
  
  document-start: disable
  trailing-spaces: enable
  
  truthy:
    check-keys: false
    allowed-values: ['true', 'false', 'yes', 'no', 'on', 'off']
  
  indentation:
    spaces: 2
    indent-sequences: true
  
  quotes:
    quote-type: single
    required: false
```

### Configuración de Terraform

Cada fase de Terraform incluye validación automática:

```hcl
# En cada main.tf
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
    # ... otros providers
  }
}
```

## 📊 Reportes

### Estructura del Reporte

Los tests de sintaxis generan reportes en el mismo formato que los otros tests:

```html
<!-- Reporte HTML -->
<div class="test-item success">
    <strong>Terraform Validate (01-bootstrap)</strong> - Test completado exitosamente
    <br><small class="timestamp">Duración: 2s | 2024-01-15 10:30:45</small>
</div>

<div class="test-item failure">
    <strong>YAML Syntax (config)</strong> - Test falló después de 3 intentos
    <br><small class="timestamp">Duración: 1s | 2024-01-15 10:30:46</small>
    <br><b>Categoría:</b> Sintaxis
    <br><b>Sugerencia:</b> Revisar indentación en línea 15
    <br><pre>config/blinkchamber.yaml:15:1: error: wrong indentation</pre>
</div>
```

### Archivos de Salida

```bash
test-results/
├── infrastructure_test_20240115_103045.html    # Reporte HTML
├── infrastructure_test_20240115_103045.log     # Log detallado
└── infrastructure_test_20240115_103045.summary # Resumen
```

## 🔧 Troubleshooting

### Problemas Comunes

#### 1. Herramientas No Instaladas

**Síntomas:**
```
[WARN] Syntax Tools Check - Herramientas faltantes: yamllint jq
```

**Solución:**
```bash
./scripts/install-syntax-tools.sh --all
```

#### 2. Error de Sintaxis YAML

**Síntomas:**
```
[FAIL] YAML Syntax (config) - Test falló después de 3 intentos
Categoría: Sintaxis
Sugerencia: Revisar indentación en línea 15
```

**Solución:**
```bash
# Verificar sintaxis manualmente
yamllint config/blinkchamber.yaml

# Corregir indentación
# Usar 2 espacios, no tabs
```

#### 3. Error de Validación Terraform

**Síntomas:**
```
[FAIL] Terraform Validate (01-bootstrap) - Test falló después de 3 intentos
```

**Solución:**
```bash
# Validar manualmente
cd terraform/phases/01-bootstrap
terraform init -backend=false
terraform validate

# Corregir errores de sintaxis
terraform fmt
```

#### 4. Error de Helm Lint

**Síntomas:**
```
[FAIL] Helm Lint (blinkchamber) - Test falló después de 3 intentos
```

**Solución:**
```bash
# Validar manualmente
helm lint blinkchamber/

# Corregir errores en Chart.yaml o templates
```

### Logs de Debug

Para obtener más información sobre los errores:

```bash
# Modo verbose
./scripts/test-infrastructure-exhaustive.sh syntax --verbose

# Modo debug
DEBUG=true ./scripts/test-infrastructure-exhaustive.sh syntax

# Ver logs detallados
tail -f test-results/infrastructure_test_*.log
```

## 📈 Métricas y KPIs

### Métricas de Calidad

| Métrica | Descripción | Objetivo |
|---------|-------------|----------|
| **Tasa de Éxito** | Porcentaje de tests de sintaxis exitosos | > 95% |
| **Tiempo de Validación** | Tiempo total de validación de sintaxis | < 30s |
| **Errores por Archivo** | Número promedio de errores por archivo | < 0.1 |
| **Cobertura** | Porcentaje de archivos validados | 100% |

### Dashboard de Monitoreo

Los reportes HTML incluyen métricas en tiempo real:

```html
<div class="metrics">
    <div class="metric">
        <div class="metric-value" id="total-tests">15</div>
        <div>Total Tests</div>
    </div>
    <div class="metric">
        <div class="metric-value" id="passed-tests">14</div>
        <div>Exitosos</div>
    </div>
    <div class="metric">
        <div class="metric-value" id="failed-tests">1</div>
        <div>Fallidos</div>
    </div>
</div>
```

## 🔄 Integración con CI/CD

### GitHub Actions

```yaml
name: Syntax Validation
on: [push, pull_request]

jobs:
  syntax-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install tools
        run: ./scripts/install-syntax-tools.sh --all
      
      - name: Run syntax tests
        run: ./scripts/test-infrastructure-exhaustive.sh syntax
      
      - name: Upload results
        uses: actions/upload-artifact@v3
        with:
          name: syntax-test-results
          path: test-results/
```

### GitLab CI

```yaml
syntax_validation:
  stage: test
  script:
    - ./scripts/install-syntax-tools.sh --all
    - ./scripts/test-infrastructure-exhaustive.sh syntax
  artifacts:
    reports:
      junit: test-results/*.xml
    paths:
      - test-results/
```

## 📚 Referencias

### Documentación Oficial

- [Terraform Validate](https://www.terraform.io/docs/cli/commands/validate.html)
- [Helm Lint](https://helm.sh/docs/helm/helm_lint/)
- [yamllint](https://yamllint.readthedocs.io/)
- [jq Manual](https://stedolan.github.io/jq/manual/)
- [ShellCheck](https://www.shellcheck.net/)

### Mejores Prácticas

- **Terraform**: Usar `terraform fmt` antes de commits
- **YAML**: Mantener indentación consistente (2 espacios)
- **JSON**: Validar con `jq` antes de usar
- **Bash**: Usar `shellcheck` para análisis estático

## 🤝 Contribución

### Agregar Nuevas Validaciones

Para agregar validación de nuevos tipos de archivos:

1. **Agregar herramienta** en `install-syntax-tools.sh`
2. **Implementar test** en `run_syntax_tests()`
3. **Actualizar documentación** en este archivo
4. **Agregar ejemplos** en `test-syntax-example.sh`

### Ejemplo de Extensión

```bash
# Agregar validación de Dockerfiles
run_single_test "Dockerfile Syntax" "find . -name 'Dockerfile' -exec hadolint {} \\;"
```

## 📜 Licencia

MIT License - ver [LICENSE](../LICENSE) para más detalles.

---

> **Nota**: La validación de sintaxis es una capa adicional de seguridad que complementa los tests de infraestructura existentes. Se recomienda ejecutar estos tests antes de cada despliegue para asegurar la calidad del código. 