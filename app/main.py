"""
API FastAPI: mide frutos en fotos estereoscópicas 3480×1080.
Copiado del ejemplo previo con comentarios en castellano.
"""
from fastapi import FastAPI, HTTPException, File, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from ultralytics import YOLO
import cv2, numpy as np, aiohttp, os, math
from typing import Optional, List
import base64
import io
from PIL import Image
import json
import logging

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

FOCAL_PX   = 783.0          # ajustar
BASELINE_MM = 55.0          # medir

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
BUCKET       = os.getenv("BUCKET_NAME", "crop-images")

app = FastAPI(title="Stereo Fruit Size API")

# Configurar CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # En producción, especifica dominios específicos
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Inicialización condicional de Supabase
sb = None
if SUPABASE_URL and SUPABASE_KEY:
    try:
        from supabase import create_client
        sb = create_client(SUPABASE_URL, SUPABASE_KEY)
        logger.info("Supabase cliente inicializado correctamente")
    except Exception as e:
        logger.error(f"Error inicializando Supabase: {e}")
        sb = None
else:
    logger.warning("Variables de Supabase no configuradas - funcionando en modo local")

# Inicializar modelo YOLO
try:
    model = YOLO("yolov8n.pt")
    logger.info("Modelo YOLO inicializado correctamente")
except Exception as e:
    logger.error(f"Error inicializando YOLO: {e}")
    model = None

def disparity(left, right):
    matcher = cv2.StereoSGBM_create(
        minDisparity=0, numDisparities=16*12, blockSize=5,
        uniquenessRatio=5, speckleWindowSize=50, speckleRange=1,
        disp12MaxDiff=1, P1=8*3*5**2, P2=32*3*5**2)
    return matcher.compute(left, right).astype(np.float32) / 16.0

def depth_from_disp(disp):
    depth = (FOCAL_PX * BASELINE_MM) / disp
    depth[disp <= 0] = np.nan
    return depth

async def http_get(url):
    async with aiohttp.ClientSession() as s:
        async with s.get(url) as r:
            if r.status != 200:
                raise HTTPException(r.status, "Error bajando imagen")
            return await r.read()

def save_disparity_map(disp_map, original_path: str) -> str:
    """Guarda el mapa de disparidad normalizado como imagen PNG"""
    if not sb:
        logger.warning("Supabase no disponible - no se puede guardar mapa de disparidad")
        return f"{original_path}_disparity.png"
    
    # Normalizar disparidad para visualización (0-255)
    disp_normalized = cv2.normalize(disp_map, None, 0, 255, cv2.NORM_MINMAX)
    disp_uint8 = disp_normalized.astype(np.uint8)
    
    # Aplicar colormap para mejor visualización
    disp_colored = cv2.applyColorMap(disp_uint8, cv2.COLORMAP_JET)
    
    # Generar path para el mapa de disparidad
    path_parts = original_path.split('/')
    filename = path_parts[-1]
    filename_without_ext = filename.rsplit('.', 1)[0]
    disparity_filename = f"{filename_without_ext}_disparity.png"
    disparity_path = '/'.join(path_parts[:-1] + [disparity_filename])
    
    # Convertir a bytes
    _, buffer = cv2.imencode('.png', disp_colored)
    
    try:
        # Subir a Supabase Storage
        sb.storage.from_(BUCKET).upload(
            path=disparity_path,
            file=buffer.tobytes(),
            file_options={
                "content-type": "image/png",
                "upsert": True
            }
        )
        return disparity_path
    except Exception as e:
        logger.error(f"Error subiendo mapa de disparidad: {e}")
        return f"{original_path}_disparity_error.png"

@app.get("/process/{path:path}")
async def process_stereo_image(path: str):
    """Procesa imagen estereoscópica y retorna análisis de frutas"""
    if not sb:
        raise HTTPException(503, "Servicio Supabase no disponible")
    if not model:
        raise HTTPException(503, "Modelo YOLO no disponible")
        
    # Usar URL firmada en lugar de URL pública
    try:
        signed_url_response = sb.storage.from_(BUCKET).create_signed_url(path, 3600)
        if signed_url_response.get('error'):
            raise HTTPException(404, f"Imagen no encontrada: {signed_url_response['error']}")
        url = signed_url_response['signedURL']
    except Exception as e:
        raise HTTPException(404, f"Error accediendo a la imagen: {str(e)}")
        
    img = cv2.imdecode(np.frombuffer(await http_get(url), np.uint8),
                       cv2.IMREAD_COLOR)
    if img is None or img.shape != (1080, 3480, 3):
        raise HTTPException(422, "Imagen debe ser 3480×1080 RGB")

    left, right = np.hsplit(img, 2)
    disp   = disparity(cv2.cvtColor(left, cv2.COLOR_BGR2GRAY),
                       cv2.cvtColor(right, cv2.COLOR_BGR2GRAY))
    depth  = depth_from_disp(disp)

    # Guardar mapa de disparidad
    disparity_map_path = save_disparity_map(disp, path)

    results, out = model(left, verbose=False)[0], []
    for box in results.boxes:
        name = results.names[int(box.cls[0])]
        if name not in {"apple", "orange", "fruit"}: continue
        x1,y1,x2,y2 = map(int, box.xyxy[0])
        d = float(np.nanmedian(depth[y1:y2, x1:x2]))
        if math.isnan(d): continue
        diam_px  = max(x2-x1, y2-y1)
        diam_mm  = diam_px * d / FOCAL_PX
        vol_mm3  = 4/3*math.pi*(diam_mm/2)**3
        out.append({
            "className": name,
            "distance_mm": round(d,2),
            "diameter_mm": round(diam_mm,2),
            "volume_mm3": round(vol_mm3,1),
            "bbox": [x1, y1, x2, y2]
        })
    
    return {
        "n_fruits": len(out), 
        "fruits": out,
        "disparity_map_path": disparity_map_path,
        "processed_at": "now()",
        "algorithm_version": "YOLOv8n + StereoSGBM"
    }

