param(
    [string]$OutputDirectory = ".\DOCS - PLANTILLAS\Excel",
    [string]$ProjectName = "",
    [switch]$Overwrite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Resolve-AbsolutePath {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        return (Resolve-Path -LiteralPath $Path).Path
    }
    $combined = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path (Get-Location).Path $Path }
    [System.IO.Path]::GetFullPath($combined)
}

function Get-ProjectDisplayName {
    param([string]$ExplicitName)
    if (-not [string]::IsNullOrWhiteSpace($ExplicitName)) {
        return $ExplicitName.Trim()
    }
    $leaf = Split-Path -Path (Get-Location).Path -Leaf
    ($leaf -replace '^\d+(?:\.\d+)*\s*-\s*', '').Trim()
}

function Import-JsonIfExists {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Escape-XmlText {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    [System.Security.SecurityElement]::Escape([string]$Text)
}

function Get-ColumnName {
    param([int]$ColumnNumber)
    $name = ""
    $n = $ColumnNumber
    while ($n -gt 0) {
        $remainder = ($n - 1) % 26
        $name = [char](65 + $remainder) + $name
        $n = [math]::Floor(($n - 1) / 26)
    }
    $name
}

function New-TextCell {
    param(
        [int]$Col,
        [string]$Text,
        [int]$Style = 1
    )
    [pscustomobject]@{
        Col = $Col
        Kind = "inline"
        Text = $Text
        Style = $Style
    }
}

function New-NumberCell {
    param(
        [int]$Col,
        [string]$Value,
        [int]$Style = 5
    )
    [pscustomobject]@{
        Col = $Col
        Kind = "number"
        Value = $Value
        Style = $Style
    }
}

function New-FormulaCell {
    param(
        [int]$Col,
        [string]$Formula,
        [string]$Value = "0",
        [int]$Style = 6
    )
    [pscustomobject]@{
        Col = $Col
        Kind = "formula"
        Formula = $Formula
        Value = $Value
        Style = $Style
    }
}

function New-Row {
    param(
        [int]$Index,
        [object[]]$Cells
    )
    [pscustomobject]@{
        Index = $Index
        Cells = [object[]]$Cells
    }
}

function Convert-CellToXml {
    param(
        [int]$RowIndex,
        $Cell
    )

    $reference = "$(Get-ColumnName -ColumnNumber $Cell.Col)$RowIndex"
    switch ($Cell.Kind) {
        "inline" {
            return "<c r=""$reference"" t=""inlineStr"" s=""$($Cell.Style)""><is><t xml:space=""preserve"">$(Escape-XmlText -Text $Cell.Text)</t></is></c>"
        }
        "number" {
            return "<c r=""$reference"" s=""$($Cell.Style)""><v>$(Escape-XmlText -Text $Cell.Value)</v></c>"
        }
        "formula" {
            return "<c r=""$reference"" s=""$($Cell.Style)""><f>$(Escape-XmlText -Text $Cell.Formula)</f><v>$(Escape-XmlText -Text $Cell.Value)</v></c>"
        }
        default {
            throw "Tipo de celda no soportado: $($Cell.Kind)"
        }
    }
}

function Convert-RowToXml {
    param($Row)
    $cellsXml = foreach ($cell in ($Row.Cells | Sort-Object Col)) {
        Convert-CellToXml -RowIndex $Row.Index -Cell $cell
    }
    "<row r=""$($Row.Index)"">$($cellsXml -join '')</row>"
}

function Get-ColumnsXml {
    param([double[]]$Widths)
    if (-not $Widths -or $Widths.Count -eq 0) { return "" }
    $cols = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $Widths.Count; $i++) {
        $widthValue = ([string]$Widths[$i]).Replace(',', '.')
        [void]$cols.Add("<col min=""$($i + 1)"" max=""$($i + 1)"" width=""$widthValue"" customWidth=""1""/>")
    }
    "<cols>$($cols -join '')</cols>"
}

