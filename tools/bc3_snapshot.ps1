<#
.SYNOPSIS
    Captura el estado completo de un archivo BC3 en un snapshot JSON antes de modificarlo.

.DESCRIPTION
    Lee todos los registros ~C (conceptos), ~D (descomposicion), ~T (texto largo) y ~M (medicion)
    de un archivo BC3 y los guarda en un JSON estructurado en scratch/bc3_snapshots/.

    USAR SIEMPRE antes de cualquier modificacion, merge o recalc sobre un BC3.
    Sin snapshot previo no hay forma de saber que se perdio si algo sale mal.

.PARAMETER Path
    Ruta al archivo .bc3 o .pzh a capturar.

.PARAMETER Label
    Etiqueta opcional para identificar el snapshot (ej: "antes-merge", "antes-recalc").
    Si se omite, se usa "snapshot".

.PARAMETER OutPath
    Ruta de salida del JSON. Si se omite, se guarda en scratch\bc3_snapshots\ con nombre
    automatico: [nombre_bc3]_[label]_[timestamp].json

.EXAMPLE
    .\bc3_snapshot.ps1 -Path ".\535.2.bc3"
    .\bc3_snapshot.ps1 -Path ".\535.2.bc3" -Label "antes-merge-pavigesa"
    .\bc3_snapshot.ps1 -Path ".\535.2.bc3" -OutPath ".\scratch\before.json"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [Parameter(Mandatory=$false)]
    [string]$Label = "snapshot",

    [Parameter(Mandatory=$false)]
    [string]$OutPath = ""
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$SnapshotDir = Join-Path $ProjectRoot "scratch\bc3_snapshots"

# Resolver ruta del BC3
$Bc3Path = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path (Get-Location) $Path }
if (-not (Test-Path $Bc3Path)) { throw "No existe el archivo: $Bc3Path" }

$Ext = [System.IO.Path]::GetExtension($Bc3Path).ToLowerInvariant()
if ($Ext -notin @('.bc3', '.pzh')) { throw "Extension no soportada: $Ext" }

# Leer BC3 con encoding CP1252
$AnsiEnc = [System.Text.Encoding]::GetEncoding(1252)
$Raw = [System.IO.File]::ReadAllText($Bc3Path, $AnsiEnc)
$Lines = $Raw -split "`r?`n"

# Estructuras de datos
$Conceptos   = [ordered]@{}  # codigo -> {unidad, resumen, precio, tipo}
$Textos      = [ordered]@{}  # codigo -> texto largo
$Descomps    = [ordered]@{}  # codigo -> array de {comp, factor, rendimiento}
$Mediciones  = [ordered]@{}  # codigo -> linea raw de medicion
$NonRecords  = @()

foreach ($Line in $Lines) {
    $Line = $Line.TrimEnd()
    if ([string]::IsNullOrWhiteSpace($Line)) { continue }

    if (-not $Line.StartsWith('~')) {
        $NonRecords += $Line
        continue
    }

    $Tipo   = $Line.Substring(0, [Math]::Min(3, $Line.Length))
    $Campos = ($Line.Substring([Math]::Min(3, $Line.Length))) -split '\|'

    switch ($Tipo) {
        '~C|' {
            if ($Campos.Count -lt 1) { continue }
            $Codigo = $Campos[0]
            if ([string]::IsNullOrWhiteSpace($Codigo)) { continue }
            $Precio = 0.0
            if ($Campos.Count -gt 3 -and $Campos[3] -ne '') {
                [double]::TryParse($Campos[3], [System.Globalization.NumberStyles]::Float,
                    [System.Globalization.CultureInfo]::InvariantCulture, [ref]$Precio) | Out-Null
            }
            $Conceptos[$Codigo] = [PSCustomObject]@{
                unidad  = if ($Campos.Count -gt 1) { $Campos[1] } else { '' }
                resumen = if ($Campos.Count -gt 2) { $Campos[2] } else { '' }
                precio  = $Precio
                tipo    = if ($Campos.Count -gt 5) { $Campos[5] } else { '0' }
            }
        }
        '~T|' {
            if ($Campos.Count -lt 2) { continue }
            $Codigo = $Campos[0]
            if (-not [string]::IsNullOrWhiteSpace($Codigo)) {
                $Textos[$Codigo] = $Campos[1]
            }
        }
        '~D|' {
            if ($Campos.Count -lt 2) { continue }
            $Codigo = $Campos[0]
            if ([string]::IsNullOrWhiteSpace($Codigo)) { continue }
            $CompRaw = $Campos[1] -split '\\'
            $Comps = @()
            for ($i = 0; $i -lt $CompRaw.Count - 2; $i += 3) {
                if (-not [string]::IsNullOrWhiteSpace($CompRaw[$i])) {
                    $F = 1.0; $R = 0.0
                    [double]::TryParse($CompRaw[$i+1], [System.Globalization.NumberStyles]::Float,
                        [System.Globalization.CultureInfo]::InvariantCulture, [ref]$F) | Out-Null
                    [double]::TryParse($CompRaw[$i+2], [System.Globalization.NumberStyles]::Float,
                        [System.Globalization.CultureInfo]::InvariantCulture, [ref]$R) | Out-Null
                    $Comps += [PSCustomObject]@{ comp = $CompRaw[$i]; factor = $F; rendimiento = $R }
                }
            }
            $Descomps[$Codigo] = $Comps
        }
        '~M|' {
            if ($Campos.Count -lt 1) { continue }
            $Codigo = $Campos[0]
            if (-not [string]::IsNullOrWhiteSpace($Codigo)) {
                $Mediciones[$Codigo] = ($Campos | Select-Object -Skip 1) -join '|'
            }
        }
    }
}

# Construir snapshot
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Snapshot = [PSCustomObject]@{
    meta = [PSCustomObject]@{
        archivo    = [System.IO.Path]::GetFileName($Bc3Path)
        ruta       = $Bc3Path
        label      = $Label
        timestamp  = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
        n_conceptos  = $Conceptos.Count
        n_textos     = $Textos.Count
        n_descomps   = $Descomps.Count
        n_mediciones = $Mediciones.Count
        n_non_records = $NonRecords.Count
    }
    conceptos  = $Conceptos
    textos     = $Textos
    descomps   = $Descomps
    mediciones = $Mediciones
}

# Determinar ruta de salida
if ($OutPath -eq "") {
    if (-not (Test-Path $SnapshotDir)) {
        New-Item -ItemType Directory -Path $SnapshotDir -Force | Out-Null
    }
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($Bc3Path)
    $OutPath = Join-Path $SnapshotDir "${BaseName}_${Label}_${Timestamp}.json"
} else {
    $OutDir = Split-Path $OutPath -Parent
    if ($OutDir -ne "" -and -not (Test-Path $OutDir)) {
        New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    }
}

# Guardar
$Snapshot | ConvertTo-Json -Depth 10 | Set-Content $OutPath -Encoding UTF8

Write-Host "[bc3_snapshot] Snapshot guardado: $OutPath" -ForegroundColor Green
Write-Host ("  Conceptos: {0}  Textos: {1}  Descomps: {2}  Mediciones: {3}" -f `
    $Conceptos.Count, $Textos.Count, $Descomps.Count, $Mediciones.Count) -ForegroundColor DarkGray

if ($NonRecords.Count -gt 0) {
    Write-Warning "  AVISO: $($NonRecords.Count) lineas fuera de registro BC3 detectadas."
}

# Devolver la ruta para que otros scripts puedan encadenar
return $OutPath
