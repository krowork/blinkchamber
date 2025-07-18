# Arquitectura de Alta Disponibilidad para ZITADEL y Vault

Este proyecto contiene los recursos para desplegar una arquitectura de alta disponibilidad de ZITADEL y HashiCorp Vault en un clúster de Kubernetes utilizando Helm y Terraform, con gestión segura de secretos mediante Vault Injector.

## Requisitos Previos

*   Un clúster de Kubernetes (puedes usar Kind para desarrollo local).
*   Helm 3 instalado.
*   `kubectl` instalado y configurado para comunicarse con su clúster.
*   Terraform instalado.
*   BATS instalado para ejecutar las pruebas.

## Despliegue Automatizado

El flujo recomendado es completamente automatizado y seguro:

1. **Infraestructura base con Terraform**
    - Provisiona namespaces, cert-manager, nginx-ingress y automatiza la configuración de policies y roles de Vault necesarios para Vault Injector.
    - Ejecuta:
      ```bash
      ./deploy.sh
      # Opción 1: Desplegar infraestructura base (Terraform)
      ```
    - Todos los archivos `.tf` en `terraform/kind/` se aplican juntos, incluyendo la automatización de Vault.

2. **TLS y Vault**
    - Crea el secret TLS para Vault (opción 2 del script).
    - Despliega Vault con Helm (opción 3).
    - Inicializa y desella Vault (opción 4).

3. **Base de datos y aplicaciones**
    - Despliega PostgreSQL HA con Vault Injector (opción 5).
    - Despliega ZITADEL con Vault Injector (opción 6).

4. **Vault Injector**
    - Los pods de PostgreSQL y Zitadel obtienen sus secretos directamente desde Vault, sin usar Kubernetes secrets.
    - Las policies y roles de Vault se crean automáticamente con Terraform (ver `terraform/kind/vault-policies.tf`).

## Ejemplo de flujo con el script

```bash
./deploy.sh
```

El script permite ejecutar cada etapa de forma interactiva y segura.

## Personalización de valores

- Personaliza los archivos `vault-values.yaml`, `zitadel-values.yaml` y `postgresql-ha-values.yaml` según tu entorno y necesidades.
- Los values ya están preparados para usar Vault Injector y no dependen de Kubernetes secrets para credenciales sensibles.

## Habilitar TLS para Producción

**¡IMPORTANTE!** No uses `tls_disable = true` en producción. Toda comunicación con Vault debe estar cifrada.

1. Elimina o comenta la línea `tls_disable = true` en tu `values.yaml` (en el bloque `extraConfig`).
2. Agrega la configuración de certificados TLS (ver ejemplo en este repositorio).
3. Crea un Secret de Kubernetes con tus certificados:

    ```bash
    kubectl create secret generic vault-tls \
      --from-file=tls.crt=</ruta/a/tu/certificado.crt> \
      --from-file=tls.key=</ruta/a/tu/clave.key> \
      -n blinkchamber
    ```

4. Actualiza el despliegue de Vault:

    ```bash
    helm upgrade vault hashicorp/vault -n blinkchamber -f vault-values.yaml
    ```

## Pruebas

Para ejecutar las pruebas de BATS, ejecute el siguiente comando:

```bash
bats tests/test_exhaustive.bats
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
