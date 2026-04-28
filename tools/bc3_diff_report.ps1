<#
.SYNOPSIS
    Compara dos snapshots BC3 y genera un informe detallado de cambios y perdidas.

.DESCRIPTION
    Compara dos archivos JSON generados por bc3_snapshot.ps1 y detecta:
    - Conceptos eliminados (PERDIDA CRITICA)
    - Conceptos nuevos (anadidos)
    - Precios cambiados
    - Descomposiciones (~D) modificadas o eliminadas
    - Textos largos (~T) modificados
    - Mediciones (~M) afectadas

    El informe se guarda en scratch\bc3_snapshots\ como Markdown.

.PARAMETER Before
    Ruta al snapshot JSON del estado ANTES de la modificacion.

.PARAMETER After
    Ruta al snapshot JSON del estado DESPUES de la modificacion.
    Si se omite, se busca el snapshot mas reciente del mismo archivo BC3.

.PARAMETER OutPath
    Ruta del informe Markdown de salida. Si se omite, se genera automaticamente.

.PARAMETER SoloProblemas
    Si se activa, omite los conceptos sin cambios del informe.

.EXAMPLE
    .\bc3_diff_report.ps1 -Before ".\scratch\bc3_snapshots\535.2_antes-merge_20260421.json" -After ".\scratch\bc3_snapshots\535.2_despues-merge_20260421.json"
    .\bc3_diff_report.ps1 -Before ".\scratch\before.json" -After ".\scratch\after.json" -SoloProblemas
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Before,

    [Parameter(Mandatory=$true)]
    [string]$After,

    [Parameter(Mandatory=$false)]
    [string]$OutPath = "",

    [Parameter(Mandatory=$false)]
    [switch]$SoloProblemas
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$SnapshotDir = Join-Path $ProjectRoot "scratch\bc3_snapshots"

# Resolver rutas
foreach ($RutaParam in @($Before, $After)) {
    $Ruta = if ([System.IO.Path]::IsPathRooted($RutaParam)) { $RutaParam } else { Join-Path (Get-Location) $RutaParam }
    if (-not (Test-Path $Ruta)) { throw "No existe el snapshot: $RutaParam" }
}

$BeforePath = if ([System.IO.Path]::IsPathRooted($Before)) { $Before } else { Join-Path (Get-Location) $Before }
$AfterPath  = if ([System.IO.Path]::IsPathRooted($After))  { $After  } else { Join-Path (Get-Location) $After  }

# Cargar snapshots
$SnapA = Get-Content $BeforePath -Raw -Encoding UTF8 | ConvertFrom-Json
$SnapB = Get-Content $AfterPath  -Raw -Encoding UTF8 | ConvertFrom-Json

function Get-DictKeys {
    param($Obj)
    if ($null -eq $Obj) { return @() }
    return @($Obj.PSObject.Properties.Name)
}

function Get-Val {
    param($Obj, $Key)
    if ($null -eq $Obj) { return $null }
    $Prop = $Obj.PSObject.Properties[$Key]
    if ($null -eq $Prop) { return $null }
    return $Prop.Value
}

# Extraer colecciones
$CodsA = @(Get-DictKeys $SnapA.conceptos)
$CodsB = @(Get-DictKeys $SnapB.conceptos)

$Eliminados  = @($CodsA | Where-Object { $_ -notin $CodsB })
$Nuevos      = @($CodsB | Where-Object { $_ -notin $CodsA })
$Comunes     = @($CodsA | Where-Object { $_ -in $CodsB })

# Analizar cambios en comunes
$PreciosCambiados  = @()
$DescompsCambiadas = @()
$TextosCambiados   = @()
$MedicionesCamb    = @()

foreach ($Cod in $Comunes) {
    $CA = Get-Val $SnapA.conceptos $Cod
    $CB = Get-Val $SnapB.conceptos $Cod

    # Precio
    $PrecioA = if ($CA) { [double]$CA.precio } else { 0.0 }
    $PrecioB = if ($CB) { [double]$CB.precio } else { 0.0 }
    if ([Math]::Abs($PrecioA - $PrecioB) -gt 0.01) {
        $PreciosCambiados += [PSCustomObject]@{
            codigo  = $Cod
            resumen = if ($CA) { $CA.resumen } else { '' }
            antes   = $PrecioA
            despues = $PrecioB
            delta   = $PrecioB - $PrecioA
        }
    }

    # Descomposicion
    $DA = Get-Val $SnapA.descomps $Cod
    $DB = Get-Val $SnapB.descomps $Cod
    $DA_str = if ($DA) { ($DA | ForEach-Object { "$($_.comp):$($_.factor):$($_.rendimiento)" }) -join '|' } else { '' }
    $DB_str = if ($DB) { ($DB | ForEach-Object { "$($_.comp):$($_.factor):$($_.rendimiento)" }) -join '|' } else { '' }
    if ($DA_str -ne $DB_str) {
        $DescompsCambiadas += [PSCustomObject]@{
            codigo       = $Cod
            resumen      = if ($CA) { $CA.resumen } else { '' }
            comps_antes  = if ($DA) { $DA.Count } else { 0 }
            comps_despues = if ($DB) { $DB.Count } else { 0 }
            antes_raw    = $DA_str
            despues_raw  = $DB_str
        }
    }

    # Texto
    $TA = Get-Val $SnapA.textos $Cod
    $TB = Get-Val $SnapB.textos $Cod
    if ($TA -ne $TB -and (-not [string]::IsNullOrWhiteSpace($TA) -or -not [string]::IsNullOrWhiteSpace($TB))) {
        $TextosCambiados += [PSCustomObject]@{
            codigo = $Cod
            resumen = if ($CA) { $CA.resumen } else { '' }
        }
    }

    # Medicion
    $MA = Get-Val $SnapA.mediciones $Cod
    $MB = Get-Val $SnapB.mediciones $Cod
    if ($MA -ne $MB) {
        $MedicionesCamb += [PSCustomObject]@{
            codigo  = $Cod
            resumen = if ($CA) { $CA.resumen } else { '' }
        }
    }
}

