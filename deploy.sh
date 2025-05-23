#!/bin/bash

# Script de despliegue automatizado para Stereo Service
# Autor: Generated for hello-sun project
# Fecha: $(date +%Y-%m-%d)

set -e  # Salir en caso de error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes con color
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar que gcloud esté instalado
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI no está instalado. Instálalo desde https://cloud.google.com/sdk"
    exit 1
fi

# Verificar que docker esté instalado
if ! command -v docker &> /dev/null; then
    print_error "Docker no está instalado. Instálalo desde https://docker.com"
    exit 1
fi

# Variables por defecto (puedes modificarlas)
PROJECT_ID=${PROJECT_ID:-"tu-proyecto-id"}
REGION=${REGION:-"us-central1"}
SERVICE_NAME=${SERVICE_NAME:-"stereo-service"}
REPOSITORY_NAME=${REPOSITORY_NAME:-"stereo-repo"}

print_status "=== Despliegue de Stereo Service ==="
echo "Proyecto: $PROJECT_ID"
echo "Región: $REGION"
echo "Servicio: $SERVICE_NAME"
echo "Repositorio: $REPOSITORY_NAME"
echo ""

# Verificar que las variables de entorno estén configuradas
if [ -z "$SUPABASE_URL" ]; then
    print_warning "SUPABASE_URL no está configurada"
fi

if [ -z "$SUPABASE_SERVICE_ROLE_KEY" ]; then
    print_warning "SUPABASE_SERVICE_ROLE_KEY no está configurada"
fi

print_status "Configurando proyecto de Google Cloud..."
gcloud config set project $PROJECT_ID

print_status "Habilitando APIs necesarias..."
gcloud services enable artifactregistry.googleapis.com
gcloud services enable run.googleapis.com

print_status "Creando repositorio en Artifact Registry (si no existe)..."
gcloud artifacts repositories create $REPOSITORY_NAME \
    --repository-format=docker \
    --location=$REGION \
    --description="Repositorio para el servicio de estéreo" \
    --quiet || print_warning "El repositorio ya existe"

print_status "Configurando Docker para usar Artifact Registry..."
gcloud auth configure-docker $REGION-docker.pkg.dev

print_status "Construyendo imagen Docker..."
docker build -t $SERVICE_NAME .

print_status "Etiquetando imagen para Artifact Registry..."
docker tag $SERVICE_NAME $REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_NAME/$SERVICE_NAME:latest

print_status "Subiendo imagen a Artifact Registry..."
docker push $REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_NAME/$SERVICE_NAME:latest

print_status "Desplegando en Cloud Run..."
gcloud run deploy $SERVICE_NAME \
    --image $REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_NAME/$SERVICE_NAME:latest \
    --platform managed \
    --region $REGION \
    --allow-unauthenticated \
    --set-env-vars "SUPABASE_URL=${SUPABASE_URL:-https://tu-proyecto.supabase.co},SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_SERVICE_ROLE_KEY:-tu-service-key},BUCKET_NAME=crop-images" \
    --port 8000 \
    --memory 1Gi \
    --project=$PROJECT_ID

# Obtener la URL del servicio desplegado
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format='value(status.url)')

print_success "¡Despliegue completado!"
echo ""
echo "🌐 URL del servicio: $SERVICE_URL"
echo "📚 Documentación: $SERVICE_URL/docs"
echo "🏥 Health check: $SERVICE_URL/health"
echo ""
print_status "Configuración para el frontend:"
echo "VITE_STEREO_SERVICE_URL=$SERVICE_URL"
echo ""
print_status "Comandos útiles:"
echo "  Ver logs: gcloud logging read \"resource.type=cloud_run_revision AND resource.labels.service_name=$SERVICE_NAME\" --limit=10"
echo "  Actualizar servicio: ./deploy.sh"
echo ""
print_success "¡Listo para usar!" 