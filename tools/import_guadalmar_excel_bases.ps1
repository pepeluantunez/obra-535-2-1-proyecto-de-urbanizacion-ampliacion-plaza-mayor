param(
    [string]$SourceRoot = "..\MEJORA CARRETERA GUADALMAR\PROYECTO 535\535.2\535.2.2 Mejora Carretera Guadalmar\POU 2026",
    [string]$TargetRoot = ".\DOCS - PLANTILLAS\Excel\Bases Guadalmar",
    [string]$FontName = "Montserrat",
    [switch]$SkipStyle
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Resolve-FullPathSafe {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
}

$sourceResolved = Resolve-FullPathSafe -Path $SourceRoot
$targetResolved = Resolve-FullPathSafe -Path $TargetRoot

if (-not (Test-Path -LiteralPath $sourceResolved)) {
    throw "No existe SourceRoot: $SourceRoot"
}
if (-not (Test-Path -LiteralPath $targetResolved)) {
    New-Item -ItemType Directory -Path $targetResolved -Force | Out-Null
}

$mappings = @(
    [pscustomobject]@{
        RelativeSourceFolder = "DOCS\Documentos de Trabajo\5.- Dimensionamiento del Firme"
        SourcePattern = "Mediciones_Firme.xlsx"
        RelativeTarget = "05 - Firme\Mediciones_Firme.xlsx"
    }
    [pscustomobject]@{
        RelativeSourceFolder = "DOCS\Documentos de Trabajo\7.- Red de Saneamiento - Pluviales"
        SourcePattern = "C*Hidrol*gico*nueva IC-5.2*_A_535.2.xlsx"
        RelativeTarget = "07 - Pluviales\Calculo Hidrologico A - base Guadalmar.xlsx"
    }
    [pscustomobject]@{
        RelativeSourceFolder = "DOCS\Documentos de Trabajo\7.- Red de Saneamiento - Pluviales"
        SourcePattern = "C*Hidrol*gico*nueva IC-5.2*_B_535.2.xlsx"
        RelativeTarget = "07 - Pluviales\Calculo Hidrologico B - base Guadalmar.xlsx"
    }
    [pscustomobject]@{
        RelativeSourceFolder = "DOCS\Documentos de Trabajo\7.- Red de Saneamiento - Pluviales"
        SourcePattern = "SSA ABRIL26 2.xlsx"
        RelativeTarget = "07 - Pluviales\SSA Abril26 2 - base Guadalmar.xlsx"
    }
    [pscustomobject]@{
        RelativeSourceFolder = "DOCS\Documentos de Trabajo\11.-Red de Alumbrado"
        SourcePattern = "CALCULO EFICIENCIA ENERG*.*xlsx"
        RelativeTarget = "11 - Alumbrado\Calculo Eficiencia Energetica - base Guadalmar.xlsx"
    }
    [pscustomobject]@{
        RelativeSourceFolder = "DOCS\Excels_Estandarizados_2026-04-08\DOCS\Documentos de Trabajo\13.- Estudio de Gestion de Residuos"
        SourcePattern = "GR_535_2_2_CORREGIDO.xlsx"
        RelativeTarget = "13 - Residuos\Gestion de Residuos - base Guadalmar.xlsx"
    }
    [pscustomobject]@{
        RelativeSourceFolder = "DOCS\Documentos de Trabajo\14.- Control de Calidad"
        SourcePattern = "535.2.2 Control-Calidad.xlsx"
        RelativeTarget = "14 - Control de Calidad\Control de Calidad - base Guadalmar.xlsx"
    }
    [pscustomobject]@{
        RelativeSourceFolder = "DOCS\Documentos de Trabajo\15.- Plan de Obra"
        SourcePattern = "535.2.2 - Plan de Obra.xlsx"
        RelativeTarget = "15 - Plan de Obra\Plan de Obra - base Guadalmar.xlsx"
    }
    [pscustomobject]@{
        RelativeSourceFolder = "DOCS\Documentos de Trabajo\17.- Seguridad y Salud"
        SourcePattern = "Dimensionado_SyS_Guadalmar.xlsx"
        RelativeTarget = "17 - Seguridad y Salud\Dimensionado SyS - base Guadalmar.xlsx"
    }
)

$copiedFiles = New-Object System.Collections.Generic.List[string]
$reportRows = New-Object System.Collections.Generic.List[object]

foreach ($mapping in $mappings) {
    $sourceFolder = Join-Path $sourceResolved $mapping.RelativeSourceFolder
    if (-not (Test-Path -LiteralPath $sourceFolder)) {
        Write-Warning "No localizada carpeta origen: $sourceFolder"
        continue
    }

    $sourceCandidate = Get-ChildItem -LiteralPath $sourceFolder -File -Filter $mapping.SourcePattern -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $sourceCandidate) {
        Write-Warning "No localizado origen por patron '$($mapping.SourcePattern)' en $sourceFolder"
        continue
    }
    $sourcePath = $sourceCandidate.FullName

    $targetPath = Join-Path $targetResolved $mapping.RelativeTarget
    $targetDir = Split-Path -Parent $targetPath
    if (-not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
    $copiedFiles.Add($targetPath) | Out-Null

    $reportRows.Add([pscustomobject]@{
        origen = $sourcePath
        destino = $targetPath
        hoja = $mapping.RelativeTarget
    }) | Out-Null
}

if ($copiedFiles.Count -eq 0) {
    throw "No se ha copiado ningun Excel desde Guadalmar."
}

$tmpRoot = Join-Path (Get-Location).Path ".codex_tmp\guadalmar_excel_import"
if (-not (Test-Path -LiteralPath $tmpRoot)) {
    New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null
}

$beforeManifest = Join-Path $tmpRoot "before.json"
$styleFailures = New-Object System.Collections.Generic.List[string]
$reportJson = Join-Path $tmpRoot "report.json"
$reportMd = Join-Path (Join-Path (Get-Location).Path "CONTROL") "guadalmar_excel_import.md"

& (Join-Path $PSScriptRoot "check_excel_formula_guard.ps1") -Paths $copiedFiles -WriteManifestPath $beforeManifest | Out-Host

if (-not $SkipStyle) {
    foreach ($copiedFile in $copiedFiles) {
        try {
            & (Join-Path $PSScriptRoot "excel_style_safe.ps1") -Paths $copiedFile -FontName $FontName | Out-Host
        } catch {
            $styleFailures.Add($copiedFile) | Out-Null
            Write-Warning ("Fallo de estandarizacion visual en: {0}" -f $copiedFile)
            Write-Warning $_.Exception.Message
        }
    }
}

& (Join-Path $PSScriptRoot "check_excel_formula_guard.ps1") -Paths $copiedFiles -BaselineManifestPath $beforeManifest | Out-Host
& (Join-Path $PSScriptRoot "check_office_mojibake.ps1") -Paths $copiedFiles | Out-Host

$reportRows | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportJson -Encoding UTF8

$md = New-Object System.Collections.Generic.List[string]
[void]$md.Add("# Importacion de Excels base desde Guadalmar")
[void]$md.Add("")
[void]$md.Add("- Fecha: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))")
[void]$md.Add("- Fuente: $sourceResolved")
[void]$md.Add("- Destino: $targetResolved")
[void]$md.Add("- Tipografia aplicada: $(if ($SkipStyle) { 'sin estandarizacion visual' } else { $FontName })")
[void]$md.Add("- Fallos de estandarizacion visual: $(if ($styleFailures.Count -eq 0) { 'ninguno' } else { $styleFailures.Count })")
[void]$md.Add("")
[void]$md.Add("| Destino | Origen |")
[void]$md.Add("|---|---|")
foreach ($row in $reportRows) {
    [void]$md.Add("| $($row.destino.Replace((Get-Location).Path + '\','')) | $($row.origen) |")
}
$md.Add("")
if ($styleFailures.Count -gt 0) {
    [void]$md.Add("## Incidencias")
    [void]$md.Add("")
    foreach ($failure in $styleFailures) {
        [void]$md.Add("- Estandarizacion visual no aplicada en: $($failure.Replace((Get-Location).Path + '\',''))")
    }
}
$md | Set-Content -LiteralPath $reportMd -Encoding UTF8

[pscustomobject]@{
    CopiedCount = $copiedFiles.Count
    TargetRoot = $targetResolved
    ReportMarkdown = $reportMd
    ReportJson = $reportJson
    StyleFailures = $styleFailures.Count
}