# Calcular severidad global
$HayPerdidas = $Eliminados.Count -gt 0
$HayCambios  = $PreciosCambiados.Count -gt 0 -or $DescompsCambiadas.Count -gt 0

# Generar informe Markdown
$Fecha = Get-Date -Format "yyyy-MM-dd HH:mm"
$Informe = @"
# Informe de diferencias BC3
Generado: $Fecha

| | Antes | Despues | Diferencia |
|---|---|---|---|
| Conceptos (~C) | $($SnapA.meta.n_conceptos) | $($SnapB.meta.n_conceptos) | $(($SnapB.meta.n_conceptos - $SnapA.meta.n_conceptos)) |
| Descomposiciones (~D) | $($SnapA.meta.n_descomps) | $($SnapB.meta.n_descomps) | $(($SnapB.meta.n_descomps - $SnapA.meta.n_descomps)) |
| Textos (~T) | $($SnapA.meta.n_textos) | $($SnapB.meta.n_textos) | $(($SnapB.meta.n_textos - $SnapA.meta.n_textos)) |
| Mediciones (~M) | $($SnapA.meta.n_mediciones) | $($SnapB.meta.n_mediciones) | $(($SnapB.meta.n_mediciones - $SnapA.meta.n_mediciones)) |

**Archivo antes:** $($SnapA.meta.archivo) — $($SnapA.meta.label) — $($SnapA.meta.timestamp)
**Archivo despues:** $($SnapB.meta.archivo) — $($SnapB.meta.label) — $($SnapB.meta.timestamp)

---

"@

# PERDIDAS (critico)
if ($Eliminados.Count -gt 0) {
    $Informe += "## ⛔ PERDIDA CRITICA — Conceptos eliminados ($($Eliminados.Count))`n`n"
    $Informe += "Estos codigos estaban en el BC3 original y han DESAPARECIDO:`n`n"
    foreach ($Cod in $Eliminados) {
        $C = Get-Val $SnapA.conceptos $Cod
        $Precio = if ($C) { $C.precio } else { '?' }
        $Resumen = if ($C) { $C.resumen } else { '(sin descripcion)' }
        $TieneDescomp = (Get-Val $SnapA.descomps $Cod) -ne $null
        $TieneMedicion = (Get-Val $SnapA.mediciones $Cod) -ne $null
        $Extras = @()
        if ($TieneDescomp) { $Extras += "~D" }
        if ($TieneMedicion) { $Extras += "~M" }
        $ExtrasStr = if ($Extras.Count -gt 0) { " [tenia: $($Extras -join ', ')]" } else { "" }
        $Informe += "- ``$Cod`` — $Resumen — precio: $Precio€$ExtrasStr`n"
    }
    $Informe += "`n---`n`n"
} else {
    $Informe += "## ✅ Sin perdidas de conceptos`n`nNo se ha eliminado ningun concepto ~C.`n`n---`n`n"
}

# NUEVOS
if ($Nuevos.Count -gt 0) {
    $Informe += "## ➕ Conceptos nuevos ($($Nuevos.Count))`n`n"
    foreach ($Cod in ($Nuevos | Select-Object -First 30)) {
        $C = Get-Val $SnapB.conceptos $Cod
        $Precio = if ($C) { $C.precio } else { '?' }
        $Resumen = if ($C) { $C.resumen } else { '(sin descripcion)' }
        $Informe += "- ``$Cod`` — $Resumen — precio: $Precio€`n"
    }
    if ($Nuevos.Count -gt 30) { $Informe += "- ... $($Nuevos.Count - 30) conceptos adicionales`n" }
    $Informe += "`n---`n`n"
}

