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
    if (-not $sheet) {
        throw "No se encuentra la hoja '$SheetName' en $($Context.Path)"
    }

    $rid = $sheet.GetAttribute('id', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
    $rel = $Context.Rels.SelectSingleNode("//r:Relationship[@Id='$rid']", $Context.NsRels)
    if (-not $rel) {
        throw "No se encuentra la relacion de la hoja '$SheetName'"
    }

    $target = 'xl/' + $rel.Target
    $entry = $Context.Zip.GetEntry($target)
    if (-not $entry) {
        throw "No se encuentra la entrada '$target'"
    }

    $reader = New-Object IO.StreamReader($entry.Open())
    $sheetXml = [xml]$reader.ReadToEnd()
    $reader.Close()

    $nsSheet = New-Object System.Xml.XmlNamespaceManager($sheetXml.NameTable)
    $nsSheet.AddNamespace('x', 'http://schemas.openxmlformats.org/spreadsheetml/2006/main')

    return [pscustomobject]@{
        Entry   = $entry
        Xml     = $sheetXml
        Ns      = $nsSheet
        Target  = $target
        Name    = $SheetName
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
    param(
        $Sheet,
        [int]$RowNumber
    )

    $row = $Sheet.Xml.SelectSingleNode("//x:sheetData/x:row[@r='$RowNumber']", $Sheet.Ns)
    if ($row) { return $row }

    $sheetData = $Sheet.Xml.SelectSingleNode('//x:sheetData', $Sheet.Ns)
    $row = $Sheet.Xml.CreateElement('row', 'http://schemas.openxmlformats.org/spreadsheetml/2006/main')
    $row.SetAttribute('r', [string]$RowNumber)
    $null = $sheetData.AppendChild($row)
    return $row
}

function Get-OrCreateCell {
    param(
        $Sheet,
        [string]$Address
    )

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
    if (-not $inserted) {
        $null = $row.AppendChild($cell)
    }

    return $cell
}

function Set-CellValue {
    param(
        $Sheet,
        [string]$Address,
        $Value
    )

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

$path = Join-Path $Root 'DOCS\Documentos de Trabajo\5.- Dimensionamiento del Firme\Mediciones_Firme.xlsx'
$ctx = Open-XlsxContext -Path $path
try {
    $sheet = Get-SheetXml -Context $ctx -SheetName 'RESUMEN'

    Set-CellValue -Sheet $sheet -Address 'A46' -Value 'CIVIL 3D'
    Set-CellValue -Sheet $sheet -Address 'B46' -Value 'REPAVIMENTACION 5CM'
    Set-CellValue -Sheet $sheet -Address 'C46' -Value 'm2'
    Set-CellValue -Sheet $sheet -Address 'D46' -Value 4919.64
    Set-CellValue -Sheet $sheet -Address 'E46' -Value 't'
    Set-CellValue -Sheet $sheet -Address 'F46' -Value 590.36

    Set-CellValue -Sheet $sheet -Address 'A47' -Value 'CIVIL 3D'
    Set-CellValue -Sheet $sheet -Address 'B47' -Value 'RIEGO ADHERENCIA REPAVIMENTACION 5CM'
    Set-CellValue -Sheet $sheet -Address 'C47' -Value 'm2'
    Set-CellValue -Sheet $sheet -Address 'D47' -Value 4919.64
    Set-CellValue -Sheet $sheet -Address 'E47' -Value 'm2'
    Set-CellValue -Sheet $sheet -Address 'F47' -Value 4919.64

    Save-SheetXml -Context $ctx -Sheet $sheet
    Set-WorkbookRecalc -Context $ctx
}
finally {
    Close-XlsxContext -Context $ctx
}

$note = @"
Actualizacion de Mediciones_Firme.xlsx:
- Se añade fila de REPAVIMENTACION 5CM: 4.919,64 m2 -> 590,36 t de PAV006.
- Se añade fila de RIEGO ADHERENCIA REPAVIMENTACION 5CM: 4.919,64 m2 -> 4.919,64 m2.
"@

[System.IO.File]::WriteAllText((Join-Path $Root 'DOCS\Documentos de Trabajo\5.- Dimensionamiento del Firme\Actualizacion_Mediciones_Firme.md'), $note, [System.Text.Encoding]::UTF8)
