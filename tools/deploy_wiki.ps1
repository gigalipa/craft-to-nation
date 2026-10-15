<#
.SYNOPSIS
    Compila, verifica y prepara el despliegue manual de la Wiki de Craft to Nation en Netlify.

.DESCRIPTION
    1. Ejecuta el build estático de VitePress en website/wiki/
    2. Ejecuta tools/verify_wiki_bundle.py para asegurar cero dead links y todos los assets
    3. Si se especifica el parámetro -Deploy, ejecuta 'netlify deploy --prod --dir=website'
#>

param(
    [switch]$Deploy
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Wiki de Craft to Nation - Build Pipeline" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Compilación de VitePress
Write-Host "`n[1/3] Compilando VitePress en website/wiki/..." -ForegroundColor Yellow
pnpm --prefix website/wiki run build
if ($LASTEXITCODE -ne 0) {
    Write-Error "Fallo en la compilación de VitePress."
    exit 1
}

# 2. Verificación de Integridad
Write-Host "`n[2/3] Verificando integridad del bundle generado..." -ForegroundColor Yellow
python tools/verify_wiki_bundle.py
if ($LASTEXITCODE -ne 0) {
    Write-Error "Fallo en la verificación del bundle de la wiki."
    exit 1
}

# 3. Despliegue a Netlify
Write-Host "`n[3/3] Estado de Despliegue:" -ForegroundColor Yellow
if ($Deploy) {
    Write-Host "Iniciando despliegue manual a producción en Netlify..." -ForegroundColor Cyan
    netlify deploy --prod --dir=website
} else {
    Write-Host "[OK] Compilacion e integridad 100% verificadas." -ForegroundColor Green
    Write-Host "Para desplegar a produccion sin gastar minutos de build en Netlify, ejecuta:" -ForegroundColor Green
    Write-Host "  powershell -ExecutionPolicy Bypass -File tools/deploy_wiki.ps1 -Deploy" -ForegroundColor White
    Write-Host "o directamente:" -ForegroundColor Green
    Write-Host "  netlify deploy --prod --dir=website" -ForegroundColor White
}
