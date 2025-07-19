# 🚀 BlinkChamber Platform - Chart Umbrella

Este es un **chart umbrella** (padre) que despliega una plataforma completa de alta disponibilidad con ZITADEL, Vault, PostgreSQL y componentes de infraestructura.

## 🎯 ¿Qué incluye?

### 📦 Componentes del Chart Umbrella:

1. **🔐 Cert-Manager** - Gestión automática de certificados TLS
2. **🌐 Nginx-Ingress** - Controlador de ingress para Kubernetes
3. **🗄️ Vault HA** - Gestión de secretos con alta disponibilidad (3 réplicas)
4. **🐘 PostgreSQL HA** - Base de datos de alta disponibilidad (3 réplicas + 2 PgPool)
5. **🆔 ZITADEL** - Plataforma de identidad y autenticación (2+ réplicas)

### 🔧 Características:

- **Gestión unificada** de versiones y dependencias
- **Configuración centralizada** en un solo `values.yaml`
- **Vault Injector** para gestión segura de secretos
- **Alta disponibilidad** en todos los componentes críticos
- **Despliegue con un solo comando**

## 🚀 Despliegue Rápido

### 1. Instalar la plataforma completa:

```bash
./deploy-umbrella.sh install
```

### 2. Verificar el estado:

```bash
./deploy-umbrella.sh status
```

### 3. Ver logs:

```bash
./deploy-umbrella.sh logs
```

## 📋 Comandos Disponibles

| Comando | Descripción |
|---------|-------------|
| `install` | Instalar la plataforma completa |
| `upgrade` | Actualizar la plataforma |
| `uninstall` | Desinstalar la plataforma |
| `status` | Ver estado de todos los componentes |
| `logs` | Ver logs de todos los componentes |
| `help` | Mostrar ayuda |

## 🔧 Configuración

### Personalizar valores:

Edita el archivo `values.yaml` para ajustar la configuración:

```yaml
# Habilitar/deshabilitar componentes
cert-manager:
  enabled: true

vault:
  enabled: true
  server:
    ha:
      replicas: 3  # Número de réplicas de Vault

zitadel:
  enabled: true
  replicaCount: 2  # Número de réplicas de ZITADEL
```

### Configuración por entorno:

Puedes crear archivos de valores específicos:

```bash
# Desarrollo
helm upgrade --install blinkchamber . -f values.yaml -f values-dev.yaml

# Producción
helm upgrade --install blinkchamber . -f values.yaml -f values-prod.yaml
```

## 🔐 Configuración Post-Despliegue

### 1. Inicializar Vault:

```bash
# Inicializar Vault (guarda las claves de desello)
kubectl exec -n blinkchamber vault-0 -- vault operator init

# Desellar Vault (necesitarás las claves del paso anterior)
kubectl exec -n blinkchamber vault-0 -- vault operator unseal
```

### 2. Configurar autenticación de Kubernetes:

```bash
# Habilitar auth de Kubernetes
kubectl exec -n blinkchamber vault-0 -- vault auth enable kubernetes

# Configurar policies (usando los ConfigMaps creados)
kubectl exec -n blinkchamber vault-0 -- vault policy write postgres-policy /tmp/postgres-policy.hcl
kubectl exec -n blinkchamber vault-0 -- vault policy write zitadel-policy /tmp/zitadel-policy.hcl
```

### 3. Crear secretos en Vault:

```bash
# Secretos para PostgreSQL
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/postgres password="tu-password-seguro"

# Secretos para ZITADEL
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/zitadel/postgres password="tu-password-zitadel"
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/zitadel/vault token="tu-token-vault"
```

## 🌐 Acceso a Servicios

| Servicio | URL | Descripción |
|----------|-----|-------------|
| Vault UI | `https://vault.blinkchamber.svc:8200` | Interfaz web de Vault |
| ZITADEL | `https://zitadel.tu-dominio.com` | Plataforma de identidad |
| PostgreSQL | `postgresql-ha-postgresql.database.svc:5432` | Base de datos |

## 📊 Monitorización

### Ver estado general:

```bash
kubectl get pods -A -l app.kubernetes.io/part-of=blinkchamber-platform
```

### Logs específicos:

```bash
# Logs de Vault
kubectl logs -n blinkchamber -l app.kubernetes.io/name=vault

# Logs de ZITADEL
kubectl logs -n identity -l app.kubernetes.io/name=zitadel

# Logs de PostgreSQL
kubectl logs -n database -l app.kubernetes.io/name=postgresql-ha
```

## 🔄 Actualizaciones

### Actualizar dependencias:

```bash
helm dependency update
```

### Actualizar la plataforma:

```bash
./deploy-umbrella.sh upgrade
```

## 🗑️ Desinstalación

```bash
./deploy-umbrella.sh uninstall
```

**⚠️ Advertencia**: Esto eliminará todos los datos. Asegúrate de hacer backup antes.

## 📁 Estructura del Chart

```
.
├── Chart.yaml              # Metadatos y dependencias
├── values.yaml             # Configuración principal
├── deploy-umbrella.sh      # Script de despliegue
├── templates/
│   ├── namespaces.yaml     # Namespaces necesarios
│   ├── vault-policies.yaml # Policies y roles de Vault
│   ├── postgresql-entrypoint-configmap.yaml # Entrypoint para PostgreSQL
│   └── notes.txt           # Notas post-instalación
└── charts/                 # Subcharts descargados automáticamente
```

## 🔧 Troubleshooting

### Problemas comunes:

1. **Vault no se inicializa**: Verifica que el pod esté corriendo y ejecuta `vault operator init`
2. **PostgreSQL no arranca**: Verifica que Vault esté desellado y los secretos estén creados
3. **ZITADEL no se conecta**: Verifica la configuración de la base de datos y los tokens de Vault

### Logs de debug:

```bash
# Ver todos los eventos
kubectl get events -A --sort-by='.lastTimestamp'

# Ver logs detallados
kubectl logs -n blinkchamber vault-0 --previous
```

## 📚 Documentación Adicional

- [Arquitectura detallada](arquitectura_ha_zitadel_vault.md)
- [Configuración de Vault](https://www.vaultproject.io/docs)
- [Documentación de ZITADEL](https://zitadel.com/docs)
- [PostgreSQL HA](https://github.com/bitnami/charts/tree/main/bitnami/postgresql-ha)

## 🤝 Contribuir

1. Fork el repositorio
2. Crea una rama para tu feature
3. Commit tus cambios
4. Push a la rama
5. Abre un Pull Request

---

**🎉 ¡Disfruta de tu plataforma de alta disponibilidad!** 