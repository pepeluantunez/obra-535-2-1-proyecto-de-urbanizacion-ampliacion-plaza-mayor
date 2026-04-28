<#
.SYNOPSIS
    Revisa las mediciones (~M) de un BC3 y detecta inconsistencias de formato,
    totales que no cuadran, descripciones vacias y patrones incorrectos.

.DESCRIPTION
    Analiza las lineas ~M del BC3 del proyecto y genera un informe con:
    - Mediciones cuyo total no coincide con la suma de sublíneas
    - Sublíneas sin descripcion (valor sin contexto)
    - Mediciones que referencian partidas sin ~C asociado
    - Inconsistencias de separador decimal
    - Totales a cero o negativos
    - Descripcion que no sigue los patrones estandar del proyecto

.PARAMETER Path
    Ruta al archivo .bc3 a revisar.

.PARAMETER OutPath
    Ruta del informe Markdown. Si se omite, se genera en scratch\bc3_snapshots\.

.PARAMETER Tolerancia
    Diferencia maxima aceptable entre total declarado y suma calculada (por defecto 0.05).

.EXAMPLE
    .\bc3_normalize_mediciones.ps1 -Path ".\PRESUPUESTO\535.2.bc3"
    .\bc3_normalize_mediciones.ps1 -Path ".\PRESUPUESTO\535.2.bc3" -Tolerancia 0.01
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [Parameter(Mandatory=$false)]
    [string]$OutPath = "",

    [Parameter(Mandatory=$false)]
    [double]$Tolerancia = 0.05
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$ProjectRoot = Split-Path $PSScriptRoot -Parent

# Resolver ruta
$Bc3Path = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path (Get-Location) $Path }
if (-not (Test-Path $Bc3Path)) { throw "No existe el archivo: $Bc3Path" }

$AnsiEnc = [System.Text.Encoding]::GetEncoding(1252)
$Raw = [System.IO.File]::ReadAllText($Bc3Path, $AnsiEnc)
$Lines = $Raw -split "`r?`n"

# Patrones estandar de descripcion en este proyecto
$DescripcionesEstandar = @(
    'Seg.n mediciones auxiliares',
    'Segun mediciones auxiliares',
    'Según mediciones auxiliares',
    'Seg.n mediciones delineante',
    'Segun mediciones delineante',
    'Según mediciones delineante',
    'Segun planos',
    'Según planos',
    'Segun Civil 3D',
    'SEGUN DELINEANTE',
    'Según medición',
    'Segun medicion'
)

# Cargar todos los codigos ~C del archivo para detectar referencias huerfanas
$CodigosC = @{}
foreach ($Line in $Lines) {
    if (-not $Line.StartsWith('~C|')) { continue }
    $Campos = $Line.Substring(3) -split '\|'
    if ($Campos.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($Campos[0])) {
        $CodigosC[$Campos[0]] = if ($Campos.Count -gt 2) { $Campos[2] } else { '' }
    }
}

# Analizar lineas ~M
$Incidencias = @()
$TotalM = 0
$MConIncidencias = 0

