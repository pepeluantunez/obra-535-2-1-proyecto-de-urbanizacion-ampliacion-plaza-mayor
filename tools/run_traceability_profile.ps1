param(
    [string]$Profile = 'base_general',
    [string]$ProfileFile = '.\\CONFIG\\trazabilidad_profiles.json',
    [string[]]$Needles,
    [switch]$StrictProfile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$profilePath = if ([System.IO.Path]::IsPathRooted($ProfileFile)) {
    $ProfileFile
} else {
    Join-Path (Get-Location) $ProfileFile
}

if (-not (Test-Path -LiteralPath $profilePath)) {
    throw "No existe el fichero de perfiles de trazabilidad: $ProfileFile"
}

$json = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
$profileNames = @($json.PSObject.Properties.Name)
if ($profileNames -notcontains $Profile) {
    throw ("Perfil no encontrado: {0}. Perfiles disponibles: {1}" -f $Profile, ($profileNames -join ', '))
}

$inputPaths = @($json.$Profile)
if ($inputPaths.Count -eq 0) {
    throw "El perfil '$Profile' no contiene rutas."
}

$supportedExtensions = @('.bc3', '.docx', '.docm', '.xlsx', '.xlsm', '.csv', '.txt', '.md', '.html', '.htm', '.xml')
$resolved = @()
$missing = @()
$unsupported = @()
foreach ($p in $inputPaths) {
    $abs = if ([System.IO.Path]::IsPathRooted($p)) { $p } else { Join-Path (Get-Location) $p }
    if (Test-Path -LiteralPath $abs) {
        $item = Get-Item -LiteralPath $abs
        if ($item.PSIsContainer) {
            $resolved += $abs
        } else {
            $ext = [System.IO.Path]::GetExtension($abs).ToLowerInvariant()
            if ($supportedExtensions -contains $ext) {
                $resolved += $abs
            } else {
                $unsupported += $p
            }
        }
    } else {
        $missing += $p
    }
}

Write-Output ("Perfil trazabilidad: {0}" -f $Profile)
Write-Output ("Modo perfil: {0}" -f ($(if ($StrictProfile) { 'estricto' } else { 'flexible' })))
Write-Output ("Rutas configuradas: {0}" -f $inputPaths.Count)
Write-Output ("Rutas existentes: {0}" -f $resolved.Count)
if ($missing.Count -gt 0) {
    Write-Output ("Rutas ausentes: {0}" -f $missing.Count)
    foreach ($m in ($missing | Select-Object -First 20)) {
        Write-Output ("  - {0}" -f $m)
    }
}
if ($unsupported.Count -gt 0) {
    Write-Output ("Rutas no soportadas (omitidas): {0}" -f $unsupported.Count)
    foreach ($u in ($unsupported | Select-Object -First 20)) {
        Write-Output ("  - {0}" -f $u)
    }
    Write-Output 'Recomendacion: convertir esas fuentes a .xlsx/.md/.txt para trazabilidad automatica completa.'
}

if ($StrictProfile -and ($missing.Count -gt 0 -or $unsupported.Count -gt 0)) {
    throw ("Perfil '{0}' invalido en modo estricto: faltan {1} ruta(s) y hay {2} ruta(s) no soportada(s)." -f $Profile, $missing.Count, $unsupported.Count)
}

if ($resolved.Count -eq 0) {
    throw "No hay rutas existentes para el perfil '$Profile'."
}

$checker = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'check_traceability_consistency.ps1'
if (-not (Test-Path -LiteralPath $checker)) {
    throw "No existe el verificador de trazabilidad: $checker"
}

if ($Needles -and $Needles.Count -gt 0) {
    & $checker -Paths $resolved -Needles $Needles
} else {
    & $checker -Paths $resolved
}
