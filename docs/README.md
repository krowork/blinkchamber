# 📚 Documentación - BlinkChamber Platform

## 📋 Índice de Documentación

Esta sección contiene toda la documentación detallada de la plataforma BlinkChamber, organizada por temas para facilitar la navegación y consulta.

## 🏗️ Arquitectura y Diseño

### [🏗️ Arquitectura de Alta Disponibilidad](arquitectura.md)
- Arquitectura detallada de ZITADEL y Vault
- Configuración de alta disponibilidad
- Patrones de diseño implementados
- Diagramas de arquitectura

## 🔧 Configuración y Despliegue

### [🌍 Configuración por Entornos](environments.md)
- Gestión de diferentes entornos (dev, staging, prod)
- Configuraciones específicas por entorno
- Promoción entre entornos
- Scripts de automatización

### [📧 Sistema de Email Mailu](mailu-integration.md)
- Configuración completa del sistema de email
- Integración con SMTP, IMAP/POP3
- Webmail integrado
- Configuración de seguridad

## 📊 Observabilidad y Monitoreo

### [📊 Stack de Observabilidad](monitoring.md) ⭐ **NUEVO**
- Stack completo de monitoreo y logging
- Prometheus para métricas
- Grafana para visualización
- Loki para logs centralizados
- Promtail para recolección de logs
- Dashboards pre-configurados
- Alertas configuradas

### [🔴 Integración Redis-ZITADEL](redis-integration.md)
- Configuración y uso de Redis con ZITADEL
- Event streaming con colas de prioridad
- Configuración de alta disponibilidad
- Optimización de rendimiento

## 🗄️ Almacenamiento

### [💾 Almacenamiento Longhorn](storage.md)
- Configuración de almacenamiento distribuido
- Volúmenes para videos
- Replicación automática
- Gestión de capacidad

## 🚀 CI/CD y Automatización

### [🔄 CI/CD Pipeline](ci-cd.md)
- Pipeline de CI/CD con ArgoCD y Tekton
- Automatización de despliegues
- Gestión de secretos
- Rollback automático

## 🔍 Guías de Troubleshooting

### Problemas Comunes

#### Vault
- [Vault no se inicializa](arquitectura.md#inicialización-de-vault)
- [Problemas de autenticación](arquitectura.md#autenticación-de-kubernetes)

#### PostgreSQL
- [PostgreSQL no arranca](arquitectura.md#postgresql-ha)
- [Problemas de replicación](arquitectura.md#replicación)

#### ZITADEL
- [ZITADEL no se conecta](arquitectura.md#zitadel)
- [Problemas de eventos](redis-integration.md#event-streaming)

#### Monitoreo
- [Grafana no carga dashboards](monitoring.md#troubleshooting)
- [Prometheus no recopila métricas](monitoring.md#verificación-de-estado)
- [Logs no aparecen en Loki](monitoring.md#consultas-de-logs)

## 🚀 Guías de Inicio Rápido

### Despliegue Inicial
1. [Crear clúster Kind](../README.md#🚀-despliegue-rápido)
2. [Instalar plataforma](../README.md#🚀-despliegue-rápido)
3. [Configurar Vault](../README.md#🔐-configuración-post-despliegue)
4. [Acceder a interfaces](../README.md#🌐-acceso-a-servicios)

### Configuración de Monitoreo
1. [Acceder a Grafana](monitoring.md#🌐-acceso-a-interfaces)
2. [Verificar dashboards](monitoring.md#📈-dashboards-disponibles)
3. [Configurar alertas](monitoring.md#🚨-alertas-configuradas)
4. [Consultar logs](monitoring.md#📝-logs-centralizados)

## 📖 Referencias Externas

### Documentación Oficial
- [Vault Documentation](https://www.vaultproject.io/docs)
- [ZITADEL Documentation](https://zitadel.com/docs)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)

### Herramientas y Tecnologías
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Longhorn Documentation](https://longhorn.io/docs/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Redis Documentation](https://redis.io/documentation)

## 🤝 Contribuir

### Cómo Contribuir
1. Fork el repositorio
2. Crea una rama para tu feature
3. Actualiza la documentación correspondiente
4. Commit tus cambios
5. Push a la rama
6. Abre un Pull Request

### Estándares de Documentación
- Usar Markdown con emojis para mejor legibilidad
- Incluir ejemplos de código cuando sea posible
- Mantener enlaces actualizados
- Seguir la estructura de navegación establecida

---

**📚 Esta documentación se actualiza constantemente. Si encuentras algún error o tienes sugerencias, por favor abre un issue o contribuye con un Pull Request.**