# PRECIOS CAMBIADOS
if ($PreciosCambiados.Count -gt 0) {
    $Informe += "## ⚠️ Precios cambiados ($($PreciosCambiados.Count))`n`n"
    $Informe += "| Codigo | Resumen | Antes | Despues | Delta |`n"
    $Informe += "|--------|---------|-------|---------|-------|`n"
    foreach ($C in ($PreciosCambiados | Sort-Object { [Math]::Abs($_.delta) } -Descending | Select-Object -First 40)) {
        $Sign = if ($C.delta -gt 0) { "+" } else { "" }
        $Informe += "| ``$($C.codigo)`` | $($C.resumen) | $($C.antes)€ | $($C.despues)€ | ${Sign}$([Math]::Round($C.delta,2))€ |`n"
    }
    if ($PreciosCambiados.Count -gt 40) { $Informe += "`n... $($PreciosCambiados.Count - 40) cambios adicionales`n" }
    $Informe += "`n---`n`n"
}

# DESCOMPOSICIONES CAMBIADAS
if ($DescompsCambiadas.Count -gt 0) {
    $Informe += "## 🔧 Descomposiciones (~D) modificadas ($($DescompsCambiadas.Count))`n`n"
    foreach ($D in ($DescompsCambiadas | Select-Object -First 25)) {
        $Informe += "### ``$($D.codigo)`` — $($D.resumen)`n"
        $Informe += "- Componentes antes: $($D.comps_antes) | Componentes despues: $($D.comps_despues)`n"
        if ($D.comps_antes -gt $D.comps_despues) {
            $Informe += "- ⚠️ Se han perdido componentes en la descomposicion`n"
        }
        $Informe += "`n"
    }
    if ($DescompsCambiadas.Count -gt 25) { $Informe += "... $($DescompsCambiadas.Count - 25) descomposiciones adicionales`n" }
    $Informe += "`n---`n`n"
}

# TEXTOS CAMBIADOS
if ($TextosCambiados.Count -gt 0 -and -not $SoloProblemas) {
    $Informe += "## 📝 Textos largos (~T) modificados ($($TextosCambiados.Count))`n`n"
    foreach ($T in ($TextosCambiados | Select-Object -First 20)) {
        $Informe += "- ``$($T.codigo)`` — $($T.resumen)`n"
    }
    $Informe += "`n---`n`n"
}

# MEDICIONES CAMBIADAS
if ($MedicionesCamb.Count -gt 0) {
    $Informe += "## 📐 Mediciones (~M) afectadas ($($MedicionesCamb.Count))`n`n"
    $Informe += "> ATENCION: Las ~M son intocables por defecto. Si no se uso --allow-mediciones, estos cambios son inesperados.`n`n"
    foreach ($M in ($MedicionesCamb | Select-Object -First 20)) {
        $Informe += "- ``$($M.codigo)`` — $($M.resumen)`n"
    }
    $Informe += "`n---`n`n"
}

# RESUMEN FINAL
$Informe += "## Resumen`n`n"
if ($Eliminados.Count -eq 0 -and $MedicionesCamb.Count -eq 0) {
    $Informe += "✅ Sin perdidas de datos criticos.`n"
} else {
    if ($Eliminados.Count -gt 0) { $Informe += "⛔ $($Eliminados.Count) concepto(s) eliminado(s) — REVISAR ANTES DE CONTINUAR.`n" }
    if ($MedicionesCamb.Count -gt 0) { $Informe += "⚠️ $($MedicionesCamb.Count) medicion(es) afectadas — verificar si fue intencionado.`n" }
}
if ($PreciosCambiados.Count -gt 0) { $Informe += "ℹ️ $($PreciosCambiados.Count) precio(s) cambiado(s).`n" }
if ($DescompsCambiadas.Count -gt 0) { $Informe += "ℹ️ $($DescompsCambiadas.Count) descomposicion(es) modificada(s).`n" }
if ($Nuevos.Count -gt 0) { $Informe += "ℹ️ $($Nuevos.Count) concepto(s) nuevo(s) anadido(s).`n" }

# Guardar informe
if ($OutPath -eq "") {
    if (-not (Test-Path $SnapshotDir)) { New-Item -ItemType Directory -Path $SnapshotDir -Force | Out-Null }
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutPath = Join-Path $SnapshotDir "diff_report_${Timestamp}.md"
}

$Informe | Set-Content $OutPath -Encoding UTF8

Write-Host "[bc3_diff_report] Informe generado: $OutPath" -ForegroundColor Green
if ($Eliminados.Count -gt 0) {
    Write-Host "  ⛔ ATENCION: $($Eliminados.Count) concepto(s) eliminado(s)." -ForegroundColor Red
} elseif ($HayCambios) {
    Write-Host "  ⚠️ Hay cambios en precios o descomposiciones. Revisar el informe." -ForegroundColor Yellow
} else {
    Write-Host "  ✅ Sin perdidas detectadas." -ForegroundColor Green
}

return $OutPath
