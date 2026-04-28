param(
    [string]$Root = ""
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'civil3d_path_helpers.ps1')
. (Join-Path $PSScriptRoot 'xml_excel_helpers.ps1')

function Normalize-NodeName {
    param(
        [string]$Name,
        [string]$Network
    )

    $clean = ($Name -replace '<.*?>', '').Trim()
    if ($Network -eq 'PLUVIALES') {
        $clean = $clean -replace ' \(PLUVIALES\)$', ''
    }
    elseif ($Network -eq 'FECALES') {
        $clean = $clean -replace ' \(FECALES\)$', ''
    }
    $clean = $clean -replace '\s+', ' '
    return $clean.Trim()
}

function Parse-HtmlTableRows {
    param(
        [string]$Html,
        [string]$Marker,
        [string]$Pattern
    )

    $tableMatch = [regex]::Match($Html, $Marker, 'Singleline')
    if (-not $tableMatch.Success) {
        throw "No se pudo localizar la tabla para el patron: $Marker"
    }

    return [regex]::Matches($tableMatch.Groups['table'].Value, $Pattern, 'Singleline')
}

function Parse-Pipes {
    param(
        [string]$HtmlPath,
        [string]$Network
    )

    $html = Get-Content -LiteralPath $HtmlPath -Raw -Encoding UTF8
    $rows = Parse-HtmlTableRows `
        -Html $html `
        -Marker '<br>Pipes\s*<table.*?>(?<table>.*?)</table>' `
        -Pattern '<tr>\s*<td>(?<name>.*?)</td>\s*<td>(?<shape>.*?)</td>\s*<td>(?<size>.*?)</td>\s*<td>(?<mat>.*?)</td>\s*<td>(?<us>.*?)</td>\s*<td>(?<ds>.*?)</td>\s*<td>(?<usi>.*?)</td>\s*<td>(?<dsi>.*?)</td>\s*<td>(?<len>.*?)</td>'

    $items = New-Object System.Collections.Generic.List[object]
    foreach ($row in $rows) {
        $rawSize = ($row.Groups['size'].Value -replace '<.*?>', '').Trim()
        $rawUS = $row.Groups['us'].Value
        $rawDS = $row.Groups['ds'].Value
        $rawLen = ($row.Groups['len'].Value -replace '<.*?>', ' ').Trim()
        $parts = $rawLen -split '\s+'
        if ($parts.Count -lt 2) { continue }

        $sizeMm = [int][double]::Parse(($rawSize -replace '^D:', ''), [Globalization.CultureInfo]::InvariantCulture)
        $center = [double]::Parse($parts[0], [Globalization.CultureInfo]::InvariantCulture)
        $edge = [double]::Parse($parts[1], [Globalization.CultureInfo]::InvariantCulture)
        if ($Network -eq 'PLUVIALES' -and $sizeMm -eq 200) {
            $sizeMm = 250
        }

        $items.Add([pscustomobject]@{
            Network       = $Network
            PipeName      = Normalize-NodeName -Name $row.Groups['name'].Value -Network $Network
            RawStart      = Normalize-NodeName -Name $rawUS -Network $Network
            RawEnd        = Normalize-NodeName -Name $rawDS -Network $Network
            SizeMm        = $sizeMm
            LengthCenter  = $center
            LengthEdge    = $edge
        })
    }

    return $items
}

function Parse-Structures {
    param(
        [string]$HtmlPath,
        [string]$Network
    )

    $html = Get-Content -LiteralPath $HtmlPath -Raw -Encoding UTF8
    $rows = Parse-HtmlTableRows `
        -Html $html `
        -Marker 'Structures\s*<table.*?>(?<table>.*?)</table>' `
        -Pattern '<tr>\s*<td>(?<name>.*?)</td>'

    $list = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    foreach ($row in $rows) {
        $name = Normalize-NodeName -Name $row.Groups['name'].Value -Network $Network
        if (-not $seen.ContainsKey($name)) {
            $seen[$name] = $true
            $list.Add($name)
        }
    }

    return $list
}

function Build-AliasMap {
    param(
        [System.Collections.Generic.List[string]]$Structures,
        [string]$KeepPattern,
        [string]$AliasPrefix
    )

    $map = @{}
    $counter = 1
    foreach ($name in $Structures) {
        if ($name -match $KeepPattern) {
            $map[$name] = $name
        }
        else {
            $map[$name] = ('{0}{1:D2}' -f $AliasPrefix, $counter)
            $counter++
        }
    }

    return $map
}

