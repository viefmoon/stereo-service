# Guía de Despliegue: Stereo Service en Google Cloud Run

Esta guía te mostrará paso a paso cómo desplegar el servicio de medición de frutos a través de fotos estereoscópicas en Google Cloud Run.

## Prerrequisitos

- Cuenta de Google Cloud Platform
- Google Cloud CLI instalado en tu equipo local
- Docker instalado en tu equipo local
- Git (para clonar el repositorio)
- Una cuenta de Supabase con un bucket configurado para almacenar imágenes

## 1. Configuración Inicial

### Instalar Google Cloud SDK

1. Descarga e instala Google Cloud SDK desde [cloud.google.com/sdk](https://cloud.google.com/sdk)
2. Inicia sesión en tu cuenta de Google Cloud:

```bash
gcloud auth login
```

3. Configura el proyecto de Google Cloud:

```bash
gcloud config set project [ID-DE-TU-PROYECTO]

gcloud config set project gen-lang-client-0720673337

```

## 2. Configuración de Variables de Entorno

Crea un archivo `.env` en la raíz del proyecto con las siguientes variables:

```
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_SERVICE_ROLE_KEY=tu-service-role-key
BUCKET_NAME=crop-images
```

Este archivo `.env` es útil para el desarrollo local, pero para el despliegue en Cloud Run, las variables se configurarán directamente en el comando de despliegue o mediante Secret Manager (aunque esta última opción la eliminaremos de esta guía simplificada).

## 3. Despliegue en Google Cloud

### 3.1 Habilitar las APIs necesarias

```bash
gcloud services enable artifactregistry.googleapis.com
gcloud services enable run.googleapis.com
```

### 3.2 Crear un repositorio en Artifact Registry

```bash
gcloud artifacts repositories create stereo-repo --repository-format=docker --location=us-central1 --description="Repositorio para el servicio de estéreo"
```

### 3.3 Configurar Docker para usar Artifact Registry

```bash
gcloud auth configure-docker us-central1-docker.pkg.dev
```

### 3.4 Etiquetar y subir la imagen al repositorio

```bash
docker tag stereo-service us-central1-docker.pkg.dev/[ID-DE-TU-PROYECTO]/stereo-repo/stereo-service:latest
docker push us-central1-docker.pkg.dev/[ID-DE-TU-PROYECTO]/stereo-repo/stereo-service:latest


docker tag stereo-service us-central1-docker.pkg.dev/gen-lang-client-0720673337/stereo-repo/stereo-service:latest
docker push us-central1-docker.pkg.dev/gen-lang-client-0720673337/stereo-repo/stereo-service:latest

```

### 3.5 Desplegar el servicio en Cloud Run

Intenta desplegar el servicio especificando el puerto que tu aplicación utiliza internamente (por defecto 8000 según tu Dockerfile). Cloud Run inyectará una variable `PORT` que tu aplicación debe respetar. El `Dockerfile` ya está configurado para usar `${PORT:-8000}`.

**Importante sobre las variables de entorno:**
Las variables pasadas con `--set-env-vars` deben estar en formato `NOMBRE1=VALOR1,NOMBRE2=VALOR2,NOMBRE3=VALOR3` todo dentro de una sola cadena de texto entre comillas. Asegúrate de que no haya espacios extra alrededor de los `=` o las comas, y que cada variable esté separada por una coma.

Reemplaza `[TU_SUPABASE_SERVICE_ROLE_KEY_AQUI]` con tu clave de servicio real de Supabase y `[ID-DE-TU-PROYECTO]` con el ID de tu proyecto de Google Cloud.

```bash
gcloud run deploy stereo-service --image us-central1-docker.pkg.dev/[ID-DE-TU-PROYECTO]/stereo-repo/stereo-service:latest --platform managed --region us-central1 --allow-unauthenticated --set-env-vars "SUPABASE_URL=https://tu-proyecto.supabase.co,SUPABASE_SERVICE_ROLE_KEY=[TU_SUPABASE_SERVICE_ROLE_KEY_AQUI],BUCKET_NAME=crop-images" --port 8000 --memory 1Gi --project=[ID-DE-TU-PROYECTO]
```

> **Nota**: Cloud Run establece una variable de entorno `PORT` en la que espera que tu aplicación escuche. Por defecto, esta variable es `8080`. Tu `Dockerfile` está configurado para usar `uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}`, lo que significa que usará el valor de `PORT` si está disponible, o `8000` en caso contrario. Al añadir `--port 8000` al comando `gcloud run deploy`, le estamos indicando a Cloud Run que el contenedor escuchará en el puerto `8000` y Cloud Run gestionará el tráfico externo hacia este puerto. El parámetro `--memory 1Gi` aumenta la memoria disponible para tu servicio a 1 Gibibyte, lo que puede ayudar a resolver errores de memoria insuficiente.

## 4. Verificación del Despliegue

1. Una vez desplegado, Cloud Run te proporcionará una URL para acceder al servicio.
2. Verifica que la API esté funcionando visitando la URL + `/docs` (interfaz Swagger de FastAPI).
3. Prueba los nuevos endpoints:
   - `/health` para verificar que el servicio está funcionando
   - `/process/{path}` para procesar imágenes estereoscópicas completas
   - `/process/normal/{path}` para procesar imágenes normales  
   - `/generate-disparity/{path}` para generar solo mapas de disparidad

## 5. Monitoreo y Mantenimiento

- Puedes ver los logs del servicio con:

```bash
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=stereo-service" --limit=10
```

- Para actualizar el servicio después de cambios, simplemente reconstruye la imagen, súbela al repositorio y despliega nuevamente.

## 6. Troubleshooting

- **Error al descargar imágenes**: Verifica que el bucket de Supabase esté configurado correctamente y que las imágenes sean accesibles públicamente.
- **Errores de memoria**: Si encuentras errores de memoria, ajusta la configuración de recursos en Cloud Run (CPU y memoria).
- **Tiempo de espera agotado**: Verifica que el procesamiento de imágenes no supere el límite de tiempo de Cloud Run (por defecto 5 minutos).

## 7. Recursos Adicionales

- [Documentación de Cloud Run](https://cloud.google.com/run/docs)
- [Documentación de FastAPI](https://fastapi.tiangolo.com/)
- [Documentación de Supabase](https://supabase.io/docs)
- [Documentación de Docker](https://docs.docker.com/) 