# Stereo Service: Análisis de Frutos con Visión Estereoscópica

## 🍎 Descripción

Servicio de procesamiento de imágenes estereoscópicas para medición automatizada de frutos. Utiliza algoritmos de visión por computadora (YOLO + StereoSGBM) para detectar y medir frutos en 3D, calculando volúmenes con precisión milimétrica.

## ✨ Características

- **Procesamiento estereoscópico**: Análisis 3D de imágenes 3480×1080 pixels
- **Detección de frutos**: YOLOv8n entrenado para manzanas, naranjas y frutas genéricas  
- **Medición volumétrica**: Cálculo preciso de diámetros y volúmenes en mm³
- **Mapas de disparidad**: Generación de visualizaciones de profundidad
- **API REST**: Endpoints documentados con FastAPI
- **Integración Supabase**: Almacenamiento en la nube y gestión de imágenes

## 🚀 Despliegue Rápido

### Usando PowerShell (Recomendado)

```powershell
cd stereo-service
.\deploy.ps1
```

El script te guía paso a paso:
- ✅ Verifica prerrequisitos (Docker, gcloud, autenticación)
- 🔐 Solicita credenciales de Supabase de forma segura  
- 🏗️ Construye y despliega automáticamente
- 🧪 Verifica el funcionamiento post-despliegue
- 📋 Proporciona comandos útiles de gestión

### Opciones de Despliegue

```powershell
# Despliegue interactivo (recomendado)
.\deploy.ps1

# Con parámetros específicos
.\deploy.ps1 -ProjectId "mi-proyecto" -SupabaseUrl "https://mi-proyecto.supabase.co"

# Redespliegue rápido sin confirmaciones
.\deploy.ps1 -Force
```

## 📋 Prerrequisitos

- **Google Cloud Platform**: Proyecto configurado
- **Google Cloud CLI**: Instalado y autenticado
- **Docker Desktop**: Funcionando
- **PowerShell**: 5.1+ (Windows) o PowerShell Core
- **Supabase**: Proyecto con bucket 'crop-images'

## 🔧 Configuración

### Variables de Entorno

Crea un archivo `.env` (opcional):

```env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_SERVICE_ROLE_KEY=tu-service-role-key
BUCKET_NAME=crop-images
```

Si no lo creas, el script te pedirá las variables durante la ejecución.

## 🌐 API Endpoints

Una vez desplegado, el servicio proporciona:

### Endpoints Principales

- `GET /health` - Estado del servicio
- `GET /docs` - Documentación interactiva (Swagger)
- `GET /process/{path}` - Procesar imagen estereoscópica
- `POST /process/normal/{path}` - Procesar imagen normal
- `POST /generate-disparity/{path}` - Generar solo mapa de disparidad

### Ejemplo de Respuesta

```json
{
  "n_fruits": 3,
  "fruits": [
    {
      "className": "apple",
      "distance_mm": 1250.5,
      "diameter_mm": 85.2,
      "volume_mm3": 323847.1,
      "bbox": [120, 200, 180, 280]
    }
  ],
  "disparity_map_path": "station1/crop1/image_disparity.png",
  "algorithm_version": "YOLOv8n + StereoSGBM"
}
```

## 🧪 Desarrollo Local

### Instalación

```bash
# Crear entorno virtual
python -m venv .venv
source .venv/bin/activate  # Linux/Mac
# o
.venv\Scripts\activate     # Windows

# Instalar dependencias
pip install -r requirements.txt
```

### Ejecución Local

```bash
# Servidor de desarrollo
uvicorn app.main:app --reload --port 8000

# Probar funcionamiento
python test_local.py
```

### Testing

```bash
# Health check
curl http://localhost:8000/health

# Documentación
# Visita: http://localhost:8000/docs
```

## 📊 Monitoreo

### Comandos Útiles (post-despliegue)

```powershell
# Ver logs en tiempo real
gcloud logging tail "resource.type=cloud_run_revision AND resource.labels.service_name=stereo-service"

# Logs recientes
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=stereo-service" --limit=50

# Redesplegar
.\deploy.ps1 -Force

# Información del servicio
gcloud run services describe stereo-service --region=us-central1
```

### Health Check

El endpoint `/health` proporciona:

```json
{
  "status": "healthy",
  "service": "stereo-fruit-api", 
  "supabase_connected": true,
  "yolo_loaded": true,
  "environment": {
    "supabase_url_configured": true,
    "supabase_key_configured": true,
    "bucket_name": "crop-images"
  }
}
```

## 🔒 Seguridad

- **Variables sensibles**: Manejo seguro sin hardcodeo
- **CORS**: Configurado para desarrollo (personalizar para producción)
- **Autenticación**: Sin autenticación por defecto (configurable)
- **Storage**: URLs firmadas de Supabase con expiración

## 📈 Optimización

### Configuración de Rendimiento

- **Memoria**: 1Gi (suficiente para YOLO + OpenCV)
- **CPU**: 1 vCPU con auto-scaling
- **Timeout**: 300s para procesamiento pesado
- **Instancias**: Max 10 instancias concurrentes
- **Cold Start**: Optimizado con keep-alive

### Escalabilidad

```bash
# Aumentar recursos
gcloud run services update stereo-service \
  --region=us-central1 \
  --memory=2Gi \
  --cpu=2 \
  --max-instances=20
```

## 🐛 Solución de Problemas

### Problemas Comunes

1. **"Docker no está corriendo"**
   - Inicia Docker Desktop y espera que cargue completamente

2. **"No autenticado en Google Cloud"**
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

3. **"Supabase conectado: false"**
   - Verifica URL y clave de servicio de Supabase
   - Asegúrate que el bucket 'crop-images' existe

4. **"YOLO cargado: false"**
   - Problema con dependencias de Python/OpenCV
   - Intenta redesplegando: `.\deploy.ps1 -Force`

5. **Timeout en procesamiento**
   - Las imágenes grandes pueden tardar hasta 5 minutos
   - Verifica que la imagen sea exactamente 3480×1080 para estéreo

## 🏗️ Arquitectura

```
Frontend (React/TypeScript)
    ↓ HTTP/REST
Cloud Run (Python/FastAPI)
    ↓ Storage API
Supabase (PostgreSQL + Storage)
    ↓ File Access  
Google Cloud Storage (Imágenes)
```

### Flujo de Procesamiento

1. **Upload**: Frontend sube imagen a Supabase Storage
2. **Trigger**: Frontend llama API con path de imagen  
3. **Download**: Servicio descarga imagen desde Supabase
4. **Process**: Análisis con YOLO + StereoSGBM
5. **Results**: Retorna métricas + guarda mapa de disparidad
6. **Display**: Frontend muestra resultados y visualizaciones

## 📚 Referencias

- [Documentación de Cloud Run](https://cloud.google.com/run/docs)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [YOLO by Ultralytics](https://docs.ultralytics.com/)
- [OpenCV StereoSGBM](https://docs.opencv.org/4.x/d2/d85/classcv_1_1StereoSGBM.html)
- [Supabase Storage](https://supabase.io/docs/guides/storage)

## 🤝 Contribución

1. Fork el repositorio
2. Crea una rama para tu feature
3. Desarrolla y testea localmente
4. Despliega con `.\deploy.ps1`
5. Haz commit y pull request

## 📄 Licencia

Este proyecto es de código abierto bajo licencia MIT.

---

**¿Necesitas ayuda?** Ejecuta `.\deploy.ps1` y el script te guiará paso a paso. Para problemas específicos, revisa los logs con los comandos proporcionados por el script.
