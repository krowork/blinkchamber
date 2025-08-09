# 📧 Sistema de Email Mailu

## 📋 Resumen

Esta documentación describe la integración completa del sistema de email en la plataforma BlinkChamber usando **Mailu**, que proporciona un sistema completo de email con SMTP, IMAP/POP3, Webmail y gestión de dominios.

## 🎯 Características del Sistema de Email

### 📧 Servicios Incluidos
- **SMTP (Postfix)**: Servidor de envío de correos
- **IMAP/POP3 (Dovecot)**: Servidor de acceso a correos
- **Webmail (Roundcube)**: Cliente web de correo electrónico
- **Nginx**: Servidor web y proxy reverso
- **Redis**: Cache y gestión de sesiones
- **PostgreSQL**: Base de datos para usuarios y configuración

### 🌐 Puertos Expuestos
- `25`: SMTP
- `587`: SMTP Submission
- `143`: IMAP
- `993`: IMAPS (IMAP con SSL)
- `110`: POP3
- `995`: POP3S (POP3 con SSL)
- `4190`: ManageSieve
- `80/443`: Webmail (HTTP/HTTPS)

### ✨ Características Avanzadas
- Sistema completo integrado
- Panel de administración web
- Gestión de dominios y usuarios
- Configuración automática de bases de datos
- Integración con Vault para secretos
- Alta disponibilidad con múltiples réplicas
- Certificados TLS automáticos

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│                           ZITADEL                              │
│                      (Identity Platform)                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                           MAILU                                │
│                    (Complete Email Stack)                      │
│                                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │
│  │    SMTP     │  │  IMAP/POP3  │  │   Webmail   │           │
│  │  (Postfix)  │  │  (Dovecot)  │  │ (Roundcube) │           │
│  └─────────────┘  └─────────────┘  └─────────────┘           │
│                                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │
│  │    Nginx    │  │    Redis    │  │ PostgreSQL  │           │
│  │   (Proxy)   │  │   (Cache)   │  │  (Database) │           │
│  └─────────────┘  └─────────────┘  └─────────────┘           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Vault                                  │
│                   (Gestión de secretos)                        │
└─────────────────────────────────────────────────────────────────┘
```

## 🔧 Configuración

### 1. Habilitar Mailu

```yaml
# En values.yaml o en el entorno específico
mailu:
  enabled: true
  hostnames:
    - mail.tu-dominio.com
  domain: "tu-dominio.com"
  secretKey: "mailu-secret-key"
  adminPassword: "admin-password"
```

### 2. Configuración de Dominios

```yaml
mailu:
  hostnames:
    - mail.tu-dominio.com
    - smtp.tu-dominio.com
    - imap.tu-dominio.com
  domain: "tu-dominio.com"
  subdomains:
    - "mail"
    - "smtp"
    - "imap"
```

### 3. Configuración de Base de Datos

Mailu puede utilizar la misma instancia de **PostgreSQL HA** que ya está configurada en el proyecto:

```yaml
mailu:
  database:
    type: postgresql
    host: postgresql-ha-postgresql.database.svc.cluster.local
    port: 5432
    name: mailu
    user: mailu
    password:
      valueFromFile: /vault/secrets/MAILU_DB_PASSWORD
```

### 4. Configuración de Redis

```yaml
mailu:
  redis:
    host: redis-master.database.svc.cluster.local
    port: 6379
    password:
      valueFromFile: /vault/secrets/REDIS_PASSWORD
    database: 2  # Base de datos separada para Mailu
```

## 🔐 Configuración de Vault

### Políticas Necesarias

```hcl
# Política para Mailu
path "secret/data/mailu/*" {
  capabilities = ["read"]
}

# Política para acceso a base de datos
path "secret/data/postgres/*" {
  capabilities = ["read"]
}

# Política para acceso a Redis
path "secret/data/redis/*" {
  capabilities = ["read"]
}
```

### Secretos Requeridos

```bash
# Secretos para Mailu
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/mailu secret_key="mailu_secret_key"
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/mailu admin_password="mailu_admin_password"
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/mailu/database password="mailu_db_password"

# O usar el script automatizado
./scripts/setup-mailu-secrets.sh
```

### Anotaciones de Vault

```yaml
podAnnotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "mailu-role"
  vault.hashicorp.com/agent-inject-secret-MAILU_SECRET_KEY: "secret/data/mailu#secret_key"
  vault.hashicorp.com/agent-inject-secret-MAILU_ADMIN_PASSWORD: "secret/data/mailu#admin_password"
  vault.hashicorp.com/agent-inject-secret-MAILU_DB_PASSWORD: "secret/data/mailu/database#password"
  vault.hashicorp.com/agent-inject-secret-REDIS_PASSWORD: "secret/data/redis#password"
