# Script de despliegue con variables de Supabase
# Reemplaza estos valores con los de tu proyecto Supabase

param(
    [Parameter(Mandatory=$true)]
    [string]$SupabaseUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$SupabaseServiceKey
)

Write-Host "=== Desplegando Stereo Service con Supabase ===" -ForegroundColor Green
Write-Host "Proyecto: gen-lang-client-0720673337" -ForegroundColor Yellow
Write-Host "Región: us-central1" -ForegroundColor Yellow
Write-Host "Servicio: stereo-service" -ForegroundColor Yellow
Write-Host ""

# Construir la imagen
Write-Host "Construyendo imagen..." -ForegroundColor Blue
gcloud builds submit --tag us-central1-docker.pkg.dev/gen-lang-client-0720673337/stereo-repo/stereo-service:latest .

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Falló la construcción de la imagen" -ForegroundColor Red
    exit 1
}

# Desplegar con variables de entorno
Write-Host "Desplegando servicio..." -ForegroundColor Blue
gcloud run deploy stereo-service `
    --image us-central1-docker.pkg.dev/gen-lang-client-0720673337/stereo-repo/stereo-service:latest `
    --platform managed `
    --region us-central1 `
    --allow-unauthenticated `
    --port 8000 `
    --memory 1Gi `
    --timeout 300 `
    --set-env-vars "SUPABASE_URL=$SupabaseUrl,SUPABASE_SERVICE_ROLE_KEY=$SupabaseServiceKey,BUCKET_NAME=crop-images"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Despliegue exitoso!" -ForegroundColor Green
    Write-Host "URL del servicio: https://stereo-service-161581788026.us-central1.run.app" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Probando endpoint de health..." -ForegroundColor Blue
    try {
        $response = Invoke-WebRequest -Uri "https://stereo-service-161581788026.us-central1.run.app/health" -Method GET
        $content = $response.Content | ConvertFrom-Json
        Write-Host "Status: $($content.status)" -ForegroundColor Green
        Write-Host "Supabase conectado: $($content.supabase_connected)" -ForegroundColor $(if($content.supabase_connected) {"Green"} else {"Yellow"})
        Write-Host "YOLO cargado: $($content.yolo_loaded)" -ForegroundColor $(if($content.yolo_loaded) {"Green"} else {"Red"})
    }
    catch {
        Write-Host "Error probando el servicio: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "ERROR: El despliegue falló" -ForegroundColor Red
    exit 1
} 