#!/bin/bash

# scripts/lib/k8s.sh - Funciones específicas para Kubernetes

# Verificar que common.sh está cargado
if [[ -z "$PROJECT_ROOT" ]]; then
    echo "Error: common.sh debe cargarse primero"
    exit 1
fi

# Función para verificar conexión a Kubernetes
check_k8s_connection() {
    local cluster_name=${1:-$CLUSTER_NAME}
    
    progress "Verificando conexión a Kubernetes..."
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        error "No se puede conectar al cluster de Kubernetes"
        return 1
    fi
    
    local current_context=$(kubectl config current-context 2>/dev/null)
    if [[ "$current_context" != "kind-$cluster_name" ]]; then
        warning "Contexto actual ($current_context) no coincide con el esperado (kind-$cluster_name)"
    fi
    
    success "Conexión a Kubernetes verificada"
    debug "Contexto actual: $current_context"
    return 0
}

# Función para verificar que un namespace existe
check_namespace() {
    local namespace=$1
    
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        debug "Namespace $namespace existe"
        return 0
    else
        error "Namespace $namespace no existe"
        return 1
    fi
}

# Función para esperar que los pods estén ready
wait_for_pods() {
    local namespace=$1
    local selector=$2
    local timeout=${3:-300}
    
    progress "Esperando pods en namespace $namespace con selector $selector..."
    
    if ! kubectl wait --for=condition=Ready pods \
        -l "$selector" \
        -n "$namespace" \
        --timeout="${timeout}s" >/dev/null 2>&1; then
        error "Timeout esperando pods en $namespace"
        return 1
    fi
    
    success "Pods en $namespace están ready"
    return 0
}

# Función para verificar que un deployment está ready
check_deployment() {
    local deployment=$1
    local namespace=$2
    
    local ready=$(kubectl get deployment "$deployment" -n "$namespace" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    local desired=$(kubectl get deployment "$deployment" -n "$namespace" \
        -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
    
    if [[ "$ready" == "$desired" ]] && [[ "$ready" -gt 0 ]]; then
        debug "Deployment $deployment/$namespace está ready ($ready/$desired)"
        return 0
    else
        debug "Deployment $deployment/$namespace no está ready ($ready/$desired)"
        return 1
    fi
}

# Función para verificar que un servicio existe
check_service() {
    local service=$1
    local namespace=$2
    
    if kubectl get service "$service" -n "$namespace" >/dev/null 2>&1; then
        debug "Servicio $service/$namespace existe"
        return 0
    else
        debug "Servicio $service/$namespace no existe"
        return 1
    fi
}

# Función para verificar conectividad HTTP dentro del cluster
test_http_internal() {
    local url=$1
    local expected_status=${2:-200}
    local namespace=${3:-default}
    
    debug "Probando conectividad HTTP interna: $url"
    
    # Crear un pod temporal para hacer la prueba
    local test_pod="http-test-$(date +%s)"
    
    kubectl run "$test_pod" \
        --image=curlimages/curl:latest \
        --rm -i --restart=Never \
        --namespace="$namespace" \
        -- curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null
    
    local status=$?
    return $status
}

# Función para obtener logs de un deployment
get_deployment_logs() {
    local deployment=$1
    local namespace=$2
    local lines=${3:-50}
    
    kubectl logs "deployment/$deployment" -n "$namespace" --tail="$lines"
}

# Función para hacer port-forward
setup_port_forward() {
    local service=$1
    local namespace=$2
    local local_port=$3
    local remote_port=$4
    local background=${5:-true}
    
    # Detener port-forward existente
    pkill -f "kubectl port-forward.*$service.*$namespace" 2>/dev/null || true
    sleep 2
    
    progress "Configurando port-forward: $service/$namespace $local_port:$remote_port"
    
    if [[ "$background" == "true" ]]; then
        kubectl port-forward "svc/$service" -n "$namespace" \
            "$local_port:$remote_port" >/dev/null 2>&1 &
        local pf_pid=$!
        
        # Esperar un momento para verificar que el port-forward funcionó
        sleep 3
        if kill -0 "$pf_pid" 2>/dev/null; then
            success "Port-forward configurado en background (PID: $pf_pid)"
            return 0
        else
            error "Port-forward falló"
            return 1
        fi
    else
        kubectl port-forward "svc/$service" -n "$namespace" "$local_port:$remote_port"
    fi
}

# Función para aplicar manifiestos YAML
apply_manifest() {
    local manifest_file=$1
    local namespace=${2:-}
    
    if [[ ! -f "$manifest_file" ]]; then
        error "Archivo de manifiesto no encontrado: $manifest_file"
        return 1
    fi
    
    progress "Aplicando manifiesto: $manifest_file"
    
    local kubectl_cmd="kubectl apply -f $manifest_file"
    if [[ -n "$namespace" ]]; then
        kubectl_cmd="$kubectl_cmd -n $namespace"
    fi
    
    if run_command "$kubectl_cmd" "Aplicar manifiesto $manifest_file"; then
        success "Manifiesto aplicado: $manifest_file"
        return 0
    else
        error "Error aplicando manifiesto: $manifest_file"
        return 1
    fi
}

# Función para verificar que cert-manager está funcionando
check_cert_manager() {
    local namespace=${1:-cert-manager}
    
    progress "Verificando cert-manager..."
    
    # Verificar pods
    if ! wait_for_pods "$namespace" "app.kubernetes.io/name=cert-manager" 60; then
        return 1
    fi
    
    # Verificar ClusterIssuer
    if kubectl get clusterissuer ca-issuer >/dev/null 2>&1; then
        success "ClusterIssuer ca-issuer configurado"
    else
        warning "ClusterIssuer ca-issuer no encontrado"
    fi
    
    return 0
}

# Función para verificar que ingress-nginx está funcionando
check_ingress_nginx() {
    local namespace=${1:-ingress-nginx}
    
    progress "Verificando ingress-nginx..."
    
    # Verificar pods
    if ! wait_for_pods "$namespace" "app.kubernetes.io/name=ingress-nginx" 60; then
        return 1
    fi
    
    # Verificar que el servicio está disponible
    if check_service "ingress-nginx-controller" "$namespace"; then
        success "Ingress Controller está funcionando"
        return 0
    else
        error "Servicio de Ingress Controller no encontrado"
        return 1
    fi
}

# Función para limpiar recursos de Kubernetes
cleanup_k8s_resources() {
    local namespace=$1
    
    if [[ -n "$namespace" ]]; then
        progress "Limpiando recursos en namespace: $namespace"
        kubectl delete namespace "$namespace" --ignore-not-found=true
    else
        warning "Namespace no especificado para limpieza"
    fi
}

# Función para obtener información del cluster
get_cluster_info() {
    cat << EOF
Información del Cluster:
========================
Contexto actual: $(kubectl config current-context 2>/dev/null || echo "No disponible")
Nodos: $(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
Namespaces: $(kubectl get namespaces --no-headers 2>/dev/null | wc -l || echo "0")
Pods total: $(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
EOF
}

# Función para verificar recursos de un namespace
check_namespace_resources() {
    local namespace=$1
    
    log "Recursos en namespace: $namespace"
    echo "Pods:"
    kubectl get pods -n "$namespace" 2>/dev/null || echo "  No hay pods"
    echo "Services:"
    kubectl get services -n "$namespace" 2>/dev/null || echo "  No hay servicios"
    echo "Ingresses:"
    kubectl get ingresses -n "$namespace" 2>/dev/null || echo "  No hay ingresses"
}

debug "Biblioteca k8s.sh cargada" 