function Get-StylesXml {
@'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <numFmts count="1">
    <numFmt numFmtId="164" formatCode="0.00"/>
  </numFmts>
  <fonts count="4">
    <font>
      <sz val="11"/>
      <color theme="1"/>
      <name val="Calibri"/>
      <family val="2"/>
      <scheme val="minor"/>
    </font>
    <font>
      <sz val="10"/>
      <name val="Montserrat"/>
      <family val="2"/>
    </font>
    <font>
      <b/>
      <sz val="16"/>
      <name val="Montserrat"/>
      <family val="2"/>
      <color rgb="FF1F1F1F"/>
    </font>
    <font>
      <b/>
      <sz val="10"/>
      <name val="Montserrat"/>
      <family val="2"/>
      <color rgb="FFFFFFFF"/>
    </font>
  </fonts>
  <fills count="5">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFF0C59A"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFF8E9D8"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF355C7D"/><bgColor indexed="64"/></patternFill></fill>
  </fills>
  <borders count="2">
    <border><left/><right/><top/><bottom/><diagonal/></border>
    <border>
      <left style="thin"><color auto="1"/></left>
      <right style="thin"><color auto="1"/></right>
      <top style="thin"><color auto="1"/></top>
      <bottom style="thin"><color auto="1"/></bottom>
      <diagonal/>
    </border>
  </borders>
  <cellStyleXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
  </cellStyleXfs>
  <cellXfs count="7">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="1" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1"><alignment vertical="center" wrapText="1"/></xf>
    <xf numFmtId="0" fontId="2" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
    <xf numFmtId="0" fontId="1" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
    <xf numFmtId="0" fontId="3" fillId="4" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>
    <xf numFmtId="164" fontId="1" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyNumberFormat="1" applyAlignment="1"><alignment vertical="center"/></xf>
    <xf numFmtId="0" fontId="1" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
  </cellXfs>
  <cellStyles count="1">
    <cellStyle name="Normal" xfId="0" builtinId="0"/>
  </cellStyles>
</styleSheet>
'@
}

function Get-WorksheetXml {
    param($Sheet)

    $rows = @($Sheet.Rows | Sort-Object Index)
    $lastRow = if ($rows.Count -gt 0) { ($rows[-1]).Index } else { 1 }
    $lastCol = if ($Sheet.LastColumn -gt 0) { $Sheet.LastColumn } else { 1 }
    $dimension = "A1:$(Get-ColumnName -ColumnNumber $lastCol)$lastRow"
    $rowsXml = $rows | ForEach-Object { Convert-RowToXml -Row $_ }
    if ($Sheet.FreezeTopRow -gt 0) {
        $topLeft = "A$($Sheet.FreezeTopRow + 1)"
        $freezeXml = "<sheetViews><sheetView workbookViewId=""0""><pane ySplit=""$($Sheet.FreezeTopRow)"" topLeftCell=""$topLeft"" activePane=""bottomLeft"" state=""frozen""/><selection pane=""bottomLeft"" activeCell=""$topLeft"" sqref=""$topLeft""/></sheetView></sheetViews>"
    } else {
        $freezeXml = '<sheetViews><sheetView workbookViewId="0"/></sheetViews>'
    }

    [object[]]$mergeRefs = @($Sheet.MergeRefs)
    if ($mergeRefs.Count -gt 0) {
        $mergeItems = $mergeRefs | ForEach-Object { "<mergeCell ref=""$_""/>" }
        $mergeXml = "<mergeCells count=""$($mergeRefs.Count)"">$($mergeItems -join '')</mergeCells>"
    } else {
        $mergeXml = ""
    }

    $autoFilterXml = if ([string]::IsNullOrWhiteSpace([string]$Sheet.AutoFilterRef)) { "" } else { "<autoFilter ref=""$($Sheet.AutoFilterRef)""/>" }
    $columnsXml = Get-ColumnsXml -Widths ([double[]]$Sheet.Widths)

@"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <dimension ref="$dimension"/>
  $freezeXml
  $columnsXml
  <sheetFormatPr defaultRowHeight="15"/>
  <sheetData>$($rowsXml -join "")</sheetData>
  $autoFilterXml
  $mergeXml
  <pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>
</worksheet>
"@
}

function Write-ZipEntryText {
    param(
        [System.IO.Compression.ZipArchive]$Zip,
        [string]$EntryName,
        [string]$Content
    )
    $entry = $Zip.CreateEntry($EntryName, [System.IO.Compression.CompressionLevel]::Optimal)
    $stream = $entry.Open()
    try {
        $writer = New-Object System.IO.StreamWriter($stream, (New-Object System.Text.UTF8Encoding($false)))
        $writer.Write($Content)
        $writer.Flush()
    } finally {
        if ($writer) { $writer.Dispose() }
        if ($stream) { $stream.Dispose() }
    }
}

