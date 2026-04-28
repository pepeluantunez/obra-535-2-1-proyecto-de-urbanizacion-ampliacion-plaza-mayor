param(
    [string]$Root = "",
    [string]$DocxPath = "",
    [switch]$SkipBackup
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
. (Join-Path $PSScriptRoot 'civil3d_path_helpers.ps1')

$WordNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'

function Convert-ToNullableNumber {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $number = 0.0
    if ([double]::TryParse(($Value -replace ',', '.'), [Globalization.NumberStyles]::Any, [Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
        return $number
    }

    return $null
}

function Format-EsNumber {
    param([AllowNull()][double]$Value)

    if ($null -eq $Value) { return '' }
    return [string]::Format([Globalization.CultureInfo]::GetCultureInfo('es-ES'), '{0:N2}', $Value)
}

function New-WElem {
    param([xml]$Xml, [string]$Name)
    return $Xml.CreateElement($Name, $WordNs)
}

function Set-ParagraphStyle {
    param(
        [xml]$Xml,
        [System.Xml.XmlElement]$Paragraph,
        [string]$StyleId
    )

    $pPr = $Paragraph.SelectSingleNode('./w:pPr', $script:Ns)
    if ($null -eq $pPr) {
        $pPr = New-WElem $Xml 'w:pPr'
        [void]$Paragraph.PrependChild($pPr)
    }

    $style = $pPr.SelectSingleNode('./w:pStyle', $script:Ns)
    if ($null -eq $style) {
        $style = New-WElem $Xml 'w:pStyle'
        [void]$pPr.AppendChild($style)
    }

    [void]$style.SetAttribute('val', $WordNs, $StyleId)
}

function New-WParagraph {
    param(
        [xml]$Xml,
        [string]$Text,
        [string]$StyleId = '',
        [bool]$Bold = $false
    )

    $paragraph = New-WElem $Xml 'w:p'
    if (-not [string]::IsNullOrWhiteSpace($StyleId)) {
        Set-ParagraphStyle -Xml $Xml -Paragraph $paragraph -StyleId $StyleId
    }

    $run = New-WElem $Xml 'w:r'
    if ($Bold) {
        $runPr = New-WElem $Xml 'w:rPr'
        $boldElem = New-WElem $Xml 'w:b'
        [void]$runPr.AppendChild($boldElem)
        [void]$run.AppendChild($runPr)
    }

    $textNode = New-WElem $Xml 'w:t'
    if ($Text -match '^\s|\s$') {
        $attribute = $Xml.CreateAttribute('xml', 'space', 'http://www.w3.org/XML/1998/namespace')
        $attribute.Value = 'preserve'
        [void]$textNode.Attributes.Append($attribute)
    }
    $textNode.InnerText = $Text
    [void]$run.AppendChild($textNode)
    [void]$paragraph.AppendChild($run)
    return $paragraph
}

function New-WTable {
    param(
        [xml]$Xml,
        [string[]]$Headers,
        [object[]]$Rows
    )

    $table = New-WElem $Xml 'w:tbl'
    $tablePr = New-WElem $Xml 'w:tblPr'
    $tableW = New-WElem $Xml 'w:tblW'
    foreach ($pair in @{ type = 'auto'; w = '0' }.GetEnumerator()) {
        $attribute = $Xml.CreateAttribute('w', $pair.Key, $WordNs)
        $attribute.Value = $pair.Value
        [void]$tableW.Attributes.Append($attribute)
    }
    [void]$tablePr.AppendChild($tableW)

    $borders = New-WElem $Xml 'w:tblBorders'
    foreach ($name in @('top', 'left', 'bottom', 'right', 'insideH', 'insideV')) {
        $border = New-WElem $Xml ("w:$name")
        foreach ($pair in @{ val = 'single'; sz = '6'; space = '0'; color = 'auto' }.GetEnumerator()) {
            $attribute = $Xml.CreateAttribute('w', $pair.Key, $WordNs)
            $attribute.Value = $pair.Value
            [void]$border.Attributes.Append($attribute)
        }
        [void]$borders.AppendChild($border)
    }
    [void]$tablePr.AppendChild($borders)
    [void]$table.AppendChild($tablePr)

    $tableGrid = New-WElem $Xml 'w:tblGrid'
    foreach ($nullHeader in $Headers) {
        $gridCol = New-WElem $Xml 'w:gridCol'
        $attribute = $Xml.CreateAttribute('w', 'w', $WordNs)
        $attribute.Value = '1800'
        [void]$gridCol.Attributes.Append($attribute)
        [void]$tableGrid.AppendChild($gridCol)
    }
    [void]$table.AppendChild($tableGrid)

    $headerRow = New-WElem $Xml 'w:tr'
    foreach ($header in $Headers) {
        $cell = New-WElem $Xml 'w:tc'
        [void]$cell.AppendChild((New-WParagraph -Xml $Xml -Text $header -Bold $true))
        [void]$headerRow.AppendChild($cell)
    }
    [void]$table.AppendChild($headerRow)

    foreach ($row in @($Rows)) {
        $tableRow = New-WElem $Xml 'w:tr'
        foreach ($cellValue in @($row)) {
            $cell = New-WElem $Xml 'w:tc'
            [void]$cell.AppendChild((New-WParagraph -Xml $Xml -Text ([string]$cellValue)))
            [void]$tableRow.AppendChild($cell)
        }
        [void]$table.AppendChild($tableRow)
    }

    return $table
}

function Get-ParagraphText {
    param([System.Xml.XmlElement]$Paragraph)
    return ((@($Paragraph.SelectNodes('.//w:t', $script:Ns)) | ForEach-Object { $_.InnerText }) -join '') -replace '\s+', ' '
}

function Find-BodyParagraphByText {
    param(
        [System.Xml.XmlElement]$Body,
        [string]$ExactText
    )

    foreach ($child in @($Body.ChildNodes)) {
        if ($child.NodeType -ne [System.Xml.XmlNodeType]::Element -or $child.LocalName -ne 'p') { continue }
        $text = (Get-ParagraphText -Paragraph $child).Trim()
        if ($text -eq $ExactText) {
            return $child
        }
    }

    return $null
}

function Remove-NodesBetween {
    param(
        [System.Xml.XmlNode]$StartNode,
        [System.Xml.XmlNode]$EndNode
    )

    $cursor = $StartNode.NextSibling
    while ($null -ne $cursor -and $cursor -ne $EndNode) {
        $next = $cursor.NextSibling
        [void]$cursor.ParentNode.RemoveChild($cursor)
        $cursor = $next
    }
}

function Insert-NodesBefore {
    param(
        [System.Xml.XmlNode]$ReferenceNode,
        [System.Collections.Generic.List[System.Xml.XmlNode]]$Nodes
    )

    foreach ($node in $Nodes) {
        [void]$ReferenceNode.ParentNode.InsertBefore($node, $ReferenceNode)
    }
}

function Pack-DirectoryAsDocx {
    param(
        [string]$SourceDirectory,
        [string]$DestinationDocx
    )

    if (Test-Path -LiteralPath $DestinationDocx) {
        Remove-Item -LiteralPath $DestinationDocx -Force
    }

    $destStream = [IO.File]::Open($DestinationDocx, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $zip = [IO.Compression.ZipArchive]::new($destStream, [IO.Compression.ZipArchiveMode]::Create, $false)
        try {
            $root = (Resolve-Path -LiteralPath $SourceDirectory).Path.TrimEnd('\')
            foreach ($file in Get-ChildItem -LiteralPath $SourceDirectory -Recurse -File) {
                $relative = $file.FullName.Substring($root.Length).TrimStart('\')
                $entryName = $relative -replace '\\', '/'
                $entry = $zip.CreateEntry($entryName, [IO.Compression.CompressionLevel]::Optimal)
                $entryStream = $entry.Open()
                $fileStream = [IO.File]::Open($file.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
                try {
                    $fileStream.CopyTo($entryStream)
                }
                finally {
                    $fileStream.Dispose()
                    $entryStream.Dispose()
                }
            }
        }
        finally {
            $zip.Dispose()
        }
    }
    finally {
        $destStream.Dispose()
    }
}

function Get-AlignmentOrder {
    param(
        [object[]]$PiRows,
        [object[]]$IncRows
    )

    $list = New-Object System.Collections.Generic.List[string]
    foreach ($row in @($PiRows + $IncRows)) {
        $name = [string]$row.Alineacion
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        if (-not $list.Contains($name)) {
            [void]$list.Add($name)
        }
    }
    return $list
}

function Build-PiSectionNodes {
    param(
        [xml]$Xml,
        [object[]]$PiRows,
        [System.Collections.Generic.List[string]]$AlignmentOrder
    )

    $nodes = New-Object System.Collections.Generic.List[System.Xml.XmlNode]
    $tableCounter = 1
    foreach ($alignment in $AlignmentOrder) {
        $rows = @($PiRows | Where-Object { $_.Alineacion -eq $alignment })
        [void]$nodes.Add((New-WParagraph -Xml $Xml -Text $alignment -StyleId 'Ttulo5'))
        [void]$nodes.Add((New-WParagraph -Xml $Xml -Text ("La alineacion {0} presenta los siguientes puntos singulares en planta segun la exportacion de Civil 3D." -f $alignment)))
        [void]$nodes.Add((New-WParagraph -Xml $Xml -Text ("Tabla {0}. Puntos singulares en planta de la alineacion {1}." -f $tableCounter, $alignment) -Bold $true))
        $tableCounter++

        $tableRows = foreach ($row in $rows) {
            ,@(
                [string]$row.PK,
                (Format-EsNumber (Convert-ToNullableNumber $row.Ordenada_m)),
                (Format-EsNumber (Convert-ToNullableNumber $row.Abscisa_m)),
                (Format-EsNumber (Convert-ToNullableNumber $row.Distancia_m)),
                [string]$row.Orientacion
            )
        }
        [void]$nodes.Add((New-WTable -Xml $Xml -Headers @('P.K. de PI', 'Ordenada (m)', 'Abscisa (m)', 'Distancia (m)', 'Orientacion') -Rows $tableRows))
        [void]$nodes.Add((New-WParagraph -Xml $Xml -Text ''))
    }

    return $nodes
}

function Build-IncrementalSectionNodes {
    param(
        [xml]$Xml,
        [object[]]$IncRows,
        [System.Collections.Generic.List[string]]$AlignmentOrder
    )

    $nodes = New-Object System.Collections.Generic.List[System.Xml.XmlNode]
    $tableCounter = 100
    foreach ($alignment in $AlignmentOrder) {
        $rows = @($IncRows | Where-Object { $_.Alineacion -eq $alignment })
        [void]$nodes.Add((New-WParagraph -Xml $Xml -Text $alignment -StyleId 'Ttulo5'))
        [void]$nodes.Add((New-WParagraph -Xml $Xml -Text ("La alineacion {0} presenta el replanteo en planta a puntos fijos segun la exportacion incremental de Civil 3D." -f $alignment)))
        [void]$nodes.Add((New-WParagraph -Xml $Xml -Text ("Tabla {0}. Puntos fijos cada 10 m en planta de la alineacion {1}." -f $tableCounter, $alignment) -Bold $true))
        $tableCounter++

        $tableRows = foreach ($row in $rows) {
            ,@(
                [string]$row.PK,
                (Format-EsNumber (Convert-ToNullableNumber $row.Ordenada_m)),
                (Format-EsNumber (Convert-ToNullableNumber $row.Abscisa_m)),
                [string]$row.Orientacion
            )
        }
        [void]$nodes.Add((New-WTable -Xml $Xml -Headers @('P.K.', 'Ordenada (m)', 'Abscisa (m)', 'Orientacion de tangente') -Rows $tableRows))
        [void]$nodes.Add((New-WParagraph -Xml $Xml -Text ''))
    }

    return $nodes
}

function Build-AlzadoPlaceholderNodes {
    param(
        [xml]$Xml,
        [System.Collections.Generic.List[string]]$AlignmentOrder,
        [string]$Description
    )

    $nodes = New-Object System.Collections.Generic.List[System.Xml.XmlNode]
    foreach ($alignment in $AlignmentOrder) {
        [void]$nodes.Add((New-WParagraph -Xml $Xml -Text $alignment -StyleId 'Ttulo5'))
        [void]$nodes.Add((New-WParagraph -Xml $Xml -Text ("Pendiente de incorporacion automatica desde las exportaciones de alzado de Civil 3D para {0}. {1}" -f $alignment, $Description)))
    }
    return $nodes
}

$projectRoot = Resolve-Civil3DProjectRoot -Root $Root
$baseDir = Resolve-Civil3DAnejo4Folder -Root $projectRoot
if ([string]::IsNullOrWhiteSpace($baseDir)) {
    throw 'No se localiza la carpeta del Anejo 4 para Civil 3D.'
}

if ([string]::IsNullOrWhiteSpace($DocxPath)) {
    $DocxPath = Resolve-Civil3DAnejoDocx -FolderPath $baseDir -PreferredNames @(
        'Anexo 4 - Trazado, Replanteo y Mediciones Auxiliares.docx',
        'Anexo 4 - Replanteo y Mediciones Auxiliares.docx'
    ) -Pattern '^Anexo\s+4.*\.docx$'
}
if (-not $DocxPath) {
    throw 'No se localiza el DOCX principal del Anejo 4.'
}

$piCsvPath = Resolve-Civil3DSourcePath -FolderPath $baseDir -FileName 'Anejo4_PK_PI_Alineaciones.csv'
$incCsvPath = Resolve-Civil3DSourcePath -FolderPath $baseDir -FileName 'Anejo4_PK_Incremental_Alineaciones.csv'
if (-not $piCsvPath) { throw 'No existe el CSV PI de alineaciones.' }
if (-not $incCsvPath) { throw 'No existe el CSV incremental de alineaciones.' }

$piRows = @(Import-Csv -LiteralPath $piCsvPath -Encoding UTF8)
$incRows = @(Import-Csv -LiteralPath $incCsvPath -Encoding UTF8)
$alignmentOrder = Get-AlignmentOrder -PiRows $piRows -IncRows $incRows
if ($alignmentOrder.Count -eq 0) {
    throw 'No se han detectado alineaciones en los CSV de Civil 3D.'
}

if (-not $SkipBackup) {
    $backupPath = Join-Path (Split-Path -Parent $DocxPath) (([IO.Path]::GetFileNameWithoutExtension($DocxPath)) + '_bak_before_civil3d.docx')
    Copy-Item -LiteralPath $DocxPath -Destination $backupPath -Force
}

$tempDir = Join-Path $env:TEMP ('anejo4_apply_' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    [IO.Compression.ZipFile]::ExtractToDirectory($DocxPath, $tempDir)
    $documentXmlPath = Join-Path $tempDir 'word\document.xml'
    [xml]$xml = Get-Content -LiteralPath $documentXmlPath -Raw -Encoding UTF8
    $script:Ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $script:Ns.AddNamespace('w', $WordNs)
    $body = $xml.SelectSingleNode('//w:body', $script:Ns)

    $p311 = Find-BodyParagraphByText -Body $body -ExactText '3.1.1. Puntos singulares'
    $p312 = Find-BodyParagraphByText -Body $body -ExactText '3.1.2. Puntos fijos cada 10 m.'
    $p321 = Find-BodyParagraphByText -Body $body -ExactText '3.2.1. Puntos singulares'
    $p322 = Find-BodyParagraphByText -Body $body -ExactText '3.2.2. Puntos fijos cada 10 m.'
    $p4 = Find-BodyParagraphByText -Body $body -ExactText '4. MEDICIONES AUXILIARES'

    foreach ($pair in @(
        @{ Name = '3.1.1'; Node = $p311 },
        @{ Name = '3.1.2'; Node = $p312 },
        @{ Name = '3.2.1'; Node = $p321 },
        @{ Name = '3.2.2'; Node = $p322 },
        @{ Name = '4'; Node = $p4 }
    )) {
        if ($null -eq $pair.Node) {
            throw "No se localiza la ancla del bloque $($pair.Name) en el DOCX."
        }
    }

    Remove-NodesBetween -StartNode $p311 -EndNode $p312
    Insert-NodesBefore -ReferenceNode $p312 -Nodes (Build-PiSectionNodes -Xml $xml -PiRows $piRows -AlignmentOrder $alignmentOrder)

    Remove-NodesBetween -StartNode $p312 -EndNode $p321
    Insert-NodesBefore -ReferenceNode $p321 -Nodes (Build-IncrementalSectionNodes -Xml $xml -IncRows $incRows -AlignmentOrder $alignmentOrder)

    Remove-NodesBetween -StartNode $p321 -EndNode $p322
    Insert-NodesBefore -ReferenceNode $p322 -Nodes (Build-AlzadoPlaceholderNodes -Xml $xml -AlignmentOrder $alignmentOrder -Description 'Cuando se disponga de Informe de curva y P.K. de VAV.html se sustituira esta nota por la tabla correspondiente.')

    Remove-NodesBetween -StartNode $p322 -EndNode $p4
    Insert-NodesBefore -ReferenceNode $p4 -Nodes (Build-AlzadoPlaceholderNodes -Xml $xml -AlignmentOrder $alignmentOrder -Description 'Cuando se disponga de Informe de P.K. incremental de VAV.html se sustituira esta nota por la tabla incremental correspondiente.')

    $utf8NoBom = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText($documentXmlPath, $xml.OuterXml, $utf8NoBom)

    Pack-DirectoryAsDocx -SourceDirectory $tempDir -DestinationDocx $DocxPath
}
finally {
    if (Test-Path -LiteralPath $tempDir) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force
    }
}

$tocScript = Join-Path $PSScriptRoot 'restore_docx_toc_fields.ps1'
if (Test-Path -LiteralPath $tocScript) {
    powershell -NoProfile -ExecutionPolicy Bypass -File $tocScript -Paths $DocxPath | Out-Null
}
else {
    Write-Warning "No existe restore_docx_toc_fields.ps1 junto al actualizador del Anejo 4. El cuerpo se ha actualizado, pero el TOC no se ha rehecho automaticamente."
}

Write-Output "OK - Anejo 4 actualizado: $DocxPath"