@app.post("/process/normal/{path:path}")
async def process_normal_image(path: str):
    """Procesa imagen normal (no estereoscópica) para detectar frutas"""
    if not sb:
        raise HTTPException(503, "Servicio Supabase no disponible")
    if not model:
        raise HTTPException(503, "Modelo YOLO no disponible")
        
    # Usar URL firmada en lugar de URL pública
    try:
        signed_url_response = sb.storage.from_(BUCKET).create_signed_url(path, 3600)
        if signed_url_response.get('error'):
            raise HTTPException(404, f"Imagen no encontrada: {signed_url_response['error']}")
        url = signed_url_response['signedURL']
    except Exception as e:
        raise HTTPException(404, f"Error accediendo a la imagen: {str(e)}")
        
    img = cv2.imdecode(np.frombuffer(await http_get(url), np.uint8),
                       cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(422, "No se pudo decodificar la imagen")

    results, out = model(img, verbose=False)[0], []
    for box in results.boxes:
        name = results.names[int(box.cls[0])]
        if name not in {"apple", "orange", "fruit"}: continue
        x1,y1,x2,y2 = map(int, box.xyxy[0])
        
        # Para imágenes normales, estimamos tamaño basado en píxeles
        # (sin medición 3D real)
        diam_px = max(x2-x1, y2-y1)
        estimated_vol_mm3 = (diam_px ** 2) * 0.5  # Estimación básica
        
        out.append({
            "className": name,
            "diameter_px": diam_px,
            "estimated_volume_mm3": round(estimated_vol_mm3, 1),
            "bbox": [x1, y1, x2, y2]
        })
    
    return {
        "n_fruits": len(out), 
        "fruits": out,
        "processed_at": "now()",
        "algorithm_version": "YOLOv8n",
        "note": "Mediciones estimadas (imagen 2D sin datos de profundidad)"
    }

@app.post("/generate-disparity/{path:path}")
async def generate_disparity_only(path: str):
    """Genera solo el mapa de disparidad de una imagen estereoscópica"""
    if not sb:
        raise HTTPException(503, "Servicio Supabase no disponible")
        
    # Usar URL firmada en lugar de URL pública
    try:
        signed_url_response = sb.storage.from_(BUCKET).create_signed_url(path, 3600)
        if signed_url_response.get('error'):
            raise HTTPException(404, f"Imagen no encontrada: {signed_url_response['error']}")
        url = signed_url_response['signedURL']
    except Exception as e:
        raise HTTPException(404, f"Error accediendo a la imagen: {str(e)}")
        
    img = cv2.imdecode(np.frombuffer(await http_get(url), np.uint8),
                       cv2.IMREAD_COLOR)
    if img is None or img.shape != (1080, 3480, 3):
        raise HTTPException(422, "Imagen debe ser 3480×1080 RGB")

    left, right = np.hsplit(img, 2)
    disp = disparity(cv2.cvtColor(left, cv2.COLOR_BGR2GRAY),
                     cv2.cvtColor(right, cv2.COLOR_BGR2GRAY))
    
    # Guardar mapa de disparidad
    disparity_map_path = save_disparity_map(disp, path)
    
    return {
        "disparity_map_path": disparity_map_path,
        "processed_at": "now()",
        "algorithm_version": "StereoSGBM"
    }

@app.get("/health")
async def health_check():
    """Endpoint de salud para verificar que el servicio está funcionando"""
    return {
        "status": "healthy", 
        "service": "stereo-fruit-api",
        "supabase_connected": sb is not None,
        "yolo_loaded": model is not None,
        "environment": {
            "supabase_url_configured": bool(SUPABASE_URL),
            "supabase_key_configured": bool(SUPABASE_KEY),
            "bucket_name": BUCKET
        }
    }

@app.post("/debug/process-image")
async def debug_process_image():
    """Endpoint de debug para verificar que YOLO funciona sin Supabase"""
    if not model:
        raise HTTPException(503, "Modelo YOLO no disponible")
    
    # Crear una imagen de prueba simple
    import numpy as np
    test_img = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
    
    try:
        results = model(test_img, verbose=False)[0]
        
        return {
            "status": "success",
            "model_loaded": True,
            "test_detection_classes": list(results.names.values()) if hasattr(results, 'names') else [],
            "processed_at": "now()",
            "note": "Endpoint de debug - imagen sintética procesada correctamente"
        }
    except Exception as e:
        return {
            "status": "error",
            "error": str(e),
            "model_loaded": model is not None
        }
