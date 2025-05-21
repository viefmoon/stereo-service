# Stereo-service

API que mide distancia y tamaño de frutos en fotos estereoscópicas (3480×1080)
almacenadas en Supabase Storage y desplegada en Google Cloud Run.

## Ejecutar localmente

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:api --reload
