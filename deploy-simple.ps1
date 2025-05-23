# Script de despliegue para PowerShell
Write-Host "=== Desplegando Stereo Service ===" -ForegroundColor Green

# Variables
$PROJECT_ID = "gen-lang-client-0720673337"
$REGION = "us-central1"
$SERVICE_NAME = "stereo-service"
$IMAGE = "us-central1-docker.pkg.dev/$PROJECT_ID/stereo-repo/$SERVICE_NAME"

Write-Host "Proyecto: $PROJECT_ID" -ForegroundColor Cyan
Write-Host "Región: $REGION" -ForegroundColor Cyan
Write-Host "Servicio: $SERVICE_NAME" -ForegroundColor Cyan

# Nota: DEBES configurar estas variables con tus valores reales de Supabase
Write-Host ""
Write-Host "IMPORTANTE: Debes configurar las variables de entorno de Supabase:" -ForegroundColor Yellow
Write-Host "- SUPABASE_URL=https://tu-proyecto.supabase.co" -ForegroundColor Yellow
Write-Host "- SUPABASE_SERVICE_ROLE_KEY=tu-service-role-key" -ForegroundColor Yellow
Write-Host ""
Write-Host "Para configurar estas variables, usa:" -ForegroundColor Yellow
Write-Host "gcloud run deploy $SERVICE_NAME --image $IMAGE --platform managed --region $REGION --allow-unauthenticated --port 8000 --memory 1Gi --timeout 300 --set-env-vars BUCKET_NAME=crop-images,SUPABASE_URL=https://tu-proyecto.supabase.co,SUPABASE_SERVICE_ROLE_KEY=tu-key" -ForegroundColor Yellow
Write-Host ""

# Despliegue básico (sin Supabase por ahora para probar)
Write-Host "Desplegando sin variables de Supabase para diagnosticar..." -ForegroundColor Cyan

$env_vars = "BUCKET_NAME=crop-images"

# Comando completo
$command = "gcloud run deploy $SERVICE_NAME --image $IMAGE --platform managed --region $REGION --allow-unauthenticated --port 8000 --memory 1Gi --timeout 300 --set-env-vars $env_vars"

Write-Host "Ejecutando: $command" -ForegroundColor Gray
Invoke-Expression $command

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=== DESPLIEGUE COMPLETADO ===" -ForegroundColor Green
    
    # Obtener URL del servicio
    $service_url = gcloud run services describe $SERVICE_NAME --region=$REGION --format="value(status.url)"
    
    Write-Host "URL del servicio: $service_url" -ForegroundColor Green
    Write-Host "Documentación: $service_url/docs" -ForegroundColor Green
    Write-Host "Health check: $service_url/health" -ForegroundColor Green
    Write-Host ""
    Write-Host "Para el frontend, configura:" -ForegroundColor Cyan
    Write-Host "VITE_STEREO_SERVICE_URL=$service_url" -ForegroundColor Cyan
} else {
    Write-Host "ERROR: El despliegue falló" -ForegroundColor Red
} 