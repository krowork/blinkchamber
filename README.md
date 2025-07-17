# Arquitectura de Alta Disponibilidad para ZITADEL y Vault

Este proyecto contiene los recursos para desplegar una arquitectura de alta disponibilidad de ZITADEL y HashiCorp Vault en un clúster de Kubernetes utilizando Helm.

## Requisitos Previos

*   Un clúster de Kubernetes.
*   Helm 3 instalado.
*   `kubectl` instalado y configurado para comunicarse con su clúster.
*   BATS instalado para ejecutar las pruebas.

## Despliegue

1.  **Desplegar ZITADEL:**

    ```bash
    helm install zitadel ./zitadel-chart
    ```

2.  **Desplegar Vault:**

    ```bash
    helm install vault ./vault-chart
    ```

## Pruebas

Para ejecutar las pruebas de BATS, ejecute el siguiente comando:

```bash
bats tests/test_architecture.bats
```

Las pruebas verificarán lo siguiente:

*   Que los despliegues de ZITADEL y Vault tengan el número correcto de réplicas.
*   Que todos los pods de ZITADEL y Vault estén en estado "Running".
*   Que los servicios de ZITADEL y Vault sean accesibles.
*   Que no haya errores en los logs de los pods de ZITADEL y Vault.
*   Que ZITADEL y Vault sigan estando disponibles después de un fallo de un nodo.
*   Que ZITADEL siga estando disponible después de un fallo de la base de datos.

## Documentación

Para obtener una descripción detallada de la arquitectura, consulte el archivo `arquitectura_ha_zitadel_vault.md`.
