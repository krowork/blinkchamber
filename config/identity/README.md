# Zitadel Identity Provider Configuration

Esta carpeta contiene los manifiestos de Kubernetes para Zitadel, el proveedor de identidad del sistema BlinChamber.

## Archivos

- `zitadel.yaml` - Deployment, Service y Secret principales de Zitadel
- `ingress.yaml` - Configuración de Ingress para acceso HTTP/HTTPS

## Configuración

### Variables de Entorno

Zitadel se configura principalmente a través de variables de entorno:

- `ZITADEL_MASTERKEY` - Clave maestra para encriptación (desde Secret)
- `ZITADEL_DATABASE_POSTGRES_*` - Configuración de conexión a PostgreSQL
- `ZITADEL_EXTERNALDOMAIN` - Dominio externo (localhost para desarrollo)
- `ZITADEL_TLS_ENABLED` - TLS deshabilitado para desarrollo

### Dependencias

Zitadel requiere que estén desplegados previamente:

1. **PostgreSQL** (namespace: database)
   - Service: `postgresql.database.svc.cluster.local:5432`
   - Base de datos: `postgres` (se crea automáticamente tabla `zitadel`)

2. **Ingress Controller** (namespace: ingress-nginx)
   - Para enrutamiento HTTP/HTTPS

3. **cert-manager** (namespace: cert-manager)
   - Para certificados TLS automáticos

### Secretos

Los secretos se almacenan en el Secret `zitadel-secrets`:

- `postgres-password` - Contraseña de PostgreSQL (base64)
- `master-key` - Clave maestra de Zitadel (base64)

### Acceso

**URLs de acceso:**
- HTTP: http://localhost/ (puerto 80)
- HTTPS: https://zitadel.blinkchamber.local/
- Consola Admin: http://localhost/ui/console/

**Para usar HTTPS:**
```bash
echo '127.0.0.1 zitadel.blinkchamber.local' | sudo tee -a /etc/hosts
```

## Despliegue

### Opción 1: Terraform (Recomendado)
```bash
cd terraform/05-identity
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Opción 2: kubectl directo
```bash
kubectl apply -f config/identity/zitadel.yaml
kubectl apply -f config/identity/ingress.yaml
```

## Verificación

Verificar que Zitadel esté funcionando:

```bash
# Verificar pods
kubectl get pods -n identity

# Verificar logs
kubectl logs -f deployment/zitadel -n identity

# Verificar health check
curl -s http://localhost/debug/healthz

# Verificar UI
curl -s http://localhost/ | grep -i zitadel
```

## Configuración Inicial

Al acceder por primera vez a Zitadel:

1. Ir a http://localhost/ui/console/
2. Configurar usuario administrador inicial
3. Configurar organización
4. Crear aplicaciones OAuth/OIDC

## Integración con Vault

Los secretos de Zitadel pueden almacenarse en Vault:

```bash
# Configurar secretos en Vault
vault kv put secret/zitadel/database \
  host="postgresql.database.svc.cluster.local" \
  port="5432" \
  database="postgres" \
  username="postgres" \
  password="..."

vault kv put secret/zitadel/config \
  master_key="..." \
  domain="zitadel.blinkchamber.local"
```

## Troubleshooting

### Pod no inicia
```bash
kubectl describe pod -n identity -l app=zitadel
kubectl logs -n identity -l app=zitadel
```

### Error de conexión a base de datos
```bash
kubectl exec -it postgresql-0 -n database -- psql -U postgres -c "\l"
```

### Ingress no funciona
```bash
kubectl get ingress -n identity
kubectl describe ingress zitadel-ingress -n identity
```

### Certificados TLS
```bash
kubectl get certificates -n identity
kubectl describe certificate zitadel-tls -n identity
``` 