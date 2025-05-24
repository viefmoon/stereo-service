#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Script completo de despliegue para Stereo Service en Google Cloud Run

.DESCRIPTION
    Este script despliega automáticamente el servicio de procesamiento de imágenes estereoscópicas
    en Google Cloud Run con todas las configuraciones necesarias.

.PARAMETER SupabaseUrl
    URL del proyecto Supabase (ej: https://tu-proyecto.supabase.co)

.PARAMETER SupabaseServiceKey
    Clave de servicio de Supabase (service_role key)

.PARAMETER ProjectId
    ID del proyecto de Google Cloud

.PARAMETER Force
    Fuerza el redespliegue sin confirmación

.EXAMPLE
    .\deploy.ps1
    .\deploy.ps1 -ProjectId "mi-proyecto" -SupabaseUrl "https://mi-proyecto.supabase.co" -SupabaseServiceKey "mi-clave"
    .\deploy.ps1 -Force
#>

param(
    [string]$SupabaseUrl,
    [string]$SupabaseServiceKey,
    [string]$ProjectId = "gen-lang-client-0720673337",
    [switch]$Force
)

# ================================================================================================
# CONFIGURACIÓN Y CONSTANTES
# ================================================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Configuración del proyecto
$REGION = "us-central1"
$SERVICE_NAME = "stereo-service"
$REPOSITORY_NAME = "stereo-repo"
$IMAGE_TAG = "latest"
$BUCKET_NAME = "crop-images"

# Colores para output
$Colors = @{
    Success = "Green"
    Error = "Red" 
    Warning = "Yellow"
    Info = "Cyan"
    Header = "Magenta"
    Accent = "Blue"
}

# ================================================================================================
# FUNCIONES AUXILIARES
# ================================================================================================

function Write-StatusMessage {
    param([string]$Message, [string]$Type = "Info")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = $Colors[$Type]
    $prefix = switch ($Type) {
        "Success" { "[OK]" }
        "Error" { "[ERROR]" }
        "Warning" { "[WARN]" }
        "Info" { "[INFO]" }
        "Header" { "[DEPLOY]" }
        "Accent" { "[CONFIG]" }
    }
    Write-Host "[$timestamp] $prefix $Message" -ForegroundColor $color
}

function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Test-DockerRunning {
    try {
        # Método simple y directo: docker ps
        $result = docker ps 2>&1
        
        # Si no hay error y el comando ejecutó exitosamente
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
        
        # Intentar docker version como método alternativo
        $versionResult = docker version 2>&1
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
        
        return $false
    }
    catch {
        return $false
    }
}

function Get-SecureInput {
    param([string]$Prompt)
    $secure = Read-Host $Prompt -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $value = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    return $value
}

function Invoke-CommandWithRetry {
    param(
        [string]$Command,
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 5
    )
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Write-StatusMessage "Ejecutando: $Command (Intento $i/$MaxRetries)" "Info"
            Invoke-Expression $Command
            if ($LASTEXITCODE -eq 0) {
                return $true
            }
        }
        catch {
            Write-StatusMessage "Error en intento $i : $($_.Exception.Message)" "Warning"
        }
        
        if ($i -lt $MaxRetries) {
            Write-StatusMessage "Reintentando en $DelaySeconds segundos..." "Warning"
            Start-Sleep $DelaySeconds
        }
    }
    
    return $false
}

function Test-GoogleCloudAuth {
    try {
        $account = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
        return -not [string]::IsNullOrEmpty($account)
    }
    catch {
        return $false
    }
}

