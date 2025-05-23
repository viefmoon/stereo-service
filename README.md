# Stereo Fruit Size API

API FastAPI para medir frutos en fotos estereoscópicas 3480×1080 usando YOLOv8n y algoritmos de visión estereoscópica.

## 🚀 Características

- **Procesamiento de imágenes estereoscópicas**: Análisis de imágenes 3480×1080 para generar mapas de disparidad
- **Detección de frutas**: Utiliza YOLOv8n para detectar manzanas, naranjas y frutas genéricas
- **Mediciones 3D**: Calcula distancia, diámetro y volumen de frutas usando datos de profundidad
- **Procesamiento de imágenes normales**: Soporte para imágenes 2D con estimaciones básicas
- **Integración con Supabase**: Almacenamiento y gestión de imágenes en la nube
- **Mapas de disparidad**: Generación y almacenamiento de mapas de disparidad coloreados

## 📋 Endpoints

### Health Check
```
GET /health
```
Verifica el estado del servicio y las conexiones.

**Respuesta:**
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

### Procesamiento Estereoscópico Completo
```
GET /process/{path:path}
```
Procesa una imagen estereoscópica y retorna análisis completo de frutas.

**Parámetros:**
- `path`: Ruta de la imagen en Supabase Storage (formato: `folder/image.jpg`)

**Respuesta:**
```json
{
  "n_fruits": 2,
  "fruits": [
    {
      "className": "apple",
      "distance_mm": 850.5,
      "diameter_mm": 75.2,
      "volume_mm3": 223847.1,
      "bbox": [100, 150, 200, 250]
    }
  ],
  "disparity_map_path": "folder/image_disparity.png",
  "processed_at": "now()",
  "algorithm_version": "YOLOv8n + StereoSGBM"
}
```

### Procesamiento de Imagen Normal
```
POST /process/normal/{path:path}
```
Procesa una imagen normal (no estereoscópica) para detectar frutas.

**Respuesta:**
```json
{
  "n_fruits": 1,
  "fruits": [
    {
      "className": "orange",
      "diameter_px": 120,
      "estimated_volume_mm3": 7200.0,
      "bbox": [50, 75, 170, 195]
    }
  ],
  "processed_at": "now()",
  "algorithm_version": "YOLOv8n",
  "note": "Mediciones estimadas (imagen 2D sin datos de profundidad)"
}
```

### Generación de Mapa de Disparidad
```
POST /generate-disparity/{path:path}
```
Genera solo el mapa de disparidad de una imagen estereoscópica.

**Respuesta:**
```json
{
  "disparity_map_path": "folder/image_disparity.png",
  "processed_at": "now()",
  "algorithm_version": "StereoSGBM"
}
```

## 🛠️ Configuración Local

### Prerrequisitos
- Python 3.11+
- pip o conda

### Instalación
```bash
# Clonar el repositorio
git clone <repository-url>
cd stereo-service

# Crear entorno virtual
python -m venv .venv
source .venv/bin/activate  # En Windows: .venv\Scripts\activate

# Instalar dependencias
pip install -r requirements.txt
```

### Variables de Entorno
Crear un archivo `.env`:
```env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_SERVICE_ROLE_KEY=tu-service-role-key
BUCKET_NAME=crop-images
```

### Ejecutar Localmente
```bash
# Activar entorno virtual
source .venv/bin/activate  # En Windows: .venv\Scripts\activate

# Ejecutar servidor
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

El servicio estará disponible en `http://localhost:8000`

### Probar Localmente
```bash
python test_local.py
```

## ☁️ Despliegue en Google Cloud Run

### Prerrequisitos
- Google Cloud CLI instalado y autenticado
- Proyecto de Google Cloud configurado
- Artifact Registry habilitado

### Configuración Inicial
```bash
# Autenticar con Google Cloud
gcloud auth login

# Configurar proyecto
gcloud config set project TU-PROJECT-ID

# Crear repositorio en Artifact Registry (solo la primera vez)
gcloud artifacts repositories create stereo-repo \
    --repository-format=docker \
    --location=us-central1
```

### Despliegue Básico (sin Supabase)
```bash
# Ejecutar script de despliegue
./deploy.sh
```

### Despliegue con Supabase (Recomendado)
```powershell
# En PowerShell (Windows)
.\deploy-with-supabase.ps1 -SupabaseUrl "https://tu-proyecto.supabase.co" -SupabaseServiceKey "tu-service-role-key"
```

