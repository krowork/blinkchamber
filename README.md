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

## Documentación

Para obtener una descripción detallada de la arquitectura, consulte el archivo `arquitectura_ha_zitadel_vault.md`.
