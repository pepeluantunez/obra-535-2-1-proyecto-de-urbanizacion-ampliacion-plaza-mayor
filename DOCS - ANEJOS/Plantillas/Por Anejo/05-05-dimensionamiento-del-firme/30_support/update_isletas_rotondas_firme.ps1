param(
    [string]$Root = "C:\Users\USUARIO\Documents\Claude\Projects\MEJORA CARRETERA GUADALMAR\PROYECTO 535\535.2\535.2.2 Mejora Carretera Guadalmar\POU 2026"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Open-XlsxContext {
    param([string]$Path)

    $zip = [IO.Compression.ZipFile]::Open($Path, [IO.Compression.ZipArchiveMode]::Update)

    $workbookReader = New-Object IO.StreamReader($zip.GetEntry('xl/workbook.xml').Open())
    $workbookXml = [xml]$workbookReader.ReadToEnd()
    $workbookReader.Close()

    $relsReader = New-Object IO.StreamReader($zip.GetEntry('xl/_rels/workbook.xml.rels').Open())
    $relsXml = [xml]$relsReader.ReadToEnd()
    $relsReader.Close()

    $nsWorkbook = New-Object System.Xml.XmlNamespaceManager($workbookXml.NameTable)
    $nsWorkbook.AddNamespace('x', 'http://schemas.openxmlformats.org/spreadsheetml/2006/main')
    $nsRels = New-Object System.Xml.XmlNamespaceManager($relsXml.NameTable)
    $nsRels.AddNamespace('r', 'http://schemas.openxmlformats.org/package/2006/relationships')

    return [pscustomobject]@{
        Path       = $Path
        Zip        = $zip
        Workbook   = $workbookXml
        Rels       = $relsXml
        NsWorkbook = $nsWorkbook
        NsRels     = $nsRels
    }
}

function Get-SheetXml {
    param(
        $Context,
        [string]$SheetName
    )

    $sheet = $Context.Workbook.SelectSingleNode("//x:sheets/x:sheet[@name='$SheetName']", $Context.NsWorkbook)
    if (-not $sheet) { throw "No se encuentra la hoja '$SheetName' en $($Context.Path)" }

    $rid = $sheet.GetAttribute('id', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
    $rel = $Context.Rels.SelectSingleNode("//r:Relationship[@Id='$rid']", $Context.NsRels)
    if (-not $rel) { throw "No se encuentra la relacion de la hoja '$SheetName'" }

    $target = 'xl/' + $rel.Target
    $entry = $Context.Zip.GetEntry($target)
    if (-not $entry) { throw "No se encuentra la entrada '$target'" }

    $reader = New-Object IO.StreamReader($entry.Open())
    $sheetXml = [xml]$reader.ReadToEnd()
    $reader.Close()

    $nsSheet = New-Object System.Xml.XmlNamespaceManager($sheetXml.NameTable)
    $nsSheet.AddNamespace('x', 'http://schemas.openxmlformats.org/spreadsheetml/2006/main')

    return [pscustomobject]@{
        Entry  = $entry
        Xml    = $sheetXml
        Ns     = $nsSheet
        Target = $target
    }
}

function Save-SheetXml {
    param(
        $Context,
        $Sheet
    )

    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        $settings = New-Object System.Xml.XmlWriterSettings
        $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
        $settings.Indent = $false
        $writer = [System.Xml.XmlWriter]::Create($tmp, $settings)
        $Sheet.Xml.Save($writer)
        $writer.Close()

        $Sheet.Entry.Delete()
        $newEntry = $Context.Zip.CreateEntry($Sheet.Target)
        $out = $newEntry.Open()
        [byte[]]$bytes = [System.IO.File]::ReadAllBytes($tmp)
        $out.Write($bytes, 0, $bytes.Length)
        $out.Close()
    }
    finally {
        Remove-Item $tmp -ErrorAction SilentlyContinue
    }
}

function Set-WorkbookRecalc {
    param($Context)

    $calcPr = $Context.Workbook.SelectSingleNode('//x:calcPr', $Context.NsWorkbook)
    if (-not $calcPr) {
        $calcPr = $Context.Workbook.CreateElement('calcPr', 'http://schemas.openxmlformats.org/spreadsheetml/2006/main')
        $null = $Context.Workbook.workbook.AppendChild($calcPr)
    }
    $calcPr.SetAttribute('calcMode', 'auto')
    $calcPr.SetAttribute('fullCalcOnLoad', '1')
    $calcPr.SetAttribute('forceFullCalc', '1')

    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        $settings = New-Object System.Xml.XmlWriterSettings
        $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
        $settings.Indent = $false
        $writer = [System.Xml.XmlWriter]::Create($tmp, $settings)
        $Context.Workbook.Save($writer)
        $writer.Close()

        $entry = $Context.Zip.GetEntry('xl/workbook.xml')
        $entry.Delete()
        $newEntry = $Context.Zip.CreateEntry('xl/workbook.xml')
        $out = $newEntry.Open()
        [byte[]]$bytes = [System.IO.File]::ReadAllBytes($tmp)
        $out.Write($bytes, 0, $bytes.Length)
        $out.Close()
    }
    finally {
        Remove-Item $tmp -ErrorAction SilentlyContinue
    }
}

