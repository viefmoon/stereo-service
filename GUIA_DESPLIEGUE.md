# Guía de Despliegue: Stereo Service en Google Cloud Run

Esta guía te mostrará cómo desplegar el servicio de medición de frutos a través de fotos estereoscópicas en Google Cloud Run usando el script automatizado de PowerShell.

## 🚀 Despliegue Rápido (Recomendado)

Si tienes PowerShell, simplemente ejecuta:

```powershell
cd stereo-service
.\deploy.ps1
```

El script te guiará paso a paso y configurará todo automáticamente.

## 📋 Prerrequisitos

- **Google Cloud Platform**: Cuenta activa con proyecto configurado
- **Google Cloud CLI**: Instalado y autenticado (`gcloud auth login`)
- **Docker Desktop**: Instalado y ejecutándose
- **PowerShell**: 5.1 o superior (Windows) o PowerShell Core (multiplataforma)
- **Supabase**: Proyecto configurado con un bucket para imágenes

## 🛠️ Configuración Inicial

### 1. Autenticación en Google Cloud

```powershell
# Autenticarse en Google Cloud
gcloud auth login

# Configurar proyecto (opcional - el script puede hacerlo)
gcloud config set project tu-proyecto-id
```

### 2. Variables de Entorno (Opcional)

Puedes crear un archivo `.env` en la carpeta `stereo-service` con tus credenciales:

```env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_SERVICE_ROLE_KEY=tu-service-role-key
BUCKET_NAME=crop-images
```

> **Nota**: Si no creas el archivo `.env`, el script te pedirá estas variables de forma segura durante la ejecución.

## 🎯 Opciones de Despliegue

### Despliegue Interactivo (Recomendado)
```powershell
.\deploy.ps1
```
- Te guía paso a paso
- Verifica prerrequisitos
- Solicita credenciales de forma segura
- Incluye confirmaciones

### Despliegue con Parámetros
```powershell
.\deploy.ps1 -ProjectId "mi-proyecto" -SupabaseUrl "https://mi-proyecto.supabase.co" -SupabaseServiceKey "mi-clave"
```

### Redespliegue Rápido (Sin Confirmaciones)
```powershell
.\deploy.ps1 -Force
```
- Salta confirmaciones
- Usa configuración existente
- Ideal para actualizaciones rápidas

## 🔍 Verificación Post-Despliegue

El script automáticamente:

1. **Verifica el Health Check**: Prueba `/health` endpoint
2. **Muestra URLs importantes**:
   - 🌐 Servicio principal
   - 📚 Documentación API (`/docs`)
   - 🏥 Health check (`/health`)
   - 🧪 Debug endpoint (`/debug/process-image`)

3. **Proporciona configuración para frontend**:
   ```env
   VITE_STEREO_SERVICE_URL=https://tu-servicio.run.app
   ```

## 🐛 Solución de Problemas

### Error: "Docker no está corriendo"
```powershell
# Inicia Docker Desktop y espera que esté completamente cargado
# Luego ejecuta de nuevo el script
```

### Error: "No autenticado en Google Cloud"
```powershell
gcloud auth login
gcloud auth application-default login
```

### Error: "Proyecto no existe"
```powershell
# Verifica que el proyecto existe y tienes acceso
gcloud projects list
# O usa tu propio proyecto
.\deploy.ps1 -ProjectId "tu-proyecto-real"
```

### Error en construcción de imagen
```powershell
# Limpia Docker y vuelve a intentar
docker system prune -f
.\deploy.ps1 -Force
```

### Health Check falla
- **Supabase conectado: false**: Verifica URL y clave de Supabase
- **YOLO cargado: false**: Problema con las dependencias de Python/OpenCV
- **Timeout**: El servicio puede estar aún inicializándose (espera 1-2 minutos)

## 📊 Comandos de Monitoreo

El script te proporciona comandos útiles al final:

```powershell
# Ver logs en tiempo real
gcloud logging tail "resource.type=cloud_run_revision AND resource.labels.service_name=stereo-service"

# Ver logs recientes
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=stereo-service" --limit=50

# Redesplegar rápidamente
.\deploy.ps1 -Force

# Eliminar servicio
gcloud run services delete stereo-service --region=us-central1
```

## 🔧 Gestión del Servicio

### Actualizar después de cambios en código:
```powershell
.\deploy.ps1 -Force
```

### Cambiar variables de entorno:
```powershell
# Edita el archivo .env o ejecuta:
.\deploy.ps1
# Y proporciona nuevas credenciales cuando se soliciten
```

### Escalar el servicio:
```powershell
gcloud run services update stereo-service \
  --region=us-central1 \
  --memory=2Gi \
  --max-instances=20
```

## 📈 Optimizaciones de Rendimiento

El script configura automáticamente:

- **Memoria**: 1Gi (suficiente para YOLO + procesamiento de imágenes)
- **CPU**: 1 vCPU 
- **Timeout**: 300 segundos (5 minutos para procesamiento pesado)
- **Max Instancias**: 10 (ajustable según demanda)
- **Cold Start**: Optimizado con keep-alive

## 🔒 Seguridad

- **Variables de entorno**: Se solicitan de forma segura (no se almacenan en el script)
- **Acceso sin autenticación**: Configurado para APIs públicas (ajustar según necesidades)
- **CORS**: Configurado para desarrollo (especificar dominios en producción)

## 📚 Recursos Adicionales

- [Documentación de Cloud Run](https://cloud.google.com/run/docs)
- [Documentación de FastAPI](https://fastapi.tiangolo.com/)
- [Documentación de Supabase](https://supabase.io/docs)
- [Documentación de Docker](https://docs.docker.com/)

## 🆘 Soporte

Si encuentras problemas:

1. **Ejecuta el test local**: `python test_local.py`
2. **Revisa los logs**: Usa los comandos proporcionados por el script
3. **Verifica prerrequisitos**: El script incluye verificaciones automáticas
4. **Intenta redespliegue**: `.\deploy.ps1 -Force`

## 🏗️ Desarrollo Local

Para desarrollo y pruebas locales:

```powershell
# Crear entorno virtual
python -m venv .venv
.venv\Scripts\Activate.ps1

# Instalar dependencias
pip install -r requirements.txt

# Ejecutar localmente
uvicorn app.main:app --reload --port 8000

# Probar servicio local
python test_local.py
``` 