function New-XlsxPackage {
    param(
        [string]$Path,
        [string]$ProjectDisplayName,
        [object[]]$Sheets
    )

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force
    }

    $fileStream = [System.IO.File]::Open($Path, [System.IO.FileMode]::CreateNew)
    $zip = $null
    try {
        $zip = New-Object System.IO.Compression.ZipArchive($fileStream, [System.IO.Compression.ZipArchiveMode]::Create, $false)

        $sheetOverrides = New-Object System.Collections.Generic.List[string]
        $sheetRefs = New-Object System.Collections.Generic.List[string]
        $sheetDefs = New-Object System.Collections.Generic.List[string]
        for ($i = 0; $i -lt $Sheets.Count; $i++) {
            $sheetNumber = $i + 1
            $sheetPath = "/xl/worksheets/sheet$sheetNumber.xml"
            [void]$sheetOverrides.Add("<Override PartName=""$sheetPath"" ContentType=""application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml""/>")
            [void]$sheetRefs.Add("<Relationship Id=""rId$sheetNumber"" Type=""http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"" Target=""worksheets/sheet$sheetNumber.xml""/>")
            [void]$sheetDefs.Add("<sheet name=""$(Escape-XmlText -Text $Sheets[$i].Name)"" sheetId=""$sheetNumber"" r:id=""rId$sheetNumber""/>")
            Write-ZipEntryText -Zip $zip -EntryName "xl/worksheets/sheet$sheetNumber.xml" -Content (Get-WorksheetXml -Sheet $Sheets[$i])
        }

        $contentTypes = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
  $($sheetOverrides -join "`n  ")
</Types>
"@

        $rootRels = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
'@

        $workbookXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <bookViews>
    <workbookView xWindow="0" yWindow="0" windowWidth="24000" windowHeight="12000"/>
  </bookViews>
  <sheets>
    $($sheetDefs -join "`n    ")
  </sheets>
  <calcPr calcId="191029" fullCalcOnLoad="1" forceFullCalc="1"/>
</workbook>
"@

        $workbookRels = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  $($sheetRefs -join "`n  ")
  <Relationship Id="rId$($Sheets.Count + 1)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
"@

        $now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
        $coreXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>$(Escape-XmlText -Text $ProjectDisplayName)</dc:title>
  <dc:creator>Codex</dc:creator>
  <cp:lastModifiedBy>Codex</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">$now</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">$now</dcterms:modified>
</cp:coreProperties>
"@

        $partNames = $Sheets | ForEach-Object { "<vt:lpstr>$(Escape-XmlText -Text $_.Name)</vt:lpstr>" }
        $appXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Microsoft Excel</Application>
  <DocSecurity>0</DocSecurity>
  <ScaleCrop>false</ScaleCrop>
  <HeadingPairs>
    <vt:vector size="2" baseType="variant">
      <vt:variant><vt:lpstr>Worksheets</vt:lpstr></vt:variant>
      <vt:variant><vt:i4>$($Sheets.Count)</vt:i4></vt:variant>
    </vt:vector>
  </HeadingPairs>
  <TitlesOfParts>
    <vt:vector size="$($Sheets.Count)" baseType="lpstr">
      $($partNames -join "`n      ")
    </vt:vector>
  </TitlesOfParts>
  <Company></Company>
  <LinksUpToDate>false</LinksUpToDate>
  <SharedDoc>false</SharedDoc>
  <HyperlinksChanged>false</HyperlinksChanged>
  <AppVersion>16.0300</AppVersion>
</Properties>
"@

        Write-ZipEntryText -Zip $zip -EntryName "[Content_Types].xml" -Content $contentTypes
        Write-ZipEntryText -Zip $zip -EntryName "_rels/.rels" -Content $rootRels
        Write-ZipEntryText -Zip $zip -EntryName "xl/workbook.xml" -Content $workbookXml
        Write-ZipEntryText -Zip $zip -EntryName "xl/_rels/workbook.xml.rels" -Content $workbookRels
        Write-ZipEntryText -Zip $zip -EntryName "xl/styles.xml" -Content (Get-StylesXml)
        Write-ZipEntryText -Zip $zip -EntryName "docProps/core.xml" -Content $coreXml
        Write-ZipEntryText -Zip $zip -EntryName "docProps/app.xml" -Content $appXml
    } finally {
        if ($zip) { $zip.Dispose() }
        $fileStream.Dispose()
    }
}

function Get-AnnexStatusRows {
    param([string]$RootPath)

    $csvPath = Join-Path $RootPath "CONTROL\matriz_estado_anejos.csv"
    if (Test-Path -LiteralPath $csvPath) {
        return [object[]]@(Import-Csv -LiteralPath $csvPath)
    }

    $annexRoot = Join-Path $RootPath "DOCS - ANEJOS"
    if (-not (Test-Path -LiteralPath $annexRoot)) { return @() }
    return [object[]]@(
        Get-ChildItem -LiteralPath $annexRoot -Directory |
            Where-Object { $_.Name -match '^\d+\.-' } |
            Sort-Object { [int](($_.Name -split '\.-', 2)[0]) } |
            ForEach-Object {
                $parts = $_.Name -split '\.-', 2
                [pscustomobject]@{
                    numero = $parts[0]
                    anejo = if ($parts.Count -gt 1) { $parts[1].Trim() } else { $_.Name }
                    estado = "Pendiente de revisar"
                    tiene_objeto = ""
                    tiene_antecedentes = ""
                    tiene_normativa = ""
                    marcadores_pendientes = ""
                }
            }
    )
}

