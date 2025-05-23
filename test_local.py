#!/usr/bin/env python3
"""
Script de prueba para verificar que el servicio stereo funciona correctamente.
Usa este script para probar localmente antes de desplegar.
"""

import asyncio
import aiohttp
import os
from dotenv import load_dotenv

# Cargar variables de entorno
load_dotenv()

BASE_URL = "http://localhost:8000"

async def test_health():
    """Prueba el endpoint de salud"""
    async with aiohttp.ClientSession() as session:
        try:
            async with session.get(f"{BASE_URL}/health") as resp:
                if resp.status == 200:
                    data = await resp.json()
                    print(f"✅ Health check: {data}")
                    return True
                else:
                    print(f"❌ Health check failed: {resp.status}")
                    return False
        except Exception as e:
            print(f"❌ Error connecting to service: {e}")
            return False

async def test_docs():
    """Prueba que la documentación esté disponible"""
    async with aiohttp.ClientSession() as session:
        try:
            async with session.get(f"{BASE_URL}/docs") as resp:
                if resp.status == 200:
                    print("✅ Documentation accessible at /docs")
                    return True
                else:
                    print(f"❌ Documentation not accessible: {resp.status}")
                    return False
        except Exception as e:
            print(f"❌ Error accessing docs: {e}")
            return False

async def main():
    print("🔍 Testing Stereo Service...")
    print(f"📡 Base URL: {BASE_URL}")
    print("=" * 50)
    
    # Verificar variables de entorno
    required_vars = ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY"]
    for var in required_vars:
        if not os.getenv(var):
            print(f"⚠️  Warning: {var} not set in environment")
        else:
            print(f"✅ {var} is configured")
    
    print("=" * 50)
    
    # Ejecutar pruebas
    tests = [
        ("Health Check", test_health()),
        ("Documentation", test_docs()),
    ]
    
    results = []
    for name, test_coro in tests:
        print(f"\n🧪 Testing {name}...")
        result = await test_coro
        results.append((name, result))
    
    print("\n" + "=" * 50)
    print("📊 Test Results:")
    for name, passed in results:
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"  {name}: {status}")
    
    all_passed = all(result for _, result in results)
    if all_passed:
        print("\n🎉 All tests passed! Service is ready.")
    else:
        print("\n⚠️  Some tests failed. Check the configuration.")
    
    return all_passed

if __name__ == "__main__":
    asyncio.run(main()) 