```bash
# En Bash (Linux/Mac)
gcloud run deploy stereo-service \
    --image us-central1-docker.pkg.dev/TU-PROJECT-ID/stereo-repo/stereo-service:latest \
    --platform managed \
    --region us-central1 \
    --allow-unauthenticated \
    --port 8000 \
    --memory 1Gi \
    --timeout 300 \
    --set-env-vars "SUPABASE_URL=https://tu-proyecto.supabase.co,SUPABASE_SERVICE_ROLE_KEY=tu-service-role-key,BUCKET_NAME=crop-images"
```

### Verificar Despliegue
```bash
# Probar endpoint de health
curl https://stereo-service-PROJECT-ID.us-central1.run.app/health
```

## 🔧 Configuración de Supabase

### 1. Crear Bucket de Storage
En el dashboard de Supabase:
1. Ve a Storage
2. Crea un bucket llamado `crop-images`
3. Configura las políticas de acceso según tus necesidades

### 2. Obtener Credenciales
1. Ve a Settings > API
2. Copia la `URL` del proyecto
3. Copia la `service_role` key (no la anon key)

### 3. Configurar Políticas de Storage
```sql
-- Permitir lectura pública de imágenes
CREATE POLICY "Public read access" ON storage.objects
FOR SELECT USING (bucket_id = 'crop-images');

-- Permitir escritura autenticada
CREATE POLICY "Authenticated upload access" ON storage.objects
FOR INSERT WITH CHECK (bucket_id = 'crop-images' AND auth.role() = 'authenticated');
```

## 🧪 Testing

### Test Local
```bash
python test_local.py
```

### Test en Producción
```bash
# Probar health check
curl https://stereo-service-PROJECT-ID.us-central1.run.app/health

# Probar procesamiento (requiere imagen en Supabase)
curl https://stereo-service-PROJECT-ID.us-central1.run.app/process/test/sample.jpg
```

## 📊 Parámetros de Calibración

### Cámara Estereoscópica
- **FOCAL_PX**: 783.0 (distancia focal en píxeles)
- **BASELINE_MM**: 55.0 (separación entre cámaras en mm)

### Algoritmo StereoSGBM
- **minDisparity**: 0
- **numDisparities**: 192 (16*12)
- **blockSize**: 5
- **uniquenessRatio**: 5
- **speckleWindowSize**: 50
- **speckleRange**: 1

## 🐛 Troubleshooting

### Error: "supabase_url is required"
- Verifica que las variables de entorno estén configuradas correctamente
- Asegúrate de usar la URL completa de Supabase (https://...)

### Error: "Modelo YOLO no disponible"
- El modelo se descarga automáticamente en el primer uso
- Verifica la conexión a internet del contenedor

### Error: "Imagen debe ser 3480×1080 RGB"
- Verifica que la imagen tenga exactamente estas dimensiones
- Asegúrate de que sea una imagen estereoscópica (lado izquierdo y derecho)

### Error de memoria en Cloud Run
- Aumenta la memoria asignada a 2Gi o más
- Considera usar CPU con más cores

## 📝 Logs

### Ver logs en Cloud Run
```bash
gcloud run services logs read stereo-service --region=us-central1 --limit=50
```

### Logs locales
Los logs se muestran en la consola cuando ejecutas el servidor localmente.

## 🔄 Actualizaciones

### Actualizar el servicio
1. Modifica el código
2. Ejecuta el script de despliegue
3. Verifica que el servicio funcione correctamente

### Rollback
```bash
# Listar revisiones
gcloud run revisions list --service=stereo-service --region=us-central1

# Hacer rollback a una revisión anterior
gcloud run services update-traffic stereo-service \
    --to-revisions=REVISION-NAME=100 \
    --region=us-central1
```

## 📄 Licencia

Este proyecto está bajo la licencia MIT. Ver el archivo LICENSE para más detalles.

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:
1. Fork el proyecto
2. Crea una rama para tu feature
3. Commit tus cambios
4. Push a la rama
5. Abre un Pull Request

## 📞 Soporte

Para soporte técnico o preguntas:
- Abre un issue en GitHub
- Contacta al equipo de desarrollo

---

**Nota**: Este servicio está optimizado para imágenes estereoscópicas de 3480×1080 píxeles. Para otros formatos, será necesario ajustar los parámetros de calibración.