function New-SheetDefinition {
    param(
        [string]$Name,
        [int]$LastColumn,
        [double[]]$Widths,
        [int]$FreezeTopRow,
        [string]$AutoFilterRef,
        [object[]]$Rows,
        [string[]]$MergeRefs = @()
    )
    [pscustomobject]@{
        Name = $Name
        LastColumn = $LastColumn
        Widths = [double[]]$Widths
        FreezeTopRow = $FreezeTopRow
        AutoFilterRef = $AutoFilterRef
        Rows = [object[]]$Rows
        MergeRefs = [string[]]$MergeRefs
    }
}

function New-ControlDocumentalWorkbookSheets {
    param(
        [string]$ProjectDisplayName,
        [object[]]$StatusRows
    )

    $rowsStatus = New-Object System.Collections.Generic.List[object]
    [void]$rowsStatus.Add((New-Row -Index 1 -Cells @(New-TextCell -Col 1 -Text "Indice de control documental" -Style 2)))
    [void]$rowsStatus.Add((New-Row -Index 2 -Cells @(New-TextCell -Col 1 -Text $ProjectDisplayName -Style 3)))
    [void]$rowsStatus.Add((New-Row -Index 4 -Cells @(
        (New-TextCell -Col 1 -Text "N" -Style 4),
        (New-TextCell -Col 2 -Text "Anejo" -Style 4),
        (New-TextCell -Col 3 -Text "Estado" -Style 4),
        (New-TextCell -Col 4 -Text "Objeto" -Style 4),
        (New-TextCell -Col 5 -Text "Antecedentes" -Style 4),
        (New-TextCell -Col 6 -Text "Normativa" -Style 4),
        (New-TextCell -Col 7 -Text "Pendientes" -Style 4),
        (New-TextCell -Col 8 -Text "Fuente principal" -Style 4),
        (New-TextCell -Col 9 -Text "Observaciones" -Style 4)
    )))
    $rowIndex = 5
    foreach ($row in $StatusRows) {
        [void]$rowsStatus.Add((New-Row -Index $rowIndex -Cells @(
            (New-TextCell -Col 1 -Text ([string]$row.numero)),
            (New-TextCell -Col 2 -Text ([string]$row.anejo)),
            (New-TextCell -Col 3 -Text ([string]$row.estado)),
            (New-TextCell -Col 4 -Text ([string]$row.tiene_objeto)),
            (New-TextCell -Col 5 -Text ([string]$row.tiene_antecedentes)),
            (New-TextCell -Col 6 -Text ([string]$row.tiene_normativa)),
            (New-NumberCell -Col 7 -Value ($(if ([string]::IsNullOrWhiteSpace([string]$row.marcadores_pendientes)) { "0" } else { [string]$row.marcadores_pendientes })) -Style 6)
        )))
        $rowIndex++
    }
    if ($rowIndex -eq 5) { $rowIndex = 6 }

    $rowsSummary = @(
        (New-Row -Index 1 -Cells @(New-TextCell -Col 1 -Text "Resumen documental" -Style 2)),
        (New-Row -Index 2 -Cells @(New-TextCell -Col 1 -Text $ProjectDisplayName -Style 3)),
        (New-Row -Index 4 -Cells @(
            (New-TextCell -Col 1 -Text "Indicador" -Style 4),
            (New-TextCell -Col 2 -Text "Valor" -Style 4)
        )),
        (New-Row -Index 5 -Cells @(
            (New-TextCell -Col 1 -Text "Anejos con base util"),
            (New-FormulaCell -Col 2 -Formula 'COUNTIF(Estado_anejos!C5:C200,"Base util preparada")+COUNTIF(Estado_anejos!C5:C200,"Arranque completado")')
        )),
        (New-Row -Index 6 -Cells @(
            (New-TextCell -Col 1 -Text "Anejos en plantilla cruda"),
            (New-FormulaCell -Col 2 -Formula 'COUNTIF(Estado_anejos!C5:C200,"Plantilla cruda")')
        )),
        (New-Row -Index 7 -Cells @(
            (New-TextCell -Col 1 -Text "Pendientes totales"),
            (New-FormulaCell -Col 2 -Formula 'SUM(Estado_anejos!G5:G200)')
        )),
        (New-Row -Index 8 -Cells @(
            (New-TextCell -Col 1 -Text "Anejos detectados"),
            (New-FormulaCell -Col 2 -Formula 'COUNTA(Estado_anejos!A5:A200)')
        ))
    )

    @(
        (New-SheetDefinition -Name "Estado_anejos" -LastColumn 9 -Widths @(8, 34, 22, 12, 16, 14, 12, 24, 28) -FreezeTopRow 4 -AutoFilterRef "A4:I4" -Rows ([object[]]$rowsStatus) -MergeRefs @("A1:I1", "A2:I2")),
        (New-SheetDefinition -Name "Resumen" -LastColumn 2 -Widths @(32, 16) -FreezeTopRow 0 -AutoFilterRef "" -Rows ([object[]]$rowsSummary) -MergeRefs @("A1:B1", "A2:B2"))
    )
}