```

## 🔗 Integración con ZITADEL

### Configuración de Notificaciones por Email

ZITADEL está configurado para usar Mailu como servidor SMTP para el envío de notificaciones por email:

```yaml
zitadel:
  config:
    notifications:
      email:
        enabled: true
        smtp:
          host: "blinkchamber-platform-mailu-front.blinkchamber.svc"
          port: 587
          user:
            valueFromFile: /vault/secrets/SMTP_USER
          password:
            valueFromFile: /vault/secrets/SMTP_PASSWORD
          startTLS: true
          from: "noreply@blinkchamber.local"
          replyTo: "support@blinkchamber.local"
```

### Tipos de Notificaciones

- **Verificación de email**: Confirmación de dirección de email
- **Recuperación de contraseña**: Envío de enlaces de reset
- **Notificaciones de seguridad**: Alertas de login sospechoso
- **Notificaciones administrativas**: Cambios en la cuenta

## 🚀 Despliegue

### 1. Desplegar con Helm

```bash
# Desplegar el umbrella chart con Mailu habilitado
helm upgrade --install blinkchamber . -f values.yaml

# O desplegar solo Mailu
helm upgrade --install mailu . -f values.yaml --set mailu.enabled=true
```

### 2. Configurar Secretos

```bash
# Configurar secretos automáticamente
./scripts/setup-mailu-secrets.sh

# O configurar manualmente
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/mailu secret_key="$(openssl rand -hex 32)"
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/mailu admin_password="$(openssl rand -base64 32)"
kubectl exec -n blinkchamber vault-0 -- vault kv put secret/data/mailu/database password="$(openssl rand -base64 32)"
```

### 3. Verificar Despliegue

```bash
# Verificar pods de Mailu
kubectl get pods -n blinkchamber -l app.kubernetes.io/name=mailu

# Verificar servicios
kubectl get svc -n blinkchamber -l app.kubernetes.io/name=mailu

# Verificar ingress
kubectl get ingress -n blinkchamber
```

## 📊 Monitorización y Logs

### Logs de Mailu

```bash
# Ver logs de Mailu
kubectl logs -f deployment/mailu -n blinkchamber

# Ver logs de componentes específicos
kubectl logs -f deployment/mailu-smtp -n blinkchamber
kubectl logs -f deployment/mailu-imap -n blinkchamber
kubectl logs -f deployment/mailu-webmail -n blinkchamber
kubectl logs -f deployment/mailu-front -n blinkchamber
```

### Métricas

Mailu expone métricas que pueden ser recopiladas por Prometheus:

```yaml
# Métricas de SMTP
mailu_smtp_connections_total
mailu_smtp_messages_sent_total
mailu_smtp_errors_total

# Métricas de IMAP/POP3
mailu_imap_connections_total
mailu_imap_authentications_total
mailu_imap_errors_total

# Métricas de Webmail
mailu_webmail_sessions_total
mailu_webmail_users_active
mailu_webmail_errors_total
```

### Comandos de Monitorización

```bash
# Verificar estado de los pods
kubectl get pods -n blinkchamber | grep -E "mailu"

# Verificar servicios
kubectl get svc -n blinkchamber | grep -E "mailu"

# Verificar ingress
kubectl get ingress -n blinkchamber

# Verificar secretos de Vault
kubectl get secrets -n blinkchamber | grep -E "mailu"

# Verificar logs de errores
kubectl logs -n blinkchamber -l app.kubernetes.io/name=mailu --tail=100 | grep -i error
```

## 🔒 Seguridad

### Configuraciones de Seguridad Implementadas

1. **Integración con Vault**: Todos los secretos se gestionan a través de Vault
2. **TLS/SSL**: Configuración automática de certificados con cert-manager
3. **Autenticación**: Integración con PostgreSQL para autenticación
4. **Cuotas**: Límites de almacenamiento por usuario
5. **Filtros**: Soporte para filtros de correo con Sieve
6. **Logs de auditoría**: Registro de todas las actividades

### Configuración de TLS

```yaml
mailu:
  tls:
    enabled: true
    certManager:
      enabled: true
      issuer: letsencrypt-prod
    secretName: mailu-tls
