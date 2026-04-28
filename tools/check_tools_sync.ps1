# check_tools_sync.ps1
# Compara SHA256 de los tools canonicos en urbanizacion-toolkit con las copias locales en tools/.
# Si hay divergencia, avisa: la copia local esta desactualizada respecto a la fuente del ecosistema.
#
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_tools_sync.ps1
#
# Regla: urbanizacion-toolkit/tools/python/ es la fuente canonica.
# Las copias en tools/ deben ser identicas.
# Si difieren: ejecutar .\tools\sync_from_toolkit.ps1 para sincronizar.

param(
    [string]$ToolkitPath = "C:\Users\USUARIO\Documents\Claude\Projects\urbanizacion-toolkit"
)

$ErrorActionPreference = "Stop"

# Herramientas canonicas que deben existir en ambos lados
$canonicalTools = @(
    "bc3_tools.py",
    "excel_tools.py",
    "mediciones_validator.py"
)

$localToolsDir = (Resolve-Path (Join-Path $PSScriptRoot "..\tools")).Path
$canonicalDir  = Join-Path $ToolkitPath "tools\python"

Write-Host "=== check_tools_sync ==="
Write-Host "Fuente canonica : $canonicalDir"
Write-Host "Copia local     : $localToolsDir"
Write-Host ""

if (-not (Test-Path $canonicalDir)) {
    Write-Host "AVISO: toolkit no encontrado en '$canonicalDir'." -ForegroundColor Yellow
    Write-Host "       Especifica la ruta con -ToolkitPath <ruta>." -ForegroundColor Yellow
    exit 2
}

$errors  = 0
$ok      = 0
$missing = 0

foreach ($tool in $canonicalTools) {
    $canonical = Join-Path $canonicalDir $tool
    $local     = Join-Path $localToolsDir $tool

    if (-not (Test-Path $canonical)) {
        Write-Host "AVISO  $tool : no en toolkit/tools/python/" -ForegroundColor Yellow
        $missing++
        continue
    }

    if (-not (Test-Path $local)) {
        Write-Host "ERROR  $tool : falta en tools/ local" -ForegroundColor Red
        $errors++
        continue
    }

    $hashCanon = (Get-FileHash $canonical -Algorithm SHA256).Hash.ToUpper()
    $hashLocal = (Get-FileHash $local     -Algorithm SHA256).Hash.ToUpper()

    if ($hashCanon -eq $hashLocal) {
        Write-Host "OK     $tool" -ForegroundColor Green
        $ok++
    } else {
        Write-Host "DRIFT  $tool : copias difieren" -ForegroundColor Red
        Write-Host "       toolkit: $hashCanon"
        Write-Host "       local  : $hashLocal"
        Write-Host "       Accion: ejecutar .\tools\sync_from_toolkit.ps1"
        $errors++
    }
}

Write-Host ""
Write-Host "Resultado: $ok OK / $errors con drift / $missing no en toolkit"

if ($errors -gt 0) {
    Write-Host "FALLO: divergencia detectada. Ejecuta sync_from_toolkit.ps1." -ForegroundColor Red
    exit 1
} else {
    Write-Host "OK: herramientas sincronizadas con toolkit." -ForegroundColor Green
    exit 0
}