function Get-OrCreateRow {
    param($Sheet, [int]$RowNumber)

    $row = $Sheet.Xml.SelectSingleNode("//x:sheetData/x:row[@r='$RowNumber']", $Sheet.Ns)
    if ($row) { return $row }

    $sheetData = $Sheet.Xml.SelectSingleNode('//x:sheetData', $Sheet.Ns)
    $row = $Sheet.Xml.CreateElement('row', 'http://schemas.openxmlformats.org/spreadsheetml/2006/main')
    $row.SetAttribute('r', [string]$RowNumber)
    $null = $sheetData.AppendChild($row)
    return $row
}

function Get-OrCreateCell {
    param($Sheet, [string]$Address)

    $cell = $Sheet.Xml.SelectSingleNode("//x:c[@r='$Address']", $Sheet.Ns)
    if ($cell) { return $cell }

    $col = ($Address -replace '\d', '')
    $rowNumber = [int]($Address -replace '\D', '')
    $row = Get-OrCreateRow -Sheet $Sheet -RowNumber $rowNumber

    $cell = $Sheet.Xml.CreateElement('c', 'http://schemas.openxmlformats.org/spreadsheetml/2006/main')
    $cell.SetAttribute('r', $Address)

    $inserted = $false
    foreach ($existing in $row.SelectNodes('x:c', $Sheet.Ns)) {
        $existingCol = ($existing.r -replace '\d', '')
        if ([string]::CompareOrdinal($existingCol, $col) -gt 0) {
            $null = $row.InsertBefore($cell, $existing)
            $inserted = $true
            break
        }
    }
    if (-not $inserted) { $null = $row.AppendChild($cell) }
    return $cell
}

function Set-CellValue {
    param($Sheet, [string]$Address, $Value)

    $cell = Get-OrCreateCell -Sheet $Sheet -Address $Address
    $cell.RemoveAll()
    $cell.SetAttribute('r', $Address)

    $vNode = $Sheet.Xml.CreateElement('v', 'http://schemas.openxmlformats.org/spreadsheetml/2006/main')
    if ($Value -is [string]) {
        $cell.SetAttribute('t', 'str')
        $vNode.InnerText = $Value
    }
    else {
        $cell.RemoveAttribute('t')
        $vNode.InnerText = [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0}', $Value)
    }
    $null = $cell.AppendChild($vNode)
}

function Close-XlsxContext {
    param($Context)
    $Context.Zip.Dispose()
}

$area = [math]::Round((2 * [math]::PI * [math]::Pow(12, 2)), 2)
$zahorra = [math]::Round(($area * 0.30), 2)
$tveg = [math]::Round(($area * 0.50), 2)

$newPav003 = 6481.03
$newTveg001 = 1084.87

$bc3Path = Join-Path $Root 'PRESUPUESTO\535.2.bc3'
$encoding = [System.Text.Encoding]::GetEncoding(1252)
$bc3 = [System.IO.File]::ReadAllText($bc3Path, $encoding)

$replacements = @(
    @{
        Pattern = '^~D\|MCG-1\.03#\|.*$'
        Replacement = '~D|MCG-1.03#|15PPP00040\1\1\RELLENOTERRA\1\5027.27\PAV003\1\6481.03\PAV007\1\4255.88\PAV006\1\3032.49\RIEGOAD\1\25270.72\RIEGOIMP\1\17732.84\FV-SOL-001\1\29743.93\FVSOLFRAT001\1\3563.64\P01.05\1\6088.13\P11.01\1\0\P11.02\1\0\TVEG-001\1\1084.87\B02.C01.08\1\1\B02.C01.07\1\1\|'
    },
    @{
        Pattern = '^~M\|MCG-1\.03#\\PAV003\|.*$'
        Replacement = '~M|MCG-1.03#\PAV003|1\3\3\|6481.03|\Según mediciones auxiliares\\\\\\TRAMO 1\1\4856.15\\\\TRAMO 2\1\726.85\\\\AV MANUEL CASTILLO\1\174.25\\\\CTRA GUADALMAR\1\210.47\\\\CALLE GUADALHORCE\1\241.88\\\\ISLETAS 2 ROTONDAS (2 x PI x 12^2 x 0,30)\1\271.43\\\|'
    },
    @{
        Pattern = '^~M\|MCG-1\.03#\\TVEG-001\|.*$'
        Replacement = '~M|MCG-1.03#\TVEG-001|1\3\13\|1084.87|\Según mediciones auxiliares\\\\\\TRAMO 1\1\570.13\\\\TRAMO 2\1\\\\\AV MANUEL CASTILLO\1\\\\\CTRA GUADALMAR\1\38.64\\\\CALLE GUADALHORCE\1\21.71\\\\ISLETAS 2 ROTONDAS (2 x PI x 12^2 x 0,50)\1\452.39\\\|'
    }
)

foreach ($item in $replacements) {
    if (-not [regex]::IsMatch($bc3, $item.Pattern, [Text.RegularExpressions.RegexOptions]::Multiline)) {
        throw "No se encuentra el patron esperado en BC3: $($item.Pattern)"
    }
    $bc3 = [regex]::Replace($bc3, $item.Pattern, $item.Replacement, [Text.RegularExpressions.RegexOptions]::Multiline)
}

[System.IO.File]::WriteAllText($bc3Path, $bc3, $encoding)

$firmePath = Join-Path $Root 'DOCS\Documentos de Trabajo\5.- Dimensionamiento del Firme\Mediciones_Firme.xlsx'
$firme = Open-XlsxContext -Path $firmePath
try {
    $sheet = Get-SheetXml -Context $firme -SheetName 'RESUMEN'

    Set-CellValue -Sheet $sheet -Address 'A48' -Value 'GEOMETRIA'
    Set-CellValue -Sheet $sheet -Address 'B48' -Value 'ISLETAS 2 ROTONDAS - ZAHORRA 30CM'
    Set-CellValue -Sheet $sheet -Address 'C48' -Value 'm2'
    Set-CellValue -Sheet $sheet -Address 'D48' -Value $area
    Set-CellValue -Sheet $sheet -Address 'E48' -Value 'm3'
    Set-CellValue -Sheet $sheet -Address 'F48' -Value $zahorra

    Set-CellValue -Sheet $sheet -Address 'A49' -Value 'GEOMETRIA'
    Set-CellValue -Sheet $sheet -Address 'B49' -Value 'ISLETAS 2 ROTONDAS - TIERRA VEGETAL 50CM'
    Set-CellValue -Sheet $sheet -Address 'C49' -Value 'm2'
    Set-CellValue -Sheet $sheet -Address 'D49' -Value $area
    Set-CellValue -Sheet $sheet -Address 'E49' -Value 'm3'
    Set-CellValue -Sheet $sheet -Address 'F49' -Value $tveg

    Save-SheetXml -Context $firme -Sheet $sheet
    Set-WorkbookRecalc -Context $firme
}
finally {
    Close-XlsxContext -Context $firme
}

$ccPath = Join-Path $Root 'DOCS\Documentos de Trabajo\14.- Control de Calidad\535.2.2 Control-Calidad.xlsx'
$cc = Open-XlsxContext -Path $ccPath
try {
    $sheet = Get-SheetXml -Context $cc -SheetName 'CRTA. GUADALMAR'
    foreach ($addr in 'H53','H54','H55','H56','H57','H58','H59','H60','H61') {
        Set-CellValue -Sheet $sheet -Address $addr -Value $newPav003
    }
    Save-SheetXml -Context $cc -Sheet $sheet
    Set-WorkbookRecalc -Context $cc
}
finally {
    Close-XlsxContext -Context $cc
}

$note = @"
Actualizacion por isletas de rotondas:
- Area total considerada: $area m2 (2 circulos de radio 12 m).
- ZAHORRA ARTIFICIAL PAV003: +$zahorra m3 -> total $newPav003 m3.
- TIERRA VEGETAL TVEG-001: +$tveg m3 -> total $newTveg001 m3.
- Control de Calidad: PAV003 actualizado en filas H53:H61.
"@

[System.IO.File]::WriteAllText((Join-Path $Root 'DOCS\Documentos de Trabajo\5.- Dimensionamiento del Firme\Actualizacion_Isletas_Rotondas.md'), $note, [System.Text.Encoding]::UTF8)