function New-FichaProyectoWorkbookSheets {
    param(
        [string]$ProjectDisplayName,
        $Config
    )

    [object[]]$sources = @($Config.known_sources)
    $rowsFicha = New-Object System.Collections.Generic.List[object]
    [void]$rowsFicha.Add((New-Row -Index 1 -Cells @(New-TextCell -Col 1 -Text "Ficha del proyecto" -Style 2)))
    [void]$rowsFicha.Add((New-Row -Index 2 -Cells @(New-TextCell -Col 1 -Text $ProjectDisplayName -Style 3)))
    [void]$rowsFicha.Add((New-Row -Index 4 -Cells @(
        (New-TextCell -Col 1 -Text "Campo" -Style 4),
        (New-TextCell -Col 2 -Text "Valor" -Style 4)
    )))

    $fields = @(
        @{ Key = "Nombre del proyecto"; Value = $ProjectDisplayName },
        @{ Key = "Nombre corto"; Value = [string]$Config.short_name },
        @{ Key = "Municipio"; Value = [string]$Config.municipality },
        @{ Key = "Provincia"; Value = [string]$Config.province },
        @{ Key = "Cliente"; Value = [string]$Config.client },
        @{ Key = "Promotor"; Value = [string]$Config.promoter },
        @{ Key = "Documento de memoria"; Value = [string]$Config.memory_filename }
    )
    $rowIndex = 5
    foreach ($field in $fields) {
        [void]$rowsFicha.Add((New-Row -Index $rowIndex -Cells @(
            (New-TextCell -Col 1 -Text $field.Key),
            (New-TextCell -Col 2 -Text $field.Value)
        )))
        $rowIndex++
    }

    $rowsFuentes = New-Object System.Collections.Generic.List[object]
    [void]$rowsFuentes.Add((New-Row -Index 1 -Cells @(New-TextCell -Col 1 -Text "Inventario de fuentes" -Style 2)))
    [void]$rowsFuentes.Add((New-Row -Index 2 -Cells @(New-TextCell -Col 1 -Text $ProjectDisplayName -Style 3)))
    [void]$rowsFuentes.Add((New-Row -Index 4 -Cells @(
        (New-TextCell -Col 1 -Text "Tipo" -Style 4),
        (New-TextCell -Col 2 -Text "Ruta" -Style 4),
        (New-TextCell -Col 3 -Text "Uso previsto" -Style 4),
        (New-TextCell -Col 4 -Text "Observaciones" -Style 4)
    )))
    $rowIndex = 5
    foreach ($source in $sources) {
        [void]$rowsFuentes.Add((New-Row -Index $rowIndex -Cells @(
            (New-TextCell -Col 1 -Text ([string]$source.type)),
            (New-TextCell -Col 2 -Text ([string]$source.path)),
            (New-TextCell -Col 4 -Text ([string]$source.notes))
        )))
        $rowIndex++
    }
    if ($rowIndex -eq 5) { [void]$rowsFuentes.Add((New-Row -Index 5 -Cells @())) }

    $rowsDecisiones = @(
        (New-Row -Index 1 -Cells @(New-TextCell -Col 1 -Text "Registro de decisiones" -Style 2)),
        (New-Row -Index 2 -Cells @(New-TextCell -Col 1 -Text $ProjectDisplayName -Style 3)),
        (New-Row -Index 4 -Cells @(
            (New-TextCell -Col 1 -Text "Fecha" -Style 4),
            (New-TextCell -Col 2 -Text "Decision" -Style 4),
            (New-TextCell -Col 3 -Text "Fundamento" -Style 4),
            (New-TextCell -Col 4 -Text "Impacto documental" -Style 4),
            (New-TextCell -Col 5 -Text "Pendiente asociado" -Style 4)
        ))
    )
    for ($i = 5; $i -le 15; $i++) {
        $rowsDecisiones += New-Row -Index $i -Cells @()
    }

    @(
        (New-SheetDefinition -Name "Ficha_proyecto" -LastColumn 2 -Widths @(28, 48) -FreezeTopRow 0 -AutoFilterRef "" -Rows ([object[]]$rowsFicha) -MergeRefs @("A1:B1", "A2:B2")),
        (New-SheetDefinition -Name "Fuentes" -LastColumn 4 -Widths @(14, 52, 24, 30) -FreezeTopRow 4 -AutoFilterRef "A4:D4" -Rows ([object[]]$rowsFuentes) -MergeRefs @("A1:D1", "A2:D2")),
        (New-SheetDefinition -Name "Decisiones" -LastColumn 5 -Widths @(14, 34, 34, 28, 24) -FreezeTopRow 4 -AutoFilterRef "A4:E4" -Rows ([object[]]$rowsDecisiones) -MergeRefs @("A1:E1", "A2:E2"))
    )
}