function Write-NetworkOutputs {
    param(
        [string]$FolderPath,
        [string]$Prefix,
        [object[]]$PipeRows,
        [object[]]$StructureRows,
        [object[]]$SummaryRows
    )

    $workbookPath = Join-Path $FolderPath ("${Prefix}_Trazable.xls")
    $pipesCsvPath = Join-Path $FolderPath ("${Prefix}_Tuberias_Trazable.csv")
    $structuresCsvPath = Join-Path $FolderPath ("${Prefix}_Estructuras_Trazable.csv")
    $compatCsvPath = Join-Path $FolderPath ($Prefix -replace '_Trazable$', '')

    $compatWorkbookPath = Join-Path $FolderPath (($Prefix -replace '_Trazable$', '_Limpia') + '.xls')
    $compatPipesCsvPath = Join-Path $FolderPath (($Prefix -replace '_Trazable$', '_Limpia') + '.csv')
    $summaryMdPath = Join-Path $FolderPath ($Prefix + '.md')

    $PipeRows | Export-Csv -LiteralPath $pipesCsvPath -NoTypeInformation -Encoding UTF8
    $StructureRows | Export-Csv -LiteralPath $structuresCsvPath -NoTypeInformation -Encoding UTF8
    $PipeRows | Export-Csv -LiteralPath $compatPipesCsvPath -NoTypeInformation -Encoding UTF8

    Write-ExcelXmlWorkbook -Path $workbookPath -Sheets @(
        (New-ExcelObjectSheet 'Resumen' $SummaryRows),
        (New-ExcelObjectSheet 'Tuberias' $PipeRows),
        (New-ExcelObjectSheet 'Estructuras' $StructureRows)
    )
    Copy-Item -LiteralPath $workbookPath -Destination $compatWorkbookPath -Force

    $markdown = @"
# $Prefix

- Tuberias exportadas: $($PipeRows.Count)
- Estructuras exportadas: $($StructureRows.Count)
- Soportes generados:
  - $(Split-Path $workbookPath -Leaf)
  - $(Split-Path $pipesCsvPath -Leaf)
  - $(Split-Path $structuresCsvPath -Leaf)
"@
    [IO.File]::WriteAllText($summaryMdPath, $markdown, [Text.Encoding]::UTF8)
}

$projectRoot = Resolve-Civil3DProjectRoot -Root $Root
$pluvialesFolder = Resolve-Civil3DPluvialesFolder -Root $projectRoot
$fecalesFolder = Resolve-Civil3DFecalesFolder -Root $projectRoot

$pluvialesPath = if ($pluvialesFolder) { Resolve-Civil3DSourcePath -FolderPath $pluvialesFolder -FileName 'CivilReport.html' } else { $null }
$fecalesPath = if ($fecalesFolder) { Resolve-Civil3DSourcePath -FolderPath $fecalesFolder -FileName 'MEDICION FECALES.html' } else { $null }

if (-not $pluvialesPath -and -not $fecalesPath) {
    throw 'No se detectan informes Civil 3D de pluviales o fecales.'
}

