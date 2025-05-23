@echo off
echo === Desplegando Stereo Service ===
echo.

REM Variables de configuracion
set PROJECT_ID=gen-lang-client-0720673337
set REGION=us-central1
set SERVICE_NAME=stereo-service
set REPOSITORY_NAME=stereo-repo

echo Proyecto: %PROJECT_ID%
echo Region: %REGION%
echo Servicio: %SERVICE_NAME%
echo.

echo === Paso 1: Construyendo imagen con Cloud Build ===
gcloud builds submit --tag %REGION%-docker.pkg.dev/%PROJECT_ID%/%REPOSITORY_NAME%/%SERVICE_NAME%:latest

if errorlevel 1 (
    echo ERROR: Fallo en la construccion de la imagen
    pause
    exit /b 1
)

echo.
echo === Paso 2: Desplegando en Cloud Run ===
gcloud run deploy %SERVICE_NAME% ^
    --image %REGION%-docker.pkg.dev/%PROJECT_ID%/%REPOSITORY_NAME%/%SERVICE_NAME%:latest ^
    --platform managed ^
    --region %REGION% ^
    --allow-unauthenticated ^
    --port 8000 ^
    --memory 1Gi ^
    --project=%PROJECT_ID%

if errorlevel 1 (
    echo ERROR: Fallo en el despliegue
    pause
    exit /b 1
)

echo.
echo === Obteniendo URL del servicio ===
for /f "tokens=*" %%a in ('gcloud run services describe %SERVICE_NAME% --region=%REGION% --format="value(status.url)"') do set SERVICE_URL=%%a

echo.
echo =====================================
echo DESPLIEGUE COMPLETADO EXITOSAMENTE
echo =====================================
echo.
echo URL del servicio: %SERVICE_URL%
echo Documentacion: %SERVICE_URL%/docs
echo Health check: %SERVICE_URL%/health
echo.
echo Configuracion para el frontend:
echo VITE_STEREO_SERVICE_URL=%SERVICE_URL%
echo.
pause 