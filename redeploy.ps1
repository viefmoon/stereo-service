# Script para redesplegar el servicio stereo con todas las variables configuradas
Write-Host "Redesplegando stereo-service con Supabase configurado..." -ForegroundColor Green

gcloud run deploy stereo-service `
  --image us-central1-docker.pkg.dev/gen-lang-client-0720673337/stereo-repo/stereo-service:latest `
  --platform managed `
  --region us-central1 `
  --allow-unauthenticated `
  --port 8000 `
  --memory 1Gi `
  --timeout 300 `
  --set-env-vars "BUCKET_NAME=crop-images,SUPABASE_URL=https://gbeffavfdvysxabblpdt.supabase.co,SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdiZWZmYXZmZHZ5c3hhYmJscGR0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQyNTgzNywiZXhwIjoyMDYzMDAxODM3fQ.d-XodTxJmu4cSqafjwmU_B9q9IDTm-JxOJ2JfkKQR90"

Write-Host "Despliegue completado!" -ForegroundColor Green 