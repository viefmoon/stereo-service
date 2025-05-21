"""
API FastAPI: mide frutos en fotos estereoscópicas 3480×1080.
Copiado del ejemplo previo con comentarios en castellano.
"""
from fastapi import FastAPI, HTTPException
from supabase import create_client
from ultralytics import YOLO
import cv2, numpy as np, aiohttp, os, math

FOCAL_PX   = 783.0          # ajustar
BASELINE_MM = 55.0          # medir

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
BUCKET       = os.getenv("BUCKET_NAME", "stereo")

app = FastAPI(title="Stereo Fruit Size API")
sb  = create_client(SUPABASE_URL, SUPABASE_KEY)
model = YOLO("yolov8n.pt")

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

@app.get("/process/{path:path}")
async def process(path: str):
    url = sb.storage.from_(BUCKET).get_public_url(path)
    img = cv2.imdecode(np.frombuffer(await http_get(url), np.uint8),
                       cv2.IMREAD_COLOR)
    if img is None or img.shape != (1080, 3480, 3):
        raise HTTPException(422, "Imagen debe ser 3480×1080 RGB")

    left, right = np.hsplit(img, 2)
    disp   = disparity(cv2.cvtColor(left, cv2.COLOR_BGR2GRAY),
                       cv2.cvtColor(right, cv2.COLOR_BGR2GRAY))
    depth  = depth_from_disp(disp)

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
            "volume_mm3": round(vol_mm3,1)
        })
    return {"n_fruits": len(out), "fruits": out}
