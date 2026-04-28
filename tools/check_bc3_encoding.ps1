# check_bc3_encoding.ps1
# Verifica que un archivo BC3 usa codificacion ANSI/latin-1 y no contiene secuencias UTF-8 multibyte.
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_bc3_encoding.ps1 -Path "<archivo.bc3>"
#
# Regla: los archivos BC3 FIEBDC-3/2020 deben estar en ANSI (Windows-1252 / latin-1).
# Si se escribe con UTF-8 aparecen secuencias multibyte (0xC3, 0xC2, 0xE2...) que
# Presto lee como mojibake (Ã, Â, â€", etc.).

param(
    [Parameter(Mandatory=$true)]
    [string]$Path
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Path)) {
    Write-Error "Archivo no encontrado: $Path"
    exit 2
}

$bytes = [System.IO.File]::ReadAllBytes($Path)
$len   = $bytes.Length

Write-Host "BC3 encoding check: $Path"
Write-Host "Tamano: $len bytes"

# Detectar BOM UTF-8 (EF BB BF)
if ($len -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Host "ERROR: BOM UTF-8 detectado al inicio del archivo." -ForegroundColor Red
    exit 1
}

# Buscar secuencias UTF-8 multibyte mas comunes que indican mojibake
# 0xC3 seguido de byte en rango 0x80-0xBF = vocales acentuadas, enye, etc. en UTF-8
# 0xC2 seguido de byte en rango 0x80-0xBF = simbolos de control Latin-1 en UTF-8
# 0xE2 0x80 ... = comillas tipograficas, guiones em/en en UTF-8
$errors   = 0
$warnings = 0
$maxReport = 10

$mojibakePatterns = @(
    @{ Lead = 0xC3; Desc = "vocales acentuadas / enye (UTF-8 C3 xx)" },
    @{ Lead = 0xC2; Desc = "simbolos latin-1 como no-break space (UTF-8 C2 xx)" },
    @{ Lead = 0xE2; Desc = "comillas/guiones tipograficos (UTF-8 E2 80 xx)" }
)

$findings = @()

for ($i = 0; $i -lt ($len - 1); $i++) {
    foreach ($pat in $mojibakePatterns) {
        if ($bytes[$i] -eq $pat.Lead -and $bytes[$i+1] -ge 0x80 -and $bytes[$i+1] -le 0xBF) {
            $findings += [PSCustomObject]@{
                Offset = $i
                Hex    = ("0x{0:X2} 0x{1:X2}" -f $bytes[$i], $bytes[$i+1])
                Desc   = $pat.Desc
            }
            $errors++
            break
        }
    }
    if ($errors -ge $maxReport) {
        Write-Host "  ... (detenido en $maxReport hallazgos)" -ForegroundColor Yellow
        break
    }
}

if ($errors -eq 0) {
    Write-Host "OK: sin secuencias UTF-8 multibyte detectadas. Codificacion ANSI/latin-1 correcta." -ForegroundColor Green
    exit 0
} else {
    Write-Host "ERROR: $errors secuencias UTF-8 multibyte encontradas (mojibake probable)." -ForegroundColor Red
    foreach ($f in $findings) {
        Write-Host ("  Offset {0,8}: {1}  — {2}" -f $f.Offset, $f.Hex, $f.Desc)
    }
    Write-Host ""
    Write-Host "Accion correctiva: reescribir el BC3 con encoding=latin-1 (ANSI)." -ForegroundColor Yellow
    Write-Host "Nunca usar encoding='utf-8' al escribir archivos BC3." -ForegroundColor Yellow
    exit 1
}
