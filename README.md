# Arquitectura de Alta Disponibilidad para ZITADEL y Vault

Este proyecto contiene los recursos para desplegar una arquitectura de alta disponibilidad de ZITADEL y HashiCorp Vault en un clúster de Kubernetes utilizando Helm.

## Requisitos Previos

*   Un clúster de Kubernetes.
*   Helm 3 instalado.
*   `kubectl` instalado y configurado para comunicarse con su clúster.
*   BATS instalado para ejecutar las pruebas.

## Despliegue

### 1. Desplegar Vault (Chart oficial HashiCorp)

1. Agrega el repositorio oficial de HashiCorp:

    ```bash
    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm repo update
    ```

2. Crea un archivo `vault-values.yaml` adaptado a tu entorno (ver ejemplo en este repositorio).

3. Despliega Vault en modo HA con el injector habilitado:

    ```bash
    helm upgrade --install vault hashicorp/vault -n blinkchamber --create-namespace -f vault-values.yaml
    ```

4. Verifica el estado de los pods:

    ```bash
    kubectl get pods -n blinkchamber
    ```

### 2. Inicializar y desellar Vault

Después de desplegar Vault, inicializa y desella el clúster:

1. **Inicializa Vault:**

    ```bash
    kubectl exec -n blinkchamber vault-0 -- vault operator init
    ```
    Guarda las claves de desellado y el root token en un lugar seguro.

2. **Desella cada nodo:**

    ```bash
    kubectl exec -n blinkchamber vault-0 -- vault operator unseal <clave1>
    kubectl exec -n blinkchamber vault-0 -- vault operator unseal <clave2>
    kubectl exec -n blinkchamber vault-0 -- vault operator unseal <clave3>

    kubectl exec -n blinkchamber vault-1 -- vault operator unseal <clave1>
    kubectl exec -n blinkchamber vault-1 -- vault operator unseal <clave2>
    kubectl exec -n blinkchamber vault-1 -- vault operator unseal <clave3>

    kubectl exec -n blinkchamber vault-2 -- vault operator unseal <clave1>
    kubectl exec -n blinkchamber vault-2 -- vault operator unseal <clave2>
    kubectl exec -n blinkchamber vault-2 -- vault operator unseal <clave3>
    ```

Cuando todos los nodos estén desellados, el clúster estará listo para usarse.

### 3. Desplegar ZITADEL

1. Agrega el repositorio oficial de ZITADEL:

    ```bash
    helm repo add zitadel https://charts.zitadel.com
    helm repo update
    ```

2. Crea un archivo `zitadel-values.yaml` adaptado a tu entorno (ver ejemplo en la documentación oficial o en este repositorio).

3. Despliega ZITADEL en modo HA:

    ```bash
    helm upgrade --install zitadel zitadel/zitadel --namespace identity --create-namespace -f zitadel-values.yaml
    ```

## Habilitar TLS para Producción

**¡IMPORTANTE!** No uses `tls_disable = true` en producción. Toda comunicación con Vault debe estar cifrada.

1. Elimina o comenta la línea `tls_disable = true` en tu `values.yaml` (en el bloque `extraConfig`).
2. Agrega la configuración de certificados TLS:

    ```yaml
    server:
      extraVolumes:
        - type: secret
          name: vault-tls
          path: /vault/userconfig/tls
      extraVolumeMounts:
        - name: vault-tls
          mountPath: /vault/userconfig/tls
          readOnly: true
      extraConfig: |
        listener "tcp" {
          address = "0.0.0.0:8200"
          cluster_address = "0.0.0.0:8201"
          tls_cert_file = "/vault/userconfig/tls/tls.crt"
          tls_key_file  = "/vault/userconfig/tls/tls.key"
          tls_disable   = false
        }
        ...
    ```

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

## Despliegue Automatizado con Script

Para facilitar el despliegue de Vault y ZITADEL, este repositorio incluye el script `deploy.sh` que orquesta todas las etapas necesarias:

```bash
./deploy.sh
```

El script permite ejecutar las siguientes etapas de forma interactiva:

1. Desplegar Vault (chart oficial, modo HA)
2. Inicializar y desellar Vault
3. Crear secret TLS para Vault
4. Desplegar ZITADEL (chart oficial, modo HA)
5. Crear secrets necesarios para ZITADEL (base de datos, token de Vault, TLS)
6. Desplegar infraestructura base (Terraform)
7. Desplegar PostgreSQL HA (Bitnami + Vault Injector)

**Notas:**
- Antes de crear los secrets, asegúrate de tener a mano las contraseñas y certificados necesarios.
- Puedes ejecutar cada etapa de forma independiente según el estado de tu clúster.
- Personaliza los archivos `vault-values.yaml`, `zitadel-values.yaml` y `postgresql-ha-values.yaml` según tu entorno.

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