```

### Configuración de Firewall

```yaml
# Puertos recomendados para abrir
- 25   # SMTP
- 587  # SMTP Submission
- 143  # IMAP
- 993  # IMAPS
- 110  # POP3
- 995  # POP3S
- 4190 # ManageSieve
- 80   # HTTP
- 443  # HTTPS
```

### Recomendaciones Adicionales

1. **Configurar firewalls**: Restringir acceso a los puertos de email
2. **Monitoreo de spam**: Implementar filtros anti-spam
3. **Backup regular**: Configurar backups de las bases de datos
4. **Actualizaciones**: Mantener actualizado Mailu
5. **Monitoreo de logs**: Configurar alertas para actividades sospechosas

## 🛠️ Troubleshooting

### Problemas Comunes

#### 1. Error de conexión a base de datos
```bash
# Verificar que PostgreSQL esté funcionando
kubectl get pods -n database -l app.kubernetes.io/name=postgresql-ha

# Comprobar credenciales en Vault
kubectl exec -n blinkchamber vault-0 -- vault kv get secret/data/mailu/database

# Verificar que las bases de datos existan
kubectl exec -n database postgresql-ha-postgresql-0 -- psql -U postgres -l | grep mailu
```

#### 2. Error de autenticación en Mailu
```bash
# Verificar configuración de usuarios en el panel de administración
kubectl port-forward -n blinkchamber svc/mailu-front 8080:80

# Comprobar que las contraseñas estén configuradas correctamente
kubectl exec -n blinkchamber vault-0 -- vault kv get secret/data/mailu

# Revisar logs de Mailu
kubectl logs -n blinkchamber -l app.kubernetes.io/name=mailu | grep -i auth
```

#### 3. Problemas de conectividad entre componentes
```bash
# Verificar que todos los servicios de Mailu estén funcionando
kubectl get pods -n blinkchamber -l app.kubernetes.io/name=mailu

# Comprobar configuración de red entre servicios
kubectl exec -n blinkchamber mailu-front-0 -- nc -zv mailu-smtp.blinkchamber.svc 25
kubectl exec -n blinkchamber mailu-front-0 -- nc -zv mailu-imap.blinkchamber.svc 143

# Verificar configuración de TLS
kubectl get certificates -n blinkchamber
```

#### 4. Problemas con Ingress
```bash
# Verificar que cert-manager esté funcionando
kubectl get pods -n cert-manager

# Comprobar configuración de DNS
nslookup mail.tu-dominio.com

# Revisar logs del ingress controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### Comandos de Diagnóstico

```bash
# Verificar estado general
kubectl get pods,svc,ingress -n blinkchamber -l app.kubernetes.io/name=mailu

# Verificar eventos
kubectl get events -n blinkchamber --sort-by='.lastTimestamp' | grep mailu

# Verificar configuración
kubectl get configmap -n blinkchamber -l app.kubernetes.io/name=mailu -o yaml

# Verificar secretos
kubectl get secrets -n blinkchamber -l app.kubernetes.io/name=mailu
```

## 📧 Configuración de Clientes

### Configuración de Cliente de Email

#### Configuración SMTP (Envío)
- **Servidor**: `smtp.tu-dominio.com` o `mail.tu-dominio.com`
- **Puerto**: `587` (STARTTLS) o `465` (SSL)
- **Seguridad**: STARTTLS o SSL/TLS
- **Autenticación**: Usuario y contraseña

#### Configuración IMAP (Recepción)
- **Servidor**: `imap.tu-dominio.com` o `mail.tu-dominio.com`
- **Puerto**: `143` (STARTTLS) o `993` (SSL)
- **Seguridad**: STARTTLS o SSL/TLS
- **Autenticación**: Usuario y contraseña

#### Configuración POP3 (Recepción)
- **Servidor**: `mail.tu-dominio.com`
- **Puerto**: `110` (STARTTLS) o `995` (SSL)
- **Seguridad**: STARTTLS o SSL/TLS
- **Autenticación**: Usuario y contraseña

### Acceso Webmail

- **URL**: `https://mail.tu-dominio.com`
- **Usuario**: Tu dirección de email completa
- **Contraseña**: Tu contraseña de email

## 📚 Referencias

- [Documentación oficial de Mailu](https://mailu.io/)
- [Guía de configuración de Vault](https://www.vaultproject.io/docs)
- [Documentación de cert-manager](https://cert-manager.io/docs/)
- [Configuración de Postfix](http://www.postfix.org/documentation.html)
- [Configuración de Dovecot](https://doc.dovecot.org/)

---

**🎉 ¡El sistema de email Mailu está listo para proporcionar servicios de email completos y seguros!**