if ($pluvialesPath) {
    $pluvialesPipes = Parse-Pipes -HtmlPath $pluvialesPath -Network 'PLUVIALES'
    $pluvialesStructures = Parse-Structures -HtmlPath $pluvialesPath -Network 'PLUVIALES'
    $pluvAliasMap = Build-AliasMap -Structures $pluvialesStructures -KeepPattern '^PP\d+$' -AliasPrefix 'IM'

    $pluvialesClean = foreach ($pipe in $pluvialesPipes) {
        $startAlias = $pluvAliasMap[$pipe.RawStart]
        $endAlias = $pluvAliasMap[$pipe.RawEnd]
        [pscustomobject]@{
            Red               = $pipe.Network
            CodigoPropuesto   = switch ($pipe.SizeMm) {
                250 { 'DN250' }
                400 { 'DN400' }
                500 { 'DN500' }
                630 { 'DN630' }
                default { 'REVISAR' }
            }
            Diametro_mm       = $pipe.SizeMm
            EstructuraInicial = $startAlias
            EstructuraFinal   = $endAlias
            Tramo             = "$startAlias-$endAlias"
            Longitud_m        = $pipe.LengthEdge
            NombreOriginal    = $pipe.PipeName
            NodoInicialRaw    = $pipe.RawStart
            NodoFinalRaw      = $pipe.RawEnd
        }
    }

    $pluvialesMapRows = foreach ($name in $pluvialesStructures) {
        [pscustomobject]@{
            NombreOriginal = $name
            AliasLimpio    = $pluvAliasMap[$name]
            Tipo           = if ($name -match '^PP\d+$') { 'Pozo' } else { 'Imbornal / estructura auxiliar' }
        }
    }

    $pluvialesSummary = @(
        [pscustomobject]@{ Concepto = 'Total tuberias pluviales (m)'; Valor = [math]::Round((($pluvialesClean | Measure-Object Longitud_m -Sum).Sum), 2); Nota = 'Longitud edge-to-edge' }
        [pscustomobject]@{ Concepto = 'DN250 pluviales (m)'; Valor = [math]::Round((($pluvialesClean | Where-Object CodigoPropuesto -eq 'DN250' | Measure-Object Longitud_m -Sum).Sum), 2); Nota = 'Incluye los DN200 tratados como DN250' }
        [pscustomobject]@{ Concepto = 'DN400 pluviales (m)'; Valor = [math]::Round((($pluvialesClean | Where-Object CodigoPropuesto -eq 'DN400' | Measure-Object Longitud_m -Sum).Sum), 2); Nota = '' }
        [pscustomobject]@{ Concepto = 'DN500 pluviales (m)'; Valor = [math]::Round((($pluvialesClean | Where-Object CodigoPropuesto -eq 'DN500' | Measure-Object Longitud_m -Sum).Sum), 2); Nota = '' }
        [pscustomobject]@{ Concepto = 'DN630 pluviales (m)'; Valor = [math]::Round((($pluvialesClean | Where-Object CodigoPropuesto -eq 'DN630' | Measure-Object Longitud_m -Sum).Sum), 2); Nota = '' }
        [pscustomobject]@{ Concepto = 'Estructuras no PPXX'; Valor = ($pluvialesMapRows | Where-Object AliasLimpio -like 'IM*').Count; Nota = 'Contrastar con tipologias del proyecto' }
    )

    Write-NetworkOutputs -FolderPath $pluvialesFolder -Prefix 'Red_Pluviales' -PipeRows $pluvialesClean -StructureRows $pluvialesMapRows -SummaryRows $pluvialesSummary
}

if ($fecalesPath) {
    $fecalesPipes = Parse-Pipes -HtmlPath $fecalesPath -Network 'FECALES'
    $fecalesStructures = Parse-Structures -HtmlPath $fecalesPath -Network 'FECALES'
    $fecAliasMap = Build-AliasMap -Structures $fecalesStructures -KeepPattern '^PF\d+$' -AliasPrefix 'IF'

    $fecalesClean = foreach ($pipe in $fecalesPipes) {
        $startAlias = $fecAliasMap[$pipe.RawStart]
        $endAlias = $fecAliasMap[$pipe.RawEnd]
        [pscustomobject]@{
            Red               = $pipe.Network
            CodigoPropuesto   = 'DN' + $pipe.SizeMm
            Diametro_mm       = $pipe.SizeMm
            EstructuraInicial = $startAlias
            EstructuraFinal   = $endAlias
            Tramo             = "$startAlias-$endAlias"
            Longitud_m        = $pipe.LengthEdge
            NombreOriginal    = $pipe.PipeName
            NodoInicialRaw    = $pipe.RawStart
            NodoFinalRaw      = $pipe.RawEnd
        }
    }

    $fecalesMapRows = foreach ($name in $fecalesStructures) {
        [pscustomobject]@{
            NombreOriginal = $name
            AliasLimpio    = $fecAliasMap[$name]
            Tipo           = if ($name -match '^PF\d+$') { 'Pozo fecales' } else { 'Estructura auxiliar' }
        }
    }

    $fecalesSummary = @(
        [pscustomobject]@{ Concepto = 'Total tuberias fecales (m)'; Valor = [math]::Round((($fecalesClean | Measure-Object Longitud_m -Sum).Sum), 2); Nota = 'Longitud edge-to-edge' }
        [pscustomobject]@{ Concepto = 'Pozos y estructuras'; Valor = $fecalesMapRows.Count; Nota = 'Contrastar con tipologias del proyecto' }
    )

    Write-NetworkOutputs -FolderPath $fecalesFolder -Prefix 'Red_Fecales' -PipeRows $fecalesClean -StructureRows $fecalesMapRows -SummaryRows $fecalesSummary
}

Write-Output 'OK - Mediciones de redes generadas desde Civil 3D.'
