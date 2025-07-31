# Integración de Email - Mailu

## Descripción

Este documento describe la integración del sistema de email completo en la plataforma BlinkChamber usando **Mailu**, que incluye:

- **Sistema completo de email**: SMTP, IMAP/POP3, Webmail
- **Nginx**: Servidor web y proxy reverso
- **Redis**: Cache y sesiones
- **PostgreSQL**: Base de datos para usuarios y configuración

## Arquitectura

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

## Componentes

### Mailu (Sistema Completo de Email)

**Servicios incluidos:**
- **SMTP (Postfix)**: Servidor de envío de correos
- **IMAP/POP3 (Dovecot)**: Servidor de acceso a correos
- **Webmail (Roundcube)**: Cliente web de correo electrónico
- **Nginx**: Servidor web y proxy reverso
- **Redis**: Cache y gestión de sesiones
- **PostgreSQL**: Base de datos para usuarios y configuración

**Puertos expuestos:**
- `25`: SMTP
- `587`: SMTP Submission
- `143`: IMAP
- `993`: IMAPS (IMAP con SSL)
- `110`: POP3
- `995`: POP3S (POP3 con SSL)
- `4190`: ManageSieve
- `80/443`: Webmail (HTTP/HTTPS)

**Características:**
- Sistema completo integrado
- Panel de administración web
- Gestión de dominios y usuarios
- Configuración automática de bases de datos
- Integración con Vault para secretos
- Alta disponibilidad con múltiples réplicas
- Certificados TLS automáticos

## Configuración de Vault

### Políticas necesarias

```hcl
# Política para Mailu
path "secret/data/mailu/*" {
  capabilities = ["read"]
}
```

### Secretos requeridos

```bash
# Secretos para Mailu
vault kv put secret/mailu secret_key="mailu_secret_key"
vault kv put secret/mailu admin_password="mailu_admin_password"
vault kv put secret/mailu/database password="mailu_db_password"
```

## Configuración de Base de Datos

### Relación con PostgreSQL HA

Mailu puede utilizar la misma instancia de **PostgreSQL HA** que ya está configurada en el proyecto, o crear su propia instancia de PostgreSQL:

- **ZITADEL**: Usa la base de datos `zitadel` para gestión de usuarios, organizaciones y aplicaciones
- **Mailu**: Puede usar la base de datos PostgreSQL HA existente o crear su propia instancia

### Configuración de base de datos

Mailu creará automáticamente las bases de datos necesarias durante el despliegue inicial. No es necesario crear manualmente las bases de datos.

### Integración con ZITADEL

ZITADEL está configurado para usar Mailu como servidor SMTP para el envío de notificaciones por email:

```yaml
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

Los secretos necesarios se configuran automáticamente con el script `setup-mailu-secrets.sh`.



## Despliegue

### 1. Habilitar Mailu

```yaml
# En values.yaml o en el entorno específico
mailu:
  enabled: true
```

### 2. Configurar dominios

```yaml
mailu:
  hostnames:
    - mail.tu-dominio.com
  domain: "tu-dominio.com"
```

### 3. Configurar secretos en Vault

```bash
# Crear los secretos necesarios
./scripts/setup-mailu-secrets.sh
```

### 4. Desplegar

```bash
# Desplegar el umbrella chart
helm upgrade --install blinkchamber . -f values.yaml
```

## Monitoreo y Logs

### Logs de Mailu

```bash
# Ver logs de Mailu
kubectl logs -f deployment/mailu -n blinkchamber

# Ver logs de componentes específicos
kubectl logs -f deployment/mailu-smtp -n blinkchamber
kubectl logs -f deployment/mailu-imap -n blinkchamber
kubectl logs -f deployment/mailu-webmail -n blinkchamber
```

### Métricas

Mailu expone métricas que pueden ser recopiladas por Prometheus:

- **SMTP**: Métricas de envío de correos
- **IMAP/POP3**: Métricas de conexiones y autenticaciones
- **Webmail**: Métricas de sesiones y usuarios activos

## Seguridad

### Configuraciones de seguridad implementadas

1. **Integración con Vault**: Todos los secretos se gestionan a través de Vault
2. **TLS/SSL**: Configuración automática de certificados con cert-manager
3. **Autenticación**: Integración con PostgreSQL para autenticación
4. **Cuotas**: Límites de almacenamiento por usuario
5. **Filtros**: Soporte para filtros de correo con Sieve
6. **Logs de auditoría**: Registro de todas las actividades

### Recomendaciones adicionales

1. **Configurar firewalls**: Restringir acceso a los puertos de email
2. **Monitoreo de spam**: Implementar filtros anti-spam
3. **Backup regular**: Configurar backups de las bases de datos
4. **Actualizaciones**: Mantener actualizado Mailu

## Troubleshooting

### Problemas comunes

1. **Error de conexión a base de datos**
   - Verificar que PostgreSQL esté funcionando
   - Comprobar credenciales en Vault
   - Verificar que las bases de datos existan

2. **Error de autenticación en Mailu**
   - Verificar configuración de usuarios en el panel de administración
   - Comprobar que las contraseñas estén configuradas correctamente
   - Revisar logs de Mailu

3. **Problemas de conectividad entre componentes**
   - Verificar que todos los servicios de Mailu estén funcionando
   - Comprobar configuración de red entre servicios
   - Verificar configuración de TLS

4. **Problemas con Ingress**
   - Verificar que cert-manager esté funcionando
   - Comprobar configuración de DNS
   - Revisar logs del ingress controller

### Comandos útiles

```bash
# Verificar estado de los pods
kubectl get pods -n blinkchamber | grep -E "mailu"

# Verificar servicios
kubectl get svc -n blinkchamber | grep -E "mailu"

# Verificar ingress
kubectl get ingress -n blinkchamber

# Verificar secretos de Vault
kubectl get secrets -n blinkchamber | grep -E "mailu"
```

## Referencias

- [Documentación oficial de Mailu](https://mailu.io/)
- [Guía de configuración de Vault](https://www.vaultproject.io/docs)
- [Documentación de cert-manager](https://cert-manager.io/docs/) 