function New-MedicionesWorkbookSheets {
    param([string]$ProjectDisplayName)

    $rowsMed = New-Object System.Collections.Generic.List[object]
    [void]$rowsMed.Add((New-Row -Index 1 -Cells @(New-TextCell -Col 1 -Text "Mediciones auxiliares" -Style 2)))
    [void]$rowsMed.Add((New-Row -Index 2 -Cells @(New-TextCell -Col 1 -Text $ProjectDisplayName -Style 3)))
    [void]$rowsMed.Add((New-Row -Index 4 -Cells @(
        (New-TextCell -Col 1 -Text "Codigo" -Style 4),
        (New-TextCell -Col 2 -Text "Capitulo" -Style 4),
        (New-TextCell -Col 3 -Text "Descripcion" -Style 4),
        (New-TextCell -Col 4 -Text "Unidad" -Style 4),
        (New-TextCell -Col 5 -Text "Longitud" -Style 4),
        (New-TextCell -Col 6 -Text "Anchura" -Style 4),
        (New-TextCell -Col 7 -Text "Espesor" -Style 4),
        (New-TextCell -Col 8 -Text "Factor" -Style 4),
        (New-TextCell -Col 9 -Text "Cantidad" -Style 4),
        (New-TextCell -Col 10 -Text "Observaciones" -Style 4)
    )))
    for ($rowIndex = 5; $rowIndex -le 40; $rowIndex++) {
        [void]$rowsMed.Add((New-Row -Index $rowIndex -Cells @(
            (New-FormulaCell -Col 9 -Formula "IFERROR(E$rowIndex*F$rowIndex*G$rowIndex*H$rowIndex,0)" -Style 5)
        )))
    }

    $rowsRes = @(
        (New-Row -Index 1 -Cells @(New-TextCell -Col 1 -Text "Resumen de mediciones" -Style 2)),
        (New-Row -Index 2 -Cells @(New-TextCell -Col 1 -Text $ProjectDisplayName -Style 3)),
        (New-Row -Index 4 -Cells @(
            (New-TextCell -Col 1 -Text "Capitulo" -Style 4),
            (New-TextCell -Col 2 -Text "Cantidad total" -Style 4),
            (New-TextCell -Col 3 -Text "Observaciones" -Style 4)
        ))
    )
    for ($rowIndex = 5; $rowIndex -le 15; $rowIndex++) {
        $rowsRes += New-Row -Index $rowIndex -Cells @(
            (New-FormulaCell -Col 2 -Formula "SUMIF(Mediciones!B:B,A$rowIndex,Mediciones!I:I)" -Style 5)
        )
    }

    @(
        (New-SheetDefinition -Name "Mediciones" -LastColumn 10 -Widths @(14, 16, 34, 12, 12, 12, 12, 12, 14, 24) -FreezeTopRow 4 -AutoFilterRef "A4:J4" -Rows ([object[]]$rowsMed) -MergeRefs @("A1:J1", "A2:J2")),
        (New-SheetDefinition -Name "Resumen" -LastColumn 3 -Widths @(22, 18, 26) -FreezeTopRow 0 -AutoFilterRef "" -Rows ([object[]]$rowsRes) -MergeRefs @("A1:C1", "A2:C2"))
    )
}

function New-TrazabilidadWorkbookSheets {
    param([string]$ProjectDisplayName)

    $rowsTrace = @(
        (New-Row -Index 1 -Cells @(New-TextCell -Col 1 -Text "Matriz de trazabilidad" -Style 2)),
        (New-Row -Index 2 -Cells @(New-TextCell -Col 1 -Text $ProjectDisplayName -Style 3)),
        (New-Row -Index 4 -Cells @(
            (New-TextCell -Col 1 -Text "Concepto" -Style 4),
            (New-TextCell -Col 2 -Text "Fuente" -Style 4),
            (New-TextCell -Col 3 -Text "Documento" -Style 4),
            (New-TextCell -Col 4 -Text "Tabla o epigrafe" -Style 4),
            (New-TextCell -Col 5 -Text "Medicion" -Style 4),
            (New-TextCell -Col 6 -Text "BC3" -Style 4),
            (New-TextCell -Col 7 -Text "Estado" -Style 4),
            (New-TextCell -Col 8 -Text "Observaciones" -Style 4)
        ))
    )
    for ($rowIndex = 5; $rowIndex -le 35; $rowIndex++) {
        $rowsTrace += New-Row -Index $rowIndex -Cells @()
    }

    $rowsCatalog = @(
        (New-Row -Index 1 -Cells @(New-TextCell -Col 1 -Text "Catalogos auxiliares" -Style 2)),
        (New-Row -Index 2 -Cells @(New-TextCell -Col 1 -Text $ProjectDisplayName -Style 3)),
        (New-Row -Index 4 -Cells @((New-TextCell -Col 1 -Text "Estados sugeridos" -Style 4))),
        (New-Row -Index 5 -Cells @((New-TextCell -Col 1 -Text "Pendiente"))),
        (New-Row -Index 6 -Cells @((New-TextCell -Col 1 -Text "En curso"))),
        (New-Row -Index 7 -Cells @((New-TextCell -Col 1 -Text "Trazado"))),
        (New-Row -Index 8 -Cells @((New-TextCell -Col 1 -Text "Cerrado")))
    )

    $rowsControl = @(
        (New-Row -Index 1 -Cells @(New-TextCell -Col 1 -Text "Control de cobertura" -Style 2)),
        (New-Row -Index 2 -Cells @(New-TextCell -Col 1 -Text $ProjectDisplayName -Style 3)),
        (New-Row -Index 4 -Cells @(
            (New-TextCell -Col 1 -Text "Indicador" -Style 4),
            (New-TextCell -Col 2 -Text "Valor" -Style 4)
        )),
        (New-Row -Index 5 -Cells @(
            (New-TextCell -Col 1 -Text "Conceptos totales"),
            (New-FormulaCell -Col 2 -Formula 'COUNTA(Trazabilidad!A5:A200)')
        )),
        (New-Row -Index 6 -Cells @(
            (New-TextCell -Col 1 -Text "Conceptos cerrados"),
            (New-FormulaCell -Col 2 -Formula 'COUNTIF(Trazabilidad!G5:G200,"Cerrado")')
        )),
        (New-Row -Index 7 -Cells @(
            (New-TextCell -Col 1 -Text "Conceptos pendientes"),
            (New-FormulaCell -Col 2 -Formula 'COUNTIF(Trazabilidad!G5:G200,"Pendiente")')
        ))
    )

    @(
        (New-SheetDefinition -Name "Trazabilidad" -LastColumn 8 -Widths @(22, 18, 22, 20, 14, 14, 16, 24) -FreezeTopRow 4 -AutoFilterRef "A4:H4" -Rows ([object[]]$rowsTrace) -MergeRefs @("A1:H1", "A2:H2")),
        (New-SheetDefinition -Name "Catalogos" -LastColumn 1 -Widths @(22) -FreezeTopRow 0 -AutoFilterRef "" -Rows ([object[]]$rowsCatalog) -MergeRefs @("A1:A1", "A2:A2")),
        (New-SheetDefinition -Name "Control" -LastColumn 2 -Widths @(26, 16) -FreezeTopRow 0 -AutoFilterRef "" -Rows ([object[]]$rowsControl) -MergeRefs @("A1:B1", "A2:B2"))
    )
}

function New-NormativaWorkbookSheets {
    param(
        [string]$ProjectDisplayName,
        $Config
    )

    [object[]]$norms = @($Config.base_normativa)
    $rowsNorm = New-Object System.Collections.Generic.List[object]
    [void]$rowsNorm.Add((New-Row -Index 1 -Cells @(New-TextCell -Col 1 -Text "Control normativa" -Style 2)))
    [void]$rowsNorm.Add((New-Row -Index 2 -Cells @(New-TextCell -Col 1 -Text $ProjectDisplayName -Style 3)))
    [void]$rowsNorm.Add((New-Row -Index 4 -Cells @(
        (New-TextCell -Col 1 -Text "Norma" -Style 4),
        (New-TextCell -Col 2 -Text "Ambito" -Style 4),
        (New-TextCell -Col 3 -Text "Aplicacion al proyecto" -Style 4),
        (New-TextCell -Col 4 -Text "Documento destino" -Style 4),
        (New-TextCell -Col 5 -Text "Estado" -Style 4),
        (New-TextCell -Col 6 -Text "Observaciones" -Style 4)
    )))
    $rowIndex = 5
    foreach ($norm in $norms) {
        [void]$rowsNorm.Add((New-Row -Index $rowIndex -Cells @(
            (New-TextCell -Col 1 -Text ([string]$norm))
        )))
        $rowIndex++
    }
    if ($rowIndex -eq 5) { [void]$rowsNorm.Add((New-Row -Index 5 -Cells @())) }

    $rowsCheck = @(
        (New-Row -Index 1 -Cells @(New-TextCell -Col 1 -Text "Checklist normativa" -Style 2)),
        (New-Row -Index 2 -Cells @(New-TextCell -Col 1 -Text $ProjectDisplayName -Style 3)),
        (New-Row -Index 4 -Cells @(
            (New-TextCell -Col 1 -Text "Bloque" -Style 4),
            (New-TextCell -Col 2 -Text "Comprobacion" -Style 4),
            (New-TextCell -Col 3 -Text "Responsable" -Style 4),
            (New-TextCell -Col 4 -Text "Estado" -Style 4),
            (New-TextCell -Col 5 -Text "Evidencia" -Style 4)
        ))
    )
    for ($i = 5; $i -le 18; $i++) {
        $rowsCheck += New-Row -Index $i -Cells @()
    }

    @(
        (New-SheetDefinition -Name "Normativa" -LastColumn 6 -Widths @(42, 18, 24, 22, 16, 22) -FreezeTopRow 4 -AutoFilterRef "A4:F4" -Rows ([object[]]$rowsNorm) -MergeRefs @("A1:F1", "A2:F2")),
        (New-SheetDefinition -Name "Checklist" -LastColumn 5 -Widths @(18, 34, 18, 14, 28) -FreezeTopRow 4 -AutoFilterRef "A4:E4" -Rows ([object[]]$rowsCheck) -MergeRefs @("A1:E1", "A2:E2"))
    )
}

$outputResolved = Resolve-AbsolutePath -Path $OutputDirectory
if (-not (Test-Path -LiteralPath $outputResolved)) {
    New-Item -ItemType Directory -Path $outputResolved -Force | Out-Null
}

$rootPath = (Get-Location).Path
$projectDisplayName = Get-ProjectDisplayName -ExplicitName $ProjectName
$config = Import-JsonIfExists -Path (Join-Path $rootPath "CONFIG\proyecto.template.json")
if ($null -eq $config) {
    $config = [pscustomobject]@{
        short_name = ""
        municipality = ""
        province = ""
        client = ""
        promoter = ""
        memory_filename = ""
        known_sources = @()
        base_normativa = @()
    }
}

$statusRows = Get-AnnexStatusRows -RootPath $rootPath
$workbooks = @(
    @{ Name = "00_Indice_control_documental.xlsx"; Sheets = New-ControlDocumentalWorkbookSheets -ProjectDisplayName $projectDisplayName -StatusRows $statusRows },
    @{ Name = "01_Ficha_y_fuentes_proyecto.xlsx"; Sheets = New-FichaProyectoWorkbookSheets -ProjectDisplayName $projectDisplayName -Config $config },
    @{ Name = "02_Mediciones_auxiliares.xlsx"; Sheets = New-MedicionesWorkbookSheets -ProjectDisplayName $projectDisplayName },
    @{ Name = "03_Matriz_trazabilidad.xlsx"; Sheets = New-TrazabilidadWorkbookSheets -ProjectDisplayName $projectDisplayName },
    @{ Name = "04_Control_normativa.xlsx"; Sheets = New-NormativaWorkbookSheets -ProjectDisplayName $projectDisplayName -Config $config }
)

$results = New-Object System.Collections.Generic.List[object]
foreach ($workbook in $workbooks) {
    $targetPath = Join-Path $outputResolved $workbook.Name
    if ((Test-Path -LiteralPath $targetPath) -and -not $Overwrite) {
        $results.Add([pscustomobject]@{ Path = $targetPath; Saved = $false; Reason = "exists" }) | Out-Null
        continue
    }

    New-XlsxPackage -Path $targetPath -ProjectDisplayName $projectDisplayName -Sheets ([object[]]$workbook.Sheets)
    $results.Add([pscustomobject]@{ Path = $targetPath; Saved = $true; Reason = "written" }) | Out-Null
}

$results
