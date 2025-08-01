#!/bin/bash

# Script para verificar la instalación y funcionamiento de Longhorn
# Uso: ./scripts/verify-longhorn.sh

set -e

echo "🔍 Verificando instalación de Longhorn..."

# Verificar que Longhorn esté instalado
echo "📋 Verificando pods de Longhorn..."
kubectl get pods -n longhorn-system

# Verificar StorageClasses
echo "💾 Verificando StorageClasses..."
kubectl get storageclass

# Verificar que el StorageClass de videos esté disponible
echo "🎥 Verificando StorageClass para videos..."
kubectl get storageclass longhorn-videos

# Verificar volúmenes persistentes
echo "📦 Verificando PersistentVolumeClaims de videos..."
kubectl get pvc -l app=video-storage

# Verificar nodos de Longhorn
echo "🖥️ Verificando nodos de Longhorn..."
kubectl get nodes -l longhorn.io/node=true

# Verificar configuración de Longhorn
echo "⚙️ Verificando configuración de Longhorn..."
kubectl get configmap -n longhorn-system longhorn-default-setting

# Verificar que la UI esté disponible
echo "🌐 Verificando acceso a la UI de Longhorn..."
kubectl get svc -n longhorn-system longhorn-frontend

echo "✅ Verificación completada!"
echo ""
echo "📊 Para acceder a la UI de Longhorn:"
echo "   kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80"
echo "   Luego abre http://localhost:8080 en tu navegador"
echo ""
echo "📈 Para monitorear volúmenes:"
echo "   kubectl get volumes -n longhorn-system"
echo "   kubectl get replicas -n longhorn-system" 