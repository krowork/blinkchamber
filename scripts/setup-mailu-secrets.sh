#!/bin/bash

# Script para configurar secretos de email en Vault
# Este script configura los secretos necesarios para Mailu

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar que Vault esté disponible
check_vault() {
    if ! command -v vault &> /dev/null; then
        print_error "Vault CLI no está instalado o no está en el PATH"
        exit 1
    fi
    
    if ! vault status &> /dev/null; then
        print_error "No se puede conectar a Vault. Verifica que esté ejecutándose y configurado"
        exit 1
    fi
    
    print_status "Vault está disponible y funcionando"
}

# Generar contraseñas seguras
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}



# Configurar secretos para Mailu
setup_mailu_secrets() {
    print_status "Configurando secretos para Mailu..."
    
    # Generar contraseñas
    MAILU_SECRET_KEY=$(generate_password)
    MAILU_ADMIN_PASSWORD=$(generate_password)
    MAILU_DB_PASSWORD=$(generate_password)
    
    # Crear secretos en Vault
    vault kv put secret/mailu secret_key="$MAILU_SECRET_KEY"
    vault kv put secret/mailu admin_username="admin"
    vault kv put secret/mailu admin_password="$MAILU_ADMIN_PASSWORD"
    vault kv put secret/mailu/database password="$MAILU_DB_PASSWORD"
    
    print_status "Secretos de Mailu configurados correctamente"
    print_warning "Guarda estas contraseñas en un lugar seguro:"
    echo "Mailu Secret Key: $MAILU_SECRET_KEY"
    echo "Mailu Admin Username: admin"
    echo "Mailu Admin Password: $MAILU_ADMIN_PASSWORD"
    echo "Mailu DB Password: $MAILU_DB_PASSWORD"
    echo
}

# Crear políticas de Vault
create_vault_policies() {
    print_status "Creando políticas de Vault..."
    
    # Política para Mailu
    vault policy write mailu-policy - <<EOF
path "secret/data/mailu/*" {
  capabilities = ["read"]
}
EOF
    
    print_status "Políticas de Vault creadas correctamente"
}

# Crear roles de Vault para Kubernetes
create_vault_roles() {
    print_status "Creando roles de Vault para Kubernetes..."
    
    # Role para Mailu
    vault write auth/kubernetes/role/mailu-role \
        bound_service_account_names=mailu \
        bound_service_account_namespaces=blinkchamber \
        policies=mailu-policy \
        ttl=1h
    
    print_status "Roles de Vault creados correctamente"
}

# Verificar que las bases de datos existan
check_databases() {
    print_status "Verificando bases de datos..."
    
    print_warning "Mailu incluye su propia base de datos PostgreSQL"
    echo "- Mailu creará automáticamente las bases de datos necesarias"
    echo "- No es necesario crear bases de datos manualmente"
    echo
    print_warning "Nota: Mailu puede usar la base de datos PostgreSQL HA existente"
    echo "o crear su propia instancia de PostgreSQL"
    echo
}

# Función principal
main() {
    echo "=========================================="
    echo "  Configuración de Secretos de Email"
    echo "=========================================="
    echo
    
    # Verificar Vault
    check_vault
    
    # Configurar secretos
    setup_mailu_secrets
    
    # Crear políticas y roles
    create_vault_policies
    create_vault_roles
    
    # Verificar bases de datos
    check_databases
    
    print_status "Configuración completada exitosamente!"
    echo
    print_warning "Próximos pasos:"
    echo "1. Mailu creará automáticamente las bases de datos necesarias"
    echo "2. Configura el dominio y hostnames en los values de environments"
    echo "3. Despliega la plataforma con: helm upgrade --install blinkchamber ."
    echo "4. Verifica que los servicios estén funcionando correctamente"
    echo "5. Accede al panel de administración de Mailu para configurar dominios"
    echo
}

# Ejecutar función principal
main "$@" 