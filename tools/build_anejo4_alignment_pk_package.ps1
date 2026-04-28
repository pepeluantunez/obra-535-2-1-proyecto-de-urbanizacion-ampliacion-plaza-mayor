param(
    [string]$Root = ""
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'civil3d_path_helpers.ps1')
. (Join-Path $PSScriptRoot 'xml_excel_helpers.ps1')

function Clean-HtmlText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $x = $Text -replace '<br\s*/?>', ' '
    $x = $x -replace '<.*?>', ''
    $x = [System.Net.WebUtility]::HtmlDecode($x)
    $x = $x -replace '&nbsp;', ' '
    return ($x -replace '\s+', ' ').Trim()
}

function Fix-Mojibake {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $x = $Text
    $x = $x -replace 'alineaci[^:<\s>]*n', 'alineacion'
    $x = $x -replace 'Alineaci[^:<\s>]*n', 'Alineacion'
    $x = $x -replace 'Descripci[^:<\s>]*n', 'Descripcion'
    $x = $x -replace 'Orientaci[^:<\s>]*n', 'Orientacion'
    return $x
}

function Convert-ToNullableNumber {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $x = $Value -replace 'm', '' -replace '\s+', ''
    $x = $x -replace ',', ''
    $number = 0.0
    if ([double]::TryParse($x, [Globalization.NumberStyles]::Any, [Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
        return [math]::Round($number, 4)
    }

    return $null
}

function Convert-PKToMeters {
    param([string]$PK)

    if ([string]::IsNullOrWhiteSpace($PK)) { return $null }
    if ($PK -match '^(?<k>\d+)\+(?<m>\d+(?:[.,]\d+)?)$') {
        $km = [double]$Matches['k'] * 1000.0
        $m = [double](($Matches['m']) -replace ',', '.')
        return [math]::Round(($km + $m), 3)
    }

    return $null
}

function Parse-AlignmentReport {
    param(
        [string]$Path,
        [ValidateSet('PI', 'INC')]
        [string]$Type
    )

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $txt = Fix-Mojibake $raw
    $blocks = [regex]::Split($txt, '<hr[^>]*>')

    $summary = @()
    $rows = @()

    foreach ($block in $blocks) {
        $nameMatch = [regex]::Match($block, 'Nombre de .*?:\s*(?<name>[^<\r\n]+)', [Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $nameMatch.Success) { continue }

        $intervalMatch = [regex]::Match($block, 'Intervalo de P\.K\.\:\s*inicio\:\s*(?<start>[^,]+),\s*fin\:\s*(?<end>[^<\r\n]+)', [Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $intervalMatch.Success) { continue }

        $tableMatch = [regex]::Match($block, '<table[^>]*>(?<table>.*?)</table>', [Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $tableMatch.Success) { continue }

        $name = Clean-HtmlText $nameMatch.Groups['name'].Value
        $pkStart = Clean-HtmlText $intervalMatch.Groups['start'].Value
        $pkEnd = Clean-HtmlText $intervalMatch.Groups['end'].Value
        $incrementMatch = [regex]::Match($block, 'Incremento de P\.K\.?\:?\s*(?<inc>[0-9\.,]+)', [Text.RegularExpressions.RegexOptions]::Singleline)
        $increment = if ($incrementMatch.Success) { Clean-HtmlText $incrementMatch.Groups['inc'].Value } else { '' }
        $startMeters = Convert-PKToMeters $pkStart
        $endMeters = Convert-PKToMeters $pkEnd
        $length = if ($startMeters -ne $null -and $endMeters -ne $null) { [math]::Round(($endMeters - $startMeters), 3) } else { $null }

        $summary += [pscustomobject]@{
            Tipo         = $Type
            Alineacion   = $name
            PK_Inicio    = $pkStart
            PK_Fin       = $pkEnd
            Longitud_m   = $length
            IncrementoPK = if ($increment) { [double](($increment) -replace ',', '.') } else { $null }
        }

        $rowIndex = 0
        foreach ($row in [regex]::Matches($tableMatch.Groups['table'].Value, '<tr[^>]*>(?<row>.*?)</tr>', [Text.RegularExpressions.RegexOptions]::Singleline)) {
            $rowIndex++
            $cells = [regex]::Matches($row.Groups['row'].Value, '<td[^>]*>(?<cell>.*?)</td>', [Text.RegularExpressions.RegexOptions]::Singleline)
            if ($cells.Count -eq 0) { continue }

            $values = @()
            foreach ($cell in $cells) {
                $values += (Clean-HtmlText $cell.Groups['cell'].Value)
            }

            if ($values[0] -match 'P\.K') { continue }

            if ($Type -eq 'PI') {
                $pk = $values[0]
                $rows += [pscustomobject]@{
                    Tipo        = 'PI'
                    Alineacion  = $name
                    PK          = $pk
                    PK_m        = Convert-PKToMeters $pk
                    Ordenada_m  = if ($values.Count -gt 1) { Convert-ToNullableNumber $values[1] } else { $null }
                    Abscisa_m   = if ($values.Count -gt 2) { Convert-ToNullableNumber $values[2] } else { $null }
                    Distancia_m = if ($values.Count -gt 3) { Convert-ToNullableNumber $values[3] } else { $null }
                    Orientacion = if ($values.Count -gt 4) { $values[4] } else { '' }
                    RowKind     = if ($pk) { 'Punto_PI' } else { 'Tramo_PI' }
                }
            }
            else {
                $pk = $values[0]
                $rows += [pscustomobject]@{
                    Tipo        = 'INCREMENTAL'
                    Alineacion  = $name
                    PK          = $pk
                    PK_m        = Convert-PKToMeters $pk
                    Ordenada_m  = if ($values.Count -gt 1) { Convert-ToNullableNumber $values[1] } else { $null }
                    Abscisa_m   = if ($values.Count -gt 2) { Convert-ToNullableNumber $values[2] } else { $null }
                    Distancia_m = $null
                    Orientacion = if ($values.Count -gt 3) { $values[3] } else { '' }
                    RowKind     = 'Punto_Incremental'
                }
            }
        }
    }

    return [pscustomobject]@{
        Summary = @($summary)
        Rows    = @($rows)
    }
}

$projectRoot = Resolve-Civil3DProjectRoot -Root $Root
$baseDir = Resolve-Civil3DAnejo4Folder -Root $projectRoot
if ([string]::IsNullOrWhiteSpace($baseDir)) {
    throw 'No se localiza la carpeta del Anejo 4 para Civil 3D.'
}

$piPath = Resolve-Civil3DSourcePath -FolderPath $baseDir -FileName 'Informe de P.K. de PI de alineaciones.html'
$incPath = Resolve-Civil3DSourcePath -FolderPath $baseDir -FileName 'Informe de P.K. incremental de alineaciones.html'
if (-not $piPath) { throw "No existe el informe fuente: Informe de P.K. de PI de alineaciones.html" }
if (-not $incPath) { throw "No existe el informe fuente: Informe de P.K. incremental de alineaciones.html" }

$pi = Parse-AlignmentReport -Path $piPath -Type 'PI'
$inc = Parse-AlignmentReport -Path $incPath -Type 'INC'

$summaryMap = @{}
foreach ($item in $pi.Summary) { $summaryMap[$item.Alineacion] = [ordered]@{ PI = $item; INC = $null } }
foreach ($item in $inc.Summary) {
    if (-not $summaryMap.ContainsKey($item.Alineacion)) {
        $summaryMap[$item.Alineacion] = [ordered]@{ PI = $null; INC = $item }
    }
    else {
        $summaryMap[$item.Alineacion].INC = $item
    }
}

$summaryRows = @()
foreach ($name in ($summaryMap.Keys | Sort-Object)) {
    $piSummary = $summaryMap[$name].PI
    $incSummary = $summaryMap[$name].INC
    $piLength = if ($piSummary) { $piSummary.Longitud_m } else { $null }
    $incLength = if ($incSummary) { $incSummary.Longitud_m } else { $null }
    $delta = if ($piLength -ne $null -and $incLength -ne $null) { [math]::Round(($incLength - $piLength), 3) } else { $null }
    $summaryRows += [pscustomobject]@{
        Alineacion              = $name
        PK_Inicio_PI            = if ($piSummary) { $piSummary.PK_Inicio } else { '' }
        PK_Fin_PI               = if ($piSummary) { $piSummary.PK_Fin } else { '' }
        Longitud_PI_m           = $piLength
        PK_Inicio_Incremental   = if ($incSummary) { $incSummary.PK_Inicio } else { '' }
        PK_Fin_Incremental      = if ($incSummary) { $incSummary.PK_Fin } else { '' }
        Longitud_Incremental_m  = $incLength
        Delta_m                 = $delta
        Estado                  = if ($delta -eq 0) { 'Coherente' } elseif ($delta -eq $null) { 'Pendiente validar' } else { 'Revisar' }
    }
}

$controlRows = @(
    [pscustomobject]@{ Bloque = 'Anejo 4'; Magnitud = 'PK de PI de alineaciones'; Estado = 'Confirmado'; Fuente = 'Informe de P.K. de PI de alineaciones.html'; Impacta = 'Replanteo; trazado; memoria de anejo'; Nota = 'No actualiza por si solo partidas BC3' }
    [pscustomobject]@{ Bloque = 'Anejo 4'; Magnitud = 'PK incremental de alineaciones'; Estado = 'Confirmado'; Fuente = 'Informe de P.K. incremental de alineaciones.html'; Impacta = 'Replanteo de campo; control geometrico'; Nota = 'No actualiza por si solo partidas BC3' }
    [pscustomobject]@{ Bloque = 'Proyecto'; Magnitud = 'Longitudes por eje'; Estado = 'Derivado'; Fuente = 'Comparativa PI vs Incremental'; Impacta = 'Coherencia de trazado'; Nota = 'Si hay delta, abrir revision de mediciones auxiliares' }
)

$piCsvPath = Join-Path $baseDir 'Anejo4_PK_PI_Alineaciones.csv'
$incCsvPath = Join-Path $baseDir 'Anejo4_PK_Incremental_Alineaciones.csv'
$workbookPath = Join-Path $baseDir 'Anejo4_PK_Alineaciones_Trazable.xls'
$markdownPath = Join-Path $baseDir 'Actualizacion_Anejo4_PK_Alineaciones.md'

$pi.Rows | Export-Csv -LiteralPath $piCsvPath -NoTypeInformation -Encoding UTF8
$inc.Rows | Export-Csv -LiteralPath $incCsvPath -NoTypeInformation -Encoding UTF8

Write-ExcelXmlWorkbook -Path $workbookPath -Sheets @(
    (New-ExcelObjectSheet '00_Resumen' $summaryRows),
    (New-ExcelObjectSheet '01_PI' $pi.Rows),
    (New-ExcelObjectSheet '02_Incremental' $inc.Rows),
    (New-ExcelObjectSheet '03_Control' $controlRows)
)

$names = ($summaryRows | ForEach-Object { $_.Alineacion }) -join ', '
$deltaValues = @($summaryRows | ForEach-Object { $_.Delta_m } | Where-Object { $null -ne $_ })
$maxDelta = if ($deltaValues.Count -gt 0) { ($deltaValues | Measure-Object -Maximum).Maximum } else { 0 }
$minDelta = if ($deltaValues.Count -gt 0) { ($deltaValues | Measure-Object -Minimum).Minimum } else { 0 }

$markdown = @"
# Actualizacion Anejo 4 - PK de alineaciones

- Fuentes integradas:
  - Informe de P.K. de PI de alineaciones.html
  - Informe de P.K. incremental de alineaciones.html
- Alineaciones procesadas: $($summaryRows.Count)
- Nombres de ejes: $names
- Delta longitud PI vs Incremental: min = $minDelta m, max = $maxDelta m

## Entregables

- Anejo4_PK_Alineaciones_Trazable.xls
- Anejo4_PK_PI_Alineaciones.csv
- Anejo4_PK_Incremental_Alineaciones.csv

## Criterio de impacto

- La informacion de PK se incorpora como base de trazado y replanteo del Anejo 4.
- No se trasladan cambios automaticamente al BC3 sin una magnitud de medicion derivada y defendible.
"@

[IO.File]::WriteAllText($markdownPath, $markdown, [Text.Encoding]::UTF8)
Write-Output "OK - Paquete de PK de alineaciones generado en: $baseDir"