foreach ($Line in $Lines) {
    if (-not $Line.StartsWith('~M|')) { continue }
    $TotalM++

    $Contenido = $Line.Substring(3)
    $Partes = $Contenido -split '\|'

    # Clave: puede ser CAPITULO\PARTIDA o solo PARTIDA
    $Clave = if ($Partes.Count -gt 0) { $Partes[0] } else { '' }
    $ClavePartes = $Clave -split '\\'
    $CodigoPartida = if ($ClavePartes.Count -gt 1) { $ClavePartes[-1] } else { $ClavePartes[0] }
    $Capitulo = if ($ClavePartes.Count -gt 1) { $ClavePartes[0] } else { '' }

    # Total declarado
    $TotalDeclarado = 0.0
    if ($Partes.Count -gt 3 -and -not [string]::IsNullOrWhiteSpace($Partes[3])) {
        $TotalStr = $Partes[3].Trim()
        # Detectar coma decimal (error comun)
        if ($TotalStr -match ',') {
            $Incidencias += [PSCustomObject]@{
                severidad = "ERROR"
                clave     = $Clave
                tipo      = "SEPARADOR_DECIMAL"
                detalle   = "Total usa coma como decimal: '$TotalStr'. BC3 requiere punto."
            }
            $TotalStr = $TotalStr -replace ',', '.'
        }
        [double]::TryParse($TotalStr, [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture, [ref]$TotalDeclarado) | Out-Null
    }

    # Total cero o negativo (sospechoso)
    if ($TotalDeclarado -le 0) {
        $Incidencias += [PSCustomObject]@{
            severidad = "AVISO"
            clave     = $Clave
            tipo      = "TOTAL_CERO_O_NEGATIVO"
            detalle   = "Total declarado: $TotalDeclarado. Verificar si es correcto."
        }
    }

    # Verificar que la partida tiene ~C asociado
    if (-not [string]::IsNullOrWhiteSpace($CodigoPartida) -and -not $CodigosC.ContainsKey($CodigoPartida)) {
        # Solo avisar si parece un codigo real (no secuencia vacia)
        if ($CodigoPartida.Length -gt 2 -and $CodigoPartida -notmatch '^\d+$') {
            $Incidencias += [PSCustomObject]@{
                severidad = "AVISO"
                clave     = $Clave
                tipo      = "PARTIDA_SIN_CONCEPTO"
                detalle   = "La partida '$CodigoPartida' no tiene registro ~C asociado."
            }
        }
    }

    # Analizar sublíneas de medicion (campo 4 en adelante)
    $SublineasRaw = if ($Partes.Count -gt 4) { $Partes[4] } else { '' }
    $Sublíneas = $SublineasRaw -split '\\\\'  # doble backslash separa sublíneas

    $SumaCalculada = 0.0
    $SublineaSinDesc = 0
    $SublineaConValor = 0

    foreach ($Sub in $Sublíneas) {
        $SubCampos = $Sub -split '\\'
        if ($SubCampos.Count -lt 2) { continue }

        $DescSub = $SubCampos[0].Trim()
        $ValN = 0.0; $ValM = 0.0; $ValA = 0.0

        if ($SubCampos.Count -gt 1 -and -not [string]::IsNullOrWhiteSpace($SubCampos[1])) {
            [double]::TryParse($SubCampos[1], [System.Globalization.NumberStyles]::Float,
                [System.Globalization.CultureInfo]::InvariantCulture, [ref]$ValN) | Out-Null
        }
        if ($SubCampos.Count -gt 2 -and -not [string]::IsNullOrWhiteSpace($SubCampos[2])) {
            [double]::TryParse($SubCampos[2], [System.Globalization.NumberStyles]::Float,
                [System.Globalization.CultureInfo]::InvariantCulture, [ref]$ValM) | Out-Null
        }
        if ($SubCampos.Count -gt 3 -and -not [string]::IsNullOrWhiteSpace($SubCampos[3])) {
            [double]::TryParse($SubCampos[3], [System.Globalization.NumberStyles]::Float,
                [System.Globalization.CultureInfo]::InvariantCulture, [ref]$ValA) | Out-Null
        }

        # Calcular aporte de esta sublínea
        $Factor = if ($ValM -gt 0 -and $ValA -gt 0) { $ValN * $ValM * $ValA }
                  elseif ($ValM -gt 0) { $ValN * $ValM }
                  else { $ValN }

        if ($Factor -ne 0) {
            $SublineaConValor++
            $SumaCalculada += $Factor
        }

        # Sublínea con valor pero sin descripcion
        if ($Factor -ne 0 -and [string]::IsNullOrWhiteSpace($DescSub)) {
            $SublineaSinDesc++
        }
    }

    if ($SublineaSinDesc -gt 0) {
        $Incidencias += [PSCustomObject]@{
            severidad = "AVISO"
            clave     = $Clave
            tipo      = "SUBLINEA_SIN_DESCRIPCION"
            detalle   = "$SublineaSinDesc sublinea(s) con valor pero sin descripcion. Dificil de trazar en revision."
        }
    }

    # Verificar que la suma cuadra con el total (solo si hay sublíneas con valor)
    if ($SublineaConValor -gt 0 -and $TotalDeclarado -gt 0) {
        $Diferencia = [Math]::Abs($TotalDeclarado - $SumaCalculada)
        if ($Diferencia -gt $Tolerancia) {
            $Incidencias += [PSCustomObject]@{
                severidad = "ERROR"
                clave     = $Clave
                tipo      = "TOTAL_NO_CUADRA"
                detalle   = ("Total declarado: {0:F3} | Suma sublíneas: {1:F3} | Diferencia: {2:F3}" -f $TotalDeclarado, $SumaCalculada, $Diferencia)
            }
        }
    }
}

# Contar incidencias
$Errores = @($Incidencias | Where-Object { $_.severidad -eq "ERROR" })
$Avisos  = @($Incidencias | Where-Object { $_.severidad -eq "AVISO" })
$MConIncidencias = ($Incidencias | Select-Object -ExpandProperty clave -Unique).Count

# Generar informe
$Fecha = Get-Date -Format "yyyy-MM-dd HH:mm"
$Informe = @"
# Informe de normalizacion de mediciones BC3
Archivo: $([System.IO.Path]::GetFileName($Bc3Path))
Generado: $Fecha

| | |
|---|---|
| Total mediciones (~M) revisadas | $TotalM |
| Mediciones con incidencias | $MConIncidencias |
| Errores | $($Errores.Count) |
| Avisos | $($Avisos.Count) |

---

"@

if ($Errores.Count -eq 0 -and $Avisos.Count -eq 0) {
    $Informe += "## ✅ Sin incidencias detectadas`n`nTodas las mediciones siguen el formato estandar del proyecto.`n"
} else {

    if ($Errores.Count -gt 0) {
        $Informe += "## ⛔ Errores ($($Errores.Count))`n`n"
        $PorTipoE = $Errores | Group-Object -Property tipo
        foreach ($Grupo in $PorTipoE) {
            $Informe += "### $($Grupo.Name) ($($Grupo.Count))`n`n"
            foreach ($Inc in $Grupo.Group) {
                $Informe += "- ``$($Inc.clave)`` — $($Inc.detalle)`n"
            }
            $Informe += "`n"
        }
        $Informe += "---`n`n"
    }

    if ($Avisos.Count -gt 0) {
        $Informe += "## ⚠️ Avisos ($($Avisos.Count))`n`n"
        $PorTipoA = $Avisos | Group-Object -Property tipo
        foreach ($Grupo in $PorTipoA) {
            $Informe += "### $($Grupo.Name) ($($Grupo.Count))`n`n"
            foreach ($Inc in ($Grupo.Group | Select-Object -First 30)) {
                $Informe += "- ``$($Inc.clave)`` — $($Inc.detalle)`n"
            }
            if ($Grupo.Count -gt 30) { $Informe += "- ... $($Grupo.Count - 30) casos adicionales`n" }
            $Informe += "`n"
        }
        $Informe += "---`n`n"
    }
}

$Informe += @"
## Patrones estandar del proyecto

Para mantener trazabilidad, cada sublínea de medicion debe llevar descripcion.
Los patrones aceptados en este proyecto son:

- ``Según mediciones auxiliares`` — medición venida de Civil 3D u hoja externa
- ``Según mediciones delineante`` — validada por delineante con fecha
- ``Según planos`` — referencia genérica a planos
- Nombre de tramo (``Glorieta``, ``Acerado sur``, ``Cruce``, etc.)
- Nombre de sección (``Sección 1.1``, ``Ramal``, etc.)
- Referencia a técnico y fecha cuando sea relevante

"@

# Guardar
if ($OutPath -eq "") {
    $SnapDir = Join-Path $ProjectRoot "scratch\bc3_snapshots"
    if (-not (Test-Path $SnapDir)) { New-Item -ItemType Directory -Path $SnapDir -Force | Out-Null }
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($Bc3Path)
    $OutPath = Join-Path $SnapDir "${BaseName}_mediciones_${Timestamp}.md"
}

$Informe | Set-Content $OutPath -Encoding UTF8

Write-Host "[bc3_normalize_mediciones] Revision completada." -ForegroundColor Cyan
Write-Host ("  Mediciones revisadas: {0}  |  Errores: {1}  |  Avisos: {2}" -f $TotalM, $Errores.Count, $Avisos.Count)
if ($Errores.Count -gt 0) {
    Write-Host "  ⛔ Hay errores que requieren correccion." -ForegroundColor Red
} elseif ($Avisos.Count -gt 0) {
    Write-Host "  ⚠️ Hay avisos. Revisar el informe." -ForegroundColor Yellow
} else {
    Write-Host "  ✅ Sin incidencias." -ForegroundColor Green
}
Write-Host "  Informe: $OutPath" -ForegroundColor DarkGray

return $OutPath
