# Infraestructura base con Kind y Terraform

## 1. Crear el clúster Kind

```bash
kind create cluster --name blinkchamber
```

## 2. Verifica el contexto de kubeconfig

```bash
kubectl config get-contexts
# Debe aparecer kind-blinkchamber
```

## 3. Aplica la infraestructura base con Terraform

```bash
cd terraform/kind
terraform init
terraform apply
```

Esto creará el namespace `infra`, instalará cert-manager y nginx-ingress, y dejará listo el proveedor Helm para instalar charts (Vault, Zitadel, etc.) en el clúster Kind.

---

## Automatización de Vault (policies y roles)

Todos los archivos `.tf` en este directorio se aplican juntos automáticamente. Esto incluye la automatización de policies y roles de Vault necesarios para que el Vault Injector funcione con PostgreSQL y Zitadel.

- **vault-policies.tf** define:
  - Las policies de acceso a secretos para PostgreSQL y Zitadel.
  - Los roles de autenticación de Kubernetes para ambos servicios, vinculando los ServiceAccounts y namespaces correctos.

No es necesario incluir manualmente este archivo en `main.tf`: Terraform lo detecta y aplica junto con el resto de la infraestructura.

---

## Siguientes pasos

1. Despliega la infraestructura base con Terraform (opción 1 del script `deploy.sh`).
2. Continúa con el despliegue de Vault, PostgreSQL y Zitadel siguiendo el flujo del script.
3. Los pods de PostgreSQL y Zitadel podrán obtener sus secretos directamente desde Vault usando Vault Injector, gracias a la configuración automatizada. 