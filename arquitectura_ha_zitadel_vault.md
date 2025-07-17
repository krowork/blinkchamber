```markdown
# Arquitectura de Alta Disponibilidad para ZITADEL y Vault

## 1. Resumen

Esta documentación describe una arquitectura de alta disponibilidad (HA) para ZITADEL y HashiCorp Vault. El objetivo es proporcionar un sistema de autenticación y autorización robusto y tolerante a fallos, así como una gestión segura de los secretos.

## 2. Componentes

La arquitectura se compone de los siguientes elementos:

*   **ZITADEL:** Un clúster de al menos dos nodos de ZITADEL.
*   **PostgreSQL:** Una base de datos PostgreSQL de alta disponibilidad con replicación en streaming.
*   **Vault:** Un clúster de al menos tres nodos de Vault con el backend de almacenamiento integrado (Raft).
*   **Balanceador de Carga:** Un balanceador de carga para distribuir el tráfico entre los nodos de ZITADEL.

## 3. Arquitectura

### 3.1. ZITADEL

*   Se desplegará un clúster de al menos dos nodos de ZITADEL.
*   Cada nodo de ZITADEL ejecutará una instancia del software de ZITADEL.
*   Los nodos de ZITADEL se conectarán a la base de datos PostgreSQL de alta disponibilidad.
*   Se utilizará un balanceador de carga para distribuir el tráfico entre los nodos de ZITADEL.

### 3.2. Vault

*   Se desplegará un clúster de Vault de al menos tres nodos.
*   El clúster de Vault utilizará el backend de almacenamiento integrado (Raft) para la alta disponibilidad.
*   ZITADEL se configurará para obtener su `masterkey` de Vault en el momento del inicio. Esto se puede hacer utilizando el proveedor de secretos de Vault para Kubernetes o recuperando el secreto a través de la API de Vault y proporcionándolo a ZITADEL como una variable de entorno.

### 3.3. PostgreSQL

*   Se utilizará una base de datos PostgreSQL de alta disponibilidad.
*   Se recomienda utilizar la replicación en streaming con un mecanismo de conmutación por error automático, como Patroni o pg_auto_failover.

## 4. Configuración

### 4.1. ZITADEL

La configuración de ZITADEL debe incluir:

*   La cadena de conexión a la base de datos PostgreSQL de alta disponibilidad.
*   La configuración para obtener la `masterkey` de Vault.

### 4.2. Vault

La configuración de Vault debe incluir:

*   La configuración del backend de almacenamiento Raft.
*   Políticas y roles de autenticación para permitir que ZITADEL acceda a la `masterkey`.

## 5. Procedimientos Operativos

### 5.1. Despliegue

El despliegue de la arquitectura se puede automatizar utilizando herramientas como Terraform y Ansible.

#### Inyección de Secretos con Vault

Para gestionar los secretos de forma segura, utilizamos el inyector de secretos de Vault. Este componente se ejecuta en Kubernetes y utiliza un sidecar para inyectar secretos directamente en los pods de las aplicaciones.

##### Flujo de trabajo

1.  **Habilitar el inyector de Vault**: El chart de Helm de Vault (`vault-chart`) ha sido modificado para incluir y habilitar el inyector de secretos.
2.  **Anotaciones en Zitadel**: El `deployment.yaml` de Zitadel (`zitadel-chart`) ha sido anotado para que el inyector de Vault sepa que debe actuar sobre él. Las anotaciones especifican el rol de Vault a utilizar y los secretos a inyectar.
3.  **Montaje de volumen**: Un volumen `emptyDir` se monta en el pod de Zitadel en `/vault/secrets`. El sidecar de Vault escribe los secretos en este volumen.
4.  **Consumo de secretos**: Zitadel ha sido configurado para leer los secretos desde los ficheros en `/vault/secrets` en lugar de variables de entorno o secretos de Kubernetes.

##### Despliegue

Para desplegar la solución completa, sigue los pasos del `README.md` de Terraform. El inyector de Vault y las anotaciones de Zitadel se configurarán automáticamente.

### 5.2. Monitorización

Es esencial monitorizar la salud y el rendimiento de todos los componentes de la arquitectura. Se recomienda utilizar Prometheus para la recopilación de métricas y Grafana para la visualización.

#### 5.2.1. Métricas de ZITADEL

ZITADEL expone métricas en formato Prometheus. Algunas de las métricas clave a monitorizar son:

*   `zitadel_build_info`: Información sobre la compilación de ZITADEL.
*   `zitadel_http_requests_total`: Número total de peticiones HTTP.
*   `zitadel_grpc_server_handled_total`: Número total de peticiones gRPC manejadas.
*   `zitadel_system_started_users_total`: Número total de usuarios iniciados en el sistema.

#### 5.2.2. Métricas de Vault

Vault también expone métricas en formato Prometheus. Algunas de las métricas clave a monitorizar son:

*   `vault_core_unsealed`: Indica si el Vault está desprecintado.
*   `vault_core_ha_mode`: Modo de alta disponibilidad de Vault.
*   `vault_raft_storage_is_leader`: Indica si el nodo de Vault es el líder del clúster Raft.
*   `vault_audit_log_request_count`: Número de peticiones de registro de auditoría.

#### 5.2.3. Alertas

Se deben configurar alertas para notificar a los administradores de los siguientes eventos:

*   Un nodo de ZITADEL o Vault deja de estar disponible.
*   El Vault se sella.
*   La base de datos de PostgreSQL no está disponible.
*   Aumento de la latencia o de la tasa de errores.

### 5.3. Copia de Seguridad y Recuperación

Se deben establecer procedimientos regulares de copia de seguridad y recuperación para la base de datos de PostgreSQL y los datos de Vault.

## 6. Consideraciones de Seguridad

*   Toda la comunicación entre los componentes debe estar encriptada utilizando TLS.
*   El acceso a los nodos de Vault y a la base de datos de PostgreSQL debe estar estrictamente controlado.
*   La `masterkey` de ZITADEL debe ser tratada como un secreto de alta sensibilidad.

## 7. Conclusión

Esta arquitectura proporciona una base sólida para un sistema de autenticación y autorización de alta disponibilidad utilizando ZITADEL y Vault. Es importante adaptar la arquitectura a los requisitos específicos de su organización y realizar pruebas exhaustivas antes de la implementación en producción.
```
