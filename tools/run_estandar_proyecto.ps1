param(
    [Parameter(Mandatory = $true)]
    [string[]]$Paths,
    [ValidateSet('flexible', 'estricto')]
    [string]$Modo = 'flexible',
    [string]$TraceProfile,
    [string[]]$Needles,
    [switch]$AutoFixDocxCaptions
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$toolsRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$closeout = Join-Path $toolsRoot 'run_project_closeout.ps1'
$traceProfileRunner = Join-Path $toolsRoot 'run_traceability_profile.ps1'
$traceChecker = Join-Path $toolsRoot 'check_traceability_consistency.ps1'
$captionFix = Join-Path $toolsRoot 'autofix_docx_captions.ps1'

if (-not (Test-Path -LiteralPath $closeout)) {
    throw "No existe run_project_closeout.ps1 en $toolsRoot"
}

$strict = $Modo -eq 'estricto'
$docExt = @('.docx', '.docm')
$resolvedFiles = @()
foreach ($p in $Paths) {
    $abs = if ([System.IO.Path]::IsPathRooted($p)) { $p } else { Join-Path (Get-Location) $p }
    if (-not (Test-Path -LiteralPath $abs)) { throw "No existe la ruta: $p" }
    $item = Get-Item -LiteralPath $abs
    if ($item.PSIsContainer) {
        $resolvedFiles += Get-ChildItem -LiteralPath $item.FullName -Recurse -File | ForEach-Object { $_.FullName }
    } else {
        $resolvedFiles += $item.FullName
    }
}
$resolvedFiles = @($resolvedFiles | Sort-Object -Unique)
$docFiles = @($resolvedFiles | Where-Object { [System.IO.Path]::GetExtension($_).ToLowerInvariant() -in $docExt })

Write-Output ("== Pipeline estandar ({0}) ==" -f $Modo)
Write-Output ("Rutas de entrada: {0}" -f $Paths.Count)
Write-Output ("Ficheros detectados: {0}" -f $resolvedFiles.Count)

if ($AutoFixDocxCaptions -and $docFiles.Count -gt 0) {
    if (-not (Test-Path -LiteralPath $captionFix)) {
        throw "No existe autofix_docx_captions.ps1 en $toolsRoot"
    }
    Write-Output '== Autofix captions DOCX =='
    & $captionFix -Paths $docFiles -CaptionPrefix 'Tabla' -DefaultDescription 'Descripcion' -UseMontserrat $true
}

Write-Output '== Cierre documental/presupuesto =='
& $closeout -Paths $Paths -StrictDocxLayout $strict -RequireTableCaption $strict -CheckExcelFormulas $true

if (-not [string]::IsNullOrWhiteSpace($TraceProfile)) {
    if (-not (Test-Path -LiteralPath $traceProfileRunner)) {
        throw "No existe run_traceability_profile.ps1 en $toolsRoot"
    }
    Write-Output '== Trazabilidad por perfil =='
    if ($Needles -and $Needles.Count -gt 0) {
        & $traceProfileRunner -Profile $TraceProfile -Needles $Needles -StrictProfile:$strict
    } else {
        & $traceProfileRunner -Profile $TraceProfile -StrictProfile:$strict
    }
} elseif ($Needles -and $Needles.Count -gt 0) {
    if (-not (Test-Path -LiteralPath $traceChecker)) {
        throw "No existe check_traceability_consistency.ps1 en $toolsRoot"
    }
    Write-Output '== Trazabilidad por anclas =='
    & $traceChecker -Paths $resolvedFiles -Needles $Needles
}

Write-Output 'PIPELINE OK'
