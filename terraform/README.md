# Despliegue de Infraestructura con Terraform y Helm

Este directorio contiene los scripts y la configuración para desplegar una infraestructura de alta disponibilidad para ZITADEL y Vault utilizando Terraform y Helm.

## Requisitos

*   Terraform
*   Helm
*   kubectl
*   Un proveedor de nube (AWS, GCP, Azure, etc.) o un entorno local con capacidad para ejecutar máquinas virtuales.

## Estructura de Directorios

*   `modules/`: Contiene los módulos de Terraform para la red, la base de datos y el clúster de Kubernetes.
*   `deploy.sh`: Script para desplegar la infraestructura con Terraform.
*   `deploy-apps.sh`: Script para desplegar Vault y Zitadel con Helm.
*   `vault-init.sh`: Script para inicializar y desellar Vault.
*   `add-node.sh`: Script para añadir nuevos nodos a un clúster existente.

## Proceso de Despliegue

1.  **Configurar las variables de Terraform:**
    *   Cree un fichero `terraform.tfvars` en el directorio raíz de `terraform`.
    *   Defina las variables necesarias para su proveedor de nube o entorno local.

2.  **Desplegar la infraestructura:**
    ```bash
    ./deploy.sh
    ```

3.  **Inicializar Vault:**
    ```bash
    ./vault-init.sh
    ```

4.  **Desplegar las aplicaciones:**
    ```bash
    ./deploy-apps.sh
    ```

## Añadir un Nuevo Nodo

Para añadir un nuevo nodo al clúster, ejecute el siguiente script:

```bash
./add-node.sh
```