function Test-ProjectExists {
    param([string]$ProjectId)
    try {
        gcloud projects describe $ProjectId 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# ================================================================================================
# VALIDACIONES PREVIAS
# ================================================================================================

function Test-Prerequisites {
    Write-StatusMessage "Verificando prerrequisitos..." "Header"
    
    $allGood = $true
    
    # Verificar gcloud CLI
    if (-not (Test-Command "gcloud")) {
        Write-StatusMessage "Google Cloud CLI no está instalado. Descárgalo desde: https://cloud.google.com/sdk" "Error"
        $allGood = $false
    } else {
        Write-StatusMessage "Google Cloud CLI encontrado" "Success"
    }
    
    # Verificar Docker
    if (-not (Test-Command "docker")) {
        Write-StatusMessage "Docker no está instalado. Descárgalo desde: https://docker.com" "Error"
        $allGood = $false
    } else {
        Write-StatusMessage "Docker encontrado" "Success"
    }
    
    # Verificar que Docker esté corriendo
    if (-not (Test-Command "docker")) {
        Write-StatusMessage "Docker no esta instalado. Descargalo desde: https://docker.com" "Error"
        $allGood = $false
    } elseif (-not (Test-DockerRunning)) {
        Write-StatusMessage "Docker esta instalado pero no esta funcionando correctamente." "Error"
        Write-StatusMessage "Por favor:" "Error"
        Write-StatusMessage "1. Verifica que Docker Desktop este abierto" "Error"
        Write-StatusMessage "2. Espera a que termine de inicializar completamente" "Error"
        Write-StatusMessage "3. Prueba ejecutar: docker ps" "Error"
        Write-StatusMessage "4. Si el comando anterior funciona, vuelve a ejecutar este script" "Error"
        $allGood = $false
    } else {
        Write-StatusMessage "Docker esta corriendo correctamente" "Success"
    }
    
    # Verificar autenticación de Google Cloud
    if (-not (Test-GoogleCloudAuth)) {
        Write-StatusMessage "No estás autenticado en Google Cloud. Ejecuta: gcloud auth login" "Error"
        $allGood = $false
    } else {
        Write-StatusMessage "Autenticado en Google Cloud" "Success"
    }
    
    # Verificar que el proyecto existe
    if (-not (Test-ProjectExists $ProjectId)) {
        Write-StatusMessage "El proyecto '$ProjectId' no existe o no tienes acceso." "Error"
        $allGood = $false
    } else {
        Write-StatusMessage "Proyecto '$ProjectId' accesible" "Success"
    }
    
    return $allGood
}

# ================================================================================================
# GESTIÓN DE VARIABLES DE ENTORNO
# ================================================================================================

function Get-EnvironmentVariables {
    Write-StatusMessage "Configurando variables de entorno..." "Header"
    
    # Intentar cargar desde archivo .env local
    $envFile = ".env"
    if (Test-Path $envFile) {
        Write-StatusMessage "Encontrado archivo .env local" "Info"
        $envContent = Get-Content $envFile
        foreach ($line in $envContent) {
            if ($line -match '^([^#][^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                if ($key -eq "SUPABASE_URL" -and [string]::IsNullOrEmpty($script:SupabaseUrl)) {
                    $script:SupabaseUrl = $value
                }
                if ($key -eq "SUPABASE_SERVICE_ROLE_KEY" -and [string]::IsNullOrEmpty($script:SupabaseServiceKey)) {
                    $script:SupabaseServiceKey = $value
                }
            }
        }
    }
    
    # Solicitar variables faltantes
    if ([string]::IsNullOrEmpty($script:SupabaseUrl)) {
        do {
            $script:SupabaseUrl = Read-Host "Ingresa la URL de Supabase (ej: https://tu-proyecto.supabase.co)"
        } while ([string]::IsNullOrEmpty($script:SupabaseUrl))
    }
    
    if ([string]::IsNullOrEmpty($script:SupabaseServiceKey)) {
        do {
            $script:SupabaseServiceKey = Get-SecureInput "Ingresa la clave de servicio de Supabase (service_role key)"
        } while ([string]::IsNullOrEmpty($script:SupabaseServiceKey))
    }
    
    # Validar formato de URL
    if ($script:SupabaseUrl -notmatch '^https://[a-zA-Z0-9]+\.supabase\.co$') {
        Write-StatusMessage "La URL de Supabase debe tener el formato: https://proyecto.supabase.co" "Warning"
    }
    
    Write-StatusMessage "Variables de entorno configuradas correctamente" "Success"
}

# ================================================================================================
# CONFIGURACIÓN DE GOOGLE CLOUD
# ================================================================================================

function Initialize-GoogleCloud {
    Write-StatusMessage "Configurando Google Cloud..." "Header"
    
    # Configurar proyecto
    Write-StatusMessage "Configurando proyecto: $ProjectId" "Info"
    gcloud config set project $ProjectId --quiet
    
    # Habilitar APIs necesarias
    Write-StatusMessage "Habilitando APIs necesarias..." "Info"
    $apis = @(
        "artifactregistry.googleapis.com",
        "run.googleapis.com",
        "cloudbuild.googleapis.com"
    )
    
    foreach ($api in $apis) {
        Write-StatusMessage "Habilitando API: $api" "Info"
        gcloud services enable $api --quiet
    }
    
    # Configurar Artifact Registry (asumiendo que ya está configurado)
    Write-StatusMessage "Configurando Artifact Registry..." "Info"
    Write-StatusMessage "Asumiendo que el repositorio '$REPOSITORY_NAME' ya existe (evitando verificaciones problemáticas)" "Info"
    
    # Configurar Docker para Artifact Registry
    Write-StatusMessage "Configurando Docker para Artifact Registry..." "Info"
    gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet
    
    Write-StatusMessage "Google Cloud configurado correctamente" "Success"
}

# ================================================================================================
# CONSTRUCCIÓN Y DESPLIEGUE
# ================================================================================================

function Build-DockerImage {
    Write-StatusMessage "Construyendo imagen Docker..." "Header"
    
    $imageName = "$REGION-docker.pkg.dev/$ProjectId/$REPOSITORY_NAME/$SERVICE_NAME"
    $fullImageName = "${imageName}:${IMAGE_TAG}"
    
    # Construir imagen
    Write-StatusMessage "Construyendo imagen: $fullImageName" "Info"
    $buildSuccess = Invoke-CommandWithRetry "docker build -t $fullImageName ."
    
    if (-not $buildSuccess) {
        Write-StatusMessage "Error construyendo la imagen Docker" "Error"
        return $false
    }
    
    # Subir imagen
    Write-StatusMessage "Subiendo imagen a Artifact Registry..." "Info"
    $pushSuccess = Invoke-CommandWithRetry "docker push $fullImageName"
    
    if (-not $pushSuccess) {
        Write-StatusMessage "Error subiendo la imagen a Artifact Registry" "Error"
        return $false
    }
    
    Write-StatusMessage "Imagen construida y subida exitosamente" "Success"
    return $fullImageName
}

function Deploy-CloudRunService {
    param([string]$ImageName)
    
    Write-StatusMessage "Desplegando en Cloud Run..." "Header"
    
    # Construir variables de entorno
    $envVars = "SUPABASE_URL=$script:SupabaseUrl,SUPABASE_SERVICE_ROLE_KEY=$script:SupabaseServiceKey,BUCKET_NAME=$BUCKET_NAME"
    
    # Comando de despliegue
    $deployCmd = @(
        "gcloud run deploy $SERVICE_NAME",
        "--image $ImageName",
        "--platform managed",
        "--region $REGION",
        "--allow-unauthenticated",
        "--port 8000",
        "--memory 1Gi",
        "--timeout 300",
        "--max-instances 10",
        "--cpu 1",
        "--set-env-vars `"$envVars`"",
        "--quiet"
    ) -join " "
    
    Write-StatusMessage "Ejecutando despliegue..." "Info"
    $deploySuccess = Invoke-CommandWithRetry $deployCmd
    
    if (-not $deploySuccess) {
        Write-StatusMessage "Error en el despliegue" "Error"
        return $false
    }
    
    Write-StatusMessage "Servicio desplegado exitosamente" "Success"
    return $true
}

# ================================================================================================
# VERIFICACIÓN POST-DESPLIEGUE
# ================================================================================================

function Test-DeployedService {
    Write-StatusMessage "Verificando servicio desplegado..." "Header"
    
    try {
        # Obtener URL del servicio
        $serviceUrl = gcloud run services describe $SERVICE_NAME --region=$REGION --format="value(status.url)" 2>$null
        
        if ([string]::IsNullOrEmpty($serviceUrl)) {
            Write-StatusMessage "No se pudo obtener la URL del servicio" "Error"
            return $false
        }
        
        Write-StatusMessage "URL del servicio: $serviceUrl" "Info"
        
        # Esperar un poco para que el servicio esté listo
        Write-StatusMessage "Esperando que el servicio esté listo..." "Info"
        Start-Sleep 10
        
        # Probar health check
        Write-StatusMessage "Probando endpoint de salud..." "Info"
        try {
            $response = Invoke-RestMethod -Uri "$serviceUrl/health" -Method GET -TimeoutSec 30
            
            Write-StatusMessage "Health Check Results:" "Accent"
            Write-Host "  Status: $($response.status)" -ForegroundColor Green
            Write-Host "  Supabase conectado: $($response.supabase_connected)" -ForegroundColor $(if($response.supabase_connected) {"Green"} else {"Red"})
            Write-Host "  YOLO cargado: $($response.yolo_loaded)" -ForegroundColor $(if($response.yolo_loaded) {"Green"} else {"Red"})
            Write-Host "  Bucket configurado: $($response.environment.bucket_name)" -ForegroundColor Cyan
            
            if ($response.supabase_connected -and $response.yolo_loaded) {
                Write-StatusMessage "Todos los componentes están funcionando correctamente" "Success"
            } else {
                Write-StatusMessage "Algunos componentes no están funcionando correctamente" "Warning"
            }
            
        }
        catch {
            Write-StatusMessage "Error probando el health check: $($_.Exception.Message)" "Warning"
            Write-StatusMessage "El servicio puede estar aún inicializándose" "Info"
        }
        
        # Mostrar información útil
        Write-StatusMessage "URLs importantes:" "Accent"
        Write-Host "  Servicio: $serviceUrl" -ForegroundColor Cyan
        Write-Host "  Documentación: $serviceUrl/docs" -ForegroundColor Cyan
        Write-Host "  Health Check: $serviceUrl/health" -ForegroundColor Cyan
        Write-Host "  Debug: $serviceUrl/debug/process-image" -ForegroundColor Cyan
        
        Write-StatusMessage "Configuración para el frontend:" "Accent"
        Write-Host "  VITE_STEREO_SERVICE_URL=$serviceUrl" -ForegroundColor Yellow
        
        return $true
        
    }
    catch {
        Write-StatusMessage "Error verificando el servicio: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Show-UsefulCommands {
    Write-StatusMessage "Comandos útiles:" "Accent"
    Write-Host ""
    Write-Host "Gestión del servicio:" -ForegroundColor Magenta
    Write-Host "  Ver logs:       gcloud logging read `"resource.type=cloud_run_revision AND resource.labels.service_name=$SERVICE_NAME`" --limit=50" -ForegroundColor Gray
    Write-Host "  Redesplegar:    .\deploy.ps1 -Force" -ForegroundColor Gray
    Write-Host "  Eliminar:       gcloud run services delete $SERVICE_NAME --region=$REGION" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Docker:" -ForegroundColor Magenta  
    Write-Host "  Ver imágenes:   docker images | grep $SERVICE_NAME" -ForegroundColor Gray
    Write-Host "  Limpiar:        docker system prune -f" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Desarrollo:" -ForegroundColor Magenta
    Write-Host "  Prueba local:   python test_local.py" -ForegroundColor Gray
    Write-Host "  Logs en vivo:   gcloud logging tail `"resource.type=cloud_run_revision AND resource.labels.service_name=$SERVICE_NAME`"" -ForegroundColor Gray
}

# ================================================================================================
# FUNCIÓN PRINCIPAL
# ================================================================================================

function Main {
    try {
        # Banner
        Write-Host ""
        Write-Host "=================================================================" -ForegroundColor Magenta
        Write-Host "          STEREO SERVICE - DESPLIEGUE EN CLOUD RUN" -ForegroundColor Magenta  
        Write-Host "=================================================================" -ForegroundColor Magenta
        Write-Host ""
        
        # Mostrar configuración
        Write-StatusMessage "Configuración del despliegue:" "Info"
        Write-Host "  Proyecto: $ProjectId" -ForegroundColor Cyan
        Write-Host "  Región: $REGION" -ForegroundColor Cyan
        Write-Host "  Servicio: $SERVICE_NAME" -ForegroundColor Cyan
        Write-Host "  Repositorio: $REPOSITORY_NAME" -ForegroundColor Cyan
        Write-Host ""
        
        # Confirmar si no es forzado
        if (-not $Force) {
            $confirm = Read-Host "¿Continuar con el despliegue? (y/N)"
            if ($confirm -notmatch '^[yY]') {
                Write-StatusMessage "Despliegue cancelado por el usuario" "Warning"
                return
            }
        }
        
        # Ejecutar pasos
        if (-not (Test-Prerequisites)) {
            Write-StatusMessage "Los prerrequisitos no se cumplen. Corrige los errores y vuelve a intentar." "Error"
            return
        }
        
        Get-EnvironmentVariables
        Initialize-GoogleCloud
        
        $imageName = Build-DockerImage
        if (-not $imageName) {
            Write-StatusMessage "Error en la construcción de la imagen" "Error"
            return
        }
        
        if (-not (Deploy-CloudRunService $imageName)) {
            Write-StatusMessage "Error en el despliegue" "Error"
            return
        }
        
        Test-DeployedService
        Show-UsefulCommands
        
        Write-Host ""
        Write-Host "=================================================================" -ForegroundColor Green
        Write-Host "               ¡DESPLIEGUE COMPLETADO EXITOSAMENTE!" -ForegroundColor Green
        Write-Host "=================================================================" -ForegroundColor Green
        Write-Host ""
        
    }
    catch {
        Write-StatusMessage "Error inesperado: $($_.Exception.Message)" "Error"
        Write-StatusMessage "Stack trace: $($_.ScriptStackTrace)" "Error"
    }
}

# ================================================================================================
# EJECUTAR SCRIPT
# ================================================================================================

Main 