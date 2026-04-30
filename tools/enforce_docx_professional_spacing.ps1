param(
    [Parameter(Mandatory = $true)]
    [string[]]$Paths,
    [double]$CaptionFontPt = 9,
    [string]$CaptionFont = "Montserrat",
    [switch]$IncludeTemplates,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$docExtensions = @(".docx", ".docm")
$WordNs = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
$TableHeaderFill = "366092"
$TableAltFill = "D9EAF7"
$TableBodyFill = "FFFFFF"
$TableBorderColor = "366092"

function Resolve-FullPathSafe {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
}

function Resolve-DocFiles {
    param([string[]]$InputPaths)
    $resolved = @()
    foreach ($inputPath in $InputPaths) {
        $absolute = Resolve-FullPathSafe -Path $inputPath
        if (-not (Test-Path -LiteralPath $absolute)) {
            throw "No existe la ruta: $inputPath"
        }
        $item = Get-Item -LiteralPath $absolute
        if ($item.PSIsContainer) {
            $resolved += Get-ChildItem -LiteralPath $item.FullName -Recurse -File |
                Where-Object {
                    $_.Extension.ToLowerInvariant() -in $docExtensions -and
                    $_.Name -notmatch '^~\$' -and
                    $_.Name -notmatch '_bak_' -and
                    $_.Name -notmatch '_ORIG' -and
                    ($IncludeTemplates -or $_.FullName -notmatch '\\Plantillas\\') -and
                    ($IncludeTemplates -or $_.FullName -notmatch '\\10_donor_docx\\')
                } |
                Select-Object -ExpandProperty FullName
        } elseif ($item.Extension.ToLowerInvariant() -in $docExtensions) {
            if (-not $IncludeTemplates -and $item.FullName -match '\\Plantillas\\') { continue }
            if (-not $IncludeTemplates -and $item.FullName -match '\\10_donor_docx\\') { continue }
            $resolved += $item.FullName
        }
    }
    return @($resolved | Sort-Object -Unique)
}

function Read-ZipEntryText {
    param([System.IO.Compression.ZipArchiveEntry]$Entry)
    $stream = $Entry.Open()
    try {
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.UTF8Encoding]::new($false), $true)
        try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
    } finally { $stream.Dispose() }
}

function Write-ZipEntryText {
    param(
        [System.IO.Compression.ZipArchive]$Archive,
        [string]$EntryName,
        [string]$Content
    )
    $existing = $Archive.GetEntry($EntryName)
    if ($null -ne $existing) { $existing.Delete() }
    $entry = $Archive.CreateEntry($EntryName, [System.IO.Compression.CompressionLevel]::Optimal)
    $stream = $entry.Open()
    try {
        $writer = New-Object System.IO.StreamWriter($stream, [System.Text.UTF8Encoding]::new($false))
        try { $writer.Write($Content) } finally { $writer.Dispose() }
    } finally { $stream.Dispose() }
}

function Get-BodyNodeList {
    param([xml]$Document)
    foreach ($child in $Document.DocumentElement.ChildNodes) {
        if ($child.LocalName -eq "body") {
            return $child
        }
    }
    throw "No se encontro w:body en document.xml"
}

function Set-AttributeIfDifferent {
    param(
        [System.Xml.XmlElement]$Element,
        [string]$AttrName,
        [string]$Namespace,
        [string]$Value
    )
    $current = $Element.GetAttribute($AttrName, $Namespace)
    if ($current -ne $Value) {
        [void]$Element.SetAttribute($AttrName, $Namespace, $Value)
        return $true
    }
    return $false
}

function Ensure-PPr {
    param([System.Xml.XmlElement]$Paragraph)
    foreach ($child in $Paragraph.ChildNodes) {
        if ($child.LocalName -eq "pPr") { return [System.Xml.XmlElement]$child }
    }
    $pPr = $Paragraph.OwnerDocument.CreateElement("w", "pPr", $WordNs)
    if ($Paragraph.HasChildNodes) {
        [void]$Paragraph.InsertBefore($pPr, $Paragraph.FirstChild)
    } else {
        [void]$Paragraph.AppendChild($pPr)
    }
    return $pPr
}

function Ensure-RPr {
    param([System.Xml.XmlElement]$Run)
    foreach ($child in $Run.ChildNodes) {
        if ($child.LocalName -eq "rPr") { return [System.Xml.XmlElement]$child }
    }
    $rPr = $Run.OwnerDocument.CreateElement("w", "rPr", $WordNs)
    if ($Run.HasChildNodes) {
        [void]$Run.InsertBefore($rPr, $Run.FirstChild)
    } else {
        [void]$Run.AppendChild($rPr)
    }
    return $rPr
}

function Ensure-ChildElement {
    param(
        [System.Xml.XmlElement]$Parent,
        [string]$LocalName
    )
    foreach ($child in $Parent.ChildNodes) {
        if ($child.LocalName -eq $LocalName) { return [System.Xml.XmlElement]$child }
    }
    $newChild = $Parent.OwnerDocument.CreateElement("w", $LocalName, $WordNs)
    [void]$Parent.AppendChild($newChild)
    return $newChild
}

function Ensure-ChildElementFirst {
    param(
        [System.Xml.XmlElement]$Parent,
        [string]$LocalName
    )
    foreach ($child in $Parent.ChildNodes) {
        if ($child.LocalName -eq $LocalName) { return [System.Xml.XmlElement]$child }
    }
    $newChild = $Parent.OwnerDocument.CreateElement("w", $LocalName, $WordNs)
    if ($Parent.HasChildNodes) {
        [void]$Parent.InsertBefore($newChild, $Parent.FirstChild)
    } else {
        [void]$Parent.AppendChild($newChild)
    }
    return $newChild
}

function Get-ParagraphStyle {
    param([System.Xml.XmlElement]$Paragraph)
    foreach ($child in $Paragraph.ChildNodes) {
        if ($child.LocalName -ne "pPr") { continue }
        foreach ($subChild in $child.ChildNodes) {
            if ($subChild.LocalName -eq "pStyle") {
                return $subChild.GetAttribute("val", $WordNs)
            }
        }
    }
    return ""
}

function Get-ParagraphText {
    param([System.Xml.XmlElement]$Paragraph)
    $texts = $Paragraph.GetElementsByTagName("w:t")
    if ($null -eq $texts -or $texts.Count -eq 0) { return "" }
    $parts = foreach ($node in $texts) { $node.InnerText }
    return (($parts -join "") -replace '\s+', ' ').Trim()
}

function Set-ParagraphSpacing {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [int]$BeforeTwips,
        [int]$AfterTwips,
        [bool]$KeepNext = $false
    )
    $pPr = Ensure-PPr -Paragraph $Paragraph
    $changed = $false

    $spacingNode = $null
    foreach ($node in $pPr.ChildNodes) {
        if ($node.LocalName -eq "spacing") {
            $spacingNode = $node
            break
        }
    }
    if ($null -eq $spacingNode) {
        $spacingNode = $Paragraph.OwnerDocument.CreateElement("w", "spacing", $WordNs)
        [void]$pPr.AppendChild($spacingNode)
        $changed = $true
    }
    if (Set-AttributeIfDifferent -Element $spacingNode -AttrName "before" -Namespace $WordNs -Value ([string]$BeforeTwips)) { $changed = $true }
    if (Set-AttributeIfDifferent -Element $spacingNode -AttrName "after" -Namespace $WordNs -Value ([string]$AfterTwips)) { $changed = $true }
    if (Set-AttributeIfDifferent -Element $spacingNode -AttrName "lineRule" -Namespace $WordNs -Value "auto") { $changed = $true }

    $keepNextNode = $null
    foreach ($node in $pPr.ChildNodes) {
        if ($node.LocalName -eq "keepNext") {
            $keepNextNode = $node
            break
        }
    }
    if ($KeepNext) {
        if ($null -eq $keepNextNode) {
            $keepNextNode = $Paragraph.OwnerDocument.CreateElement("w", "keepNext", $WordNs)
            [void]$pPr.AppendChild($keepNextNode)
            $changed = $true
        }
    } elseif ($null -ne $keepNextNode) {
        [void]$pPr.RemoveChild($keepNextNode)
        $changed = $true
    }
    return $changed
}

function Test-HeadingParagraph {
    param([System.Xml.XmlElement]$Paragraph)
    $style = Get-ParagraphStyle -Paragraph $Paragraph
    if ($style -match '^(TDC|TOC)') { return $false }
    if ($style -match '^(Ttulo|Titulo|Heading)') { return $true }
    return $false
}

function Get-HeadingLevel {
    param([System.Xml.XmlElement]$Paragraph)
    $style = Get-ParagraphStyle -Paragraph $Paragraph
    if ($style -match 'Heading(\d+)$') { return [int]$Matches[1] }
    if ($style -match 'Ttulo(\d+)$') { return [int]$Matches[1] }
    if ($style -match 'Titulo(\d+)$') { return [int]$Matches[1] }
    return 2
}

function Test-TableCaption {
    param([System.Xml.XmlElement]$Paragraph)
    $style = Get-ParagraphStyle -Paragraph $Paragraph
    if ($style -match '(?i)caption|leyenda') { return $true }
    $txt = Get-ParagraphText -Paragraph $Paragraph
    return ($txt -match '^\s*Tabla\s*(?:N[ºo.]?\s*)?\d+(?:[.\-:)]\s*|\s+).+')
}

function Test-TocParagraph {
    param([System.Xml.XmlElement]$Paragraph)
    $style = Get-ParagraphStyle -Paragraph $Paragraph
    return ($style -match '^(TDC|TOC)')
}

function Set-ParagraphRunTypography {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [string]$FontName,
        [double]$FontPt
    )
    $changed = $false
    $halfPoints = [int][Math]::Round($FontPt * 2)
    foreach ($runNode in $Paragraph.GetElementsByTagName("w:r")) {
        if ($runNode -isnot [System.Xml.XmlElement]) { continue }
        $run = [System.Xml.XmlElement]$runNode
        $rPr = Ensure-RPr -Run $run

        $rFonts = Ensure-ChildElement -Parent $rPr -LocalName "rFonts"
        if (Set-AttributeIfDifferent -Element $rFonts -AttrName "ascii" -Namespace $WordNs -Value $FontName) { $changed = $true }
        if (Set-AttributeIfDifferent -Element $rFonts -AttrName "hAnsi" -Namespace $WordNs -Value $FontName) { $changed = $true }
        if (Set-AttributeIfDifferent -Element $rFonts -AttrName "eastAsia" -Namespace $WordNs -Value $FontName) { $changed = $true }
        if (Set-AttributeIfDifferent -Element $rFonts -AttrName "cs" -Namespace $WordNs -Value $FontName) { $changed = $true }

        $sz = Ensure-ChildElement -Parent $rPr -LocalName "sz"
        if (Set-AttributeIfDifferent -Element $sz -AttrName "val" -Namespace $WordNs -Value ([string]$halfPoints)) { $changed = $true }

        $szCs = Ensure-ChildElement -Parent $rPr -LocalName "szCs"
        if (Set-AttributeIfDifferent -Element $szCs -AttrName "val" -Namespace $WordNs -Value ([string]$halfPoints)) { $changed = $true }
    }
    return $changed
}

function Ensure-MinRunFontSize {
    param(
        [System.Xml.XmlElement]$Run,
        [int]$MinHalfPoints
    )
    $changed = $false
    $rPr = Ensure-RPr -Run $Run
    $sz = Ensure-ChildElement -Parent $rPr -LocalName "sz"
    $current = $sz.GetAttribute("val", $WordNs)
    $currentInt = 0
    $hasCurrent = [int]::TryParse($current, [ref]$currentInt)
    if (-not $hasCurrent -or $currentInt -lt $MinHalfPoints) {
        if (Set-AttributeIfDifferent -Element $sz -AttrName "val" -Namespace $WordNs -Value ([string]$MinHalfPoints)) { $changed = $true }
    }

    $szCs = Ensure-ChildElement -Parent $rPr -LocalName "szCs"
    $currentCs = $szCs.GetAttribute("val", $WordNs)
    $currentCsInt = 0
    $hasCurrentCs = [int]::TryParse($currentCs, [ref]$currentCsInt)
    if (-not $hasCurrentCs -or $currentCsInt -lt $MinHalfPoints) {
        if (Set-AttributeIfDifferent -Element $szCs -AttrName "val" -Namespace $WordNs -Value ([string]$MinHalfPoints)) { $changed = $true }
    }
    return $changed
}

function Remove-ExplicitRunSize {
    param([System.Xml.XmlElement]$Run)
    $changed = $false
    $rPr = Ensure-RPr -Run $Run
    $toRemove = @()
    foreach ($child in $rPr.ChildNodes) {
        if ($child.LocalName -eq "sz" -or $child.LocalName -eq "szCs") {
            $toRemove += $child
        }
    }
    foreach ($node in $toRemove) {
        [void]$rPr.RemoveChild($node)
        $changed = $true
    }
    return $changed
}

function Ensure-TableReadability {
    param(
        [System.Xml.XmlElement]$Table,
        [string]$FontName,
        [double]$MinFontPt
    )
    $changed = $false
    $minHalfPoints = [int][Math]::Round($MinFontPt * 2)

    foreach ($trNode in $Table.GetElementsByTagName("w:tr")) {
        if ($trNode -isnot [System.Xml.XmlElement]) { continue }
        $tr = [System.Xml.XmlElement]$trNode
        $trPr = Ensure-ChildElementFirst -Parent $tr -LocalName "trPr"
        $cantSplit = $null
        foreach ($child in $trPr.ChildNodes) {
            if ($child.LocalName -eq "cantSplit") {
                $cantSplit = $child
                break
            }
        }
        if ($null -eq $cantSplit) {
            $cantSplit = $tr.OwnerDocument.CreateElement("w", "cantSplit", $WordNs)
            [void]$trPr.AppendChild($cantSplit)
            $changed = $true
        }
    }

    foreach ($pNode in $Table.GetElementsByTagName("w:p")) {
        if ($pNode -isnot [System.Xml.XmlElement]) { continue }
        $p = [System.Xml.XmlElement]$pNode
        $text = Get-ParagraphText -Paragraph $p
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        $pPr = Ensure-PPr -Paragraph $p
        $suppressAutoHyphens = $null
        foreach ($child in $pPr.ChildNodes) {
            if ($child.LocalName -eq "suppressAutoHyphens") {
                $suppressAutoHyphens = $child
                break
            }
        }
        if ($null -eq $suppressAutoHyphens) {
            $suppressAutoHyphens = $p.OwnerDocument.CreateElement("w", "suppressAutoHyphens", $WordNs)
            [void]$pPr.AppendChild($suppressAutoHyphens)
            $changed = $true
        }

        foreach ($runNode in $p.GetElementsByTagName("w:r")) {
            if ($runNode -isnot [System.Xml.XmlElement]) { continue }
            $run = [System.Xml.XmlElement]$runNode
            $rPr = Ensure-RPr -Run $run
            $rFonts = Ensure-ChildElement -Parent $rPr -LocalName "rFonts"
            if (Set-AttributeIfDifferent -Element $rFonts -AttrName "ascii" -Namespace $WordNs -Value $FontName) { $changed = $true }
            if (Set-AttributeIfDifferent -Element $rFonts -AttrName "hAnsi" -Namespace $WordNs -Value $FontName) { $changed = $true }
            if (Set-AttributeIfDifferent -Element $rFonts -AttrName "eastAsia" -Namespace $WordNs -Value $FontName) { $changed = $true }
            if (Set-AttributeIfDifferent -Element $rFonts -AttrName "cs" -Namespace $WordNs -Value $FontName) { $changed = $true }
            if (Remove-ExplicitRunSize -Run $run) { $changed = $true }
        }
    }
    return $changed
}

function Test-NumericLikeText {
    param([string]$Text)
    $txt = ($Text -replace '\s+', '').Trim()
    if ([string]::IsNullOrWhiteSpace($txt)) { return $false }
    return ($txt -match '^[\-\+]?\d[\d\.,]*(?:[%º]|m|m2|m3|ud|kg|l|ha)?$')
}

function Set-ParagraphAlignment {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [string]$AlignValue
    )
    $pPr = Ensure-PPr -Paragraph $Paragraph
    $jc = $null
    foreach ($child in $pPr.ChildNodes) {
        if ($child.LocalName -eq "jc") {
            $jc = [System.Xml.XmlElement]$child
            break
        }
    }
    if ($null -eq $jc) {
        $jc = $Paragraph.OwnerDocument.CreateElement("w", "jc", $WordNs)
        [void]$pPr.AppendChild($jc)
    }
    return (Set-AttributeIfDifferent -Element $jc -AttrName "val" -Namespace $WordNs -Value $AlignValue)
}

function Set-CellShading {
    param(
        [System.Xml.XmlElement]$Cell,
        [string]$FillColor
    )
    $changed = $false
    $tcPr = Ensure-ChildElementFirst -Parent $Cell -LocalName "tcPr"
    $existing = @($tcPr.ChildNodes | Where-Object { $_.LocalName -eq "shd" })
    foreach ($node in $existing) {
        [void]$tcPr.RemoveChild($node)
        $changed = $true
    }
    $shd = $Cell.OwnerDocument.CreateElement("w", "shd", $WordNs)
    [void]$shd.SetAttribute("val", $WordNs, "clear")
    [void]$shd.SetAttribute("color", $WordNs, "auto")
    [void]$shd.SetAttribute("fill", $WordNs, $FillColor)
    [void]$tcPr.AppendChild($shd)
    return $true -or $changed
}

function Set-CellBorders {
    param(
        [System.Xml.XmlElement]$Cell,
        [string]$Color
    )
    $changed = $false
    $tcPr = Ensure-ChildElementFirst -Parent $Cell -LocalName "tcPr"
    $existing = @($tcPr.ChildNodes | Where-Object { $_.LocalName -eq "tcBorders" })
    foreach ($node in $existing) {
        [void]$tcPr.RemoveChild($node)
        $changed = $true
    }
    $borders = $Cell.OwnerDocument.CreateElement("w", "tcBorders", $WordNs)
    foreach ($side in @("top", "left", "bottom", "right")) {
        $edge = $Cell.OwnerDocument.CreateElement("w", $side, $WordNs)
        [void]$edge.SetAttribute("val", $WordNs, "single")
        [void]$edge.SetAttribute("sz", $WordNs, "4")
        [void]$edge.SetAttribute("space", $WordNs, "0")
        [void]$edge.SetAttribute("color", $WordNs, $Color)
        [void]$borders.AppendChild($edge)
    }
    [void]$tcPr.AppendChild($borders)
    return $true -or $changed
}

function Set-TableProperties {
    param([System.Xml.XmlElement]$Table)
    $changed = $false
    $tblPr = Ensure-ChildElementFirst -Parent $Table -LocalName "tblPr"

    $tblLayout = Ensure-ChildElement -Parent $tblPr -LocalName "tblLayout"
    if (Set-AttributeIfDifferent -Element $tblLayout -AttrName "type" -Namespace $WordNs -Value "fixed") { $changed = $true }

    $tblCellMar = Ensure-ChildElement -Parent $tblPr -LocalName "tblCellMar"
    foreach ($side in @("top", "left", "bottom", "right")) {
        $sideNode = Ensure-ChildElement -Parent $tblCellMar -LocalName $side
        $target = if ($side -in @("left", "right")) { "100" } else { "80" }
        if (Set-AttributeIfDifferent -Element $sideNode -AttrName "w" -Namespace $WordNs -Value $target) { $changed = $true }
        if (Set-AttributeIfDifferent -Element $sideNode -AttrName "type" -Namespace $WordNs -Value "dxa") { $changed = $true }
    }
    return $changed
}

function Set-RowHeaderRepeat {
    param([System.Xml.XmlElement]$Row)
    $trPr = Ensure-ChildElementFirst -Parent $Row -LocalName "trPr"
    $tblHeader = Ensure-ChildElement -Parent $trPr -LocalName "tblHeader"
    return (Set-AttributeIfDifferent -Element $tblHeader -AttrName "val" -Namespace $WordNs -Value "1")
}

function Set-TableVisualStyle {
    param(
        [System.Xml.XmlElement]$Table,
        [string]$FontName
    )
    $changed = $false
    if (Set-TableProperties -Table $Table) { $changed = $true }

    $rows = @($Table.ChildNodes | Where-Object { $_.LocalName -eq "tr" })
    if ($rows.Count -lt 2) { return $changed }

    for ($r = 0; $r -lt $rows.Count; $r++) {
        $row = [System.Xml.XmlElement]$rows[$r]
        $isHeader = ($r -eq 0)
        $isAlt = (($r % 2) -eq 0 -and -not $isHeader)

        if ($isHeader) {
            if (Set-RowHeaderRepeat -Row $row) { $changed = $true }
        }

        $cells = @($row.ChildNodes | Where-Object { $_.LocalName -eq "tc" })
        foreach ($cellNode in $cells) {
            $cell = [System.Xml.XmlElement]$cellNode
            $fill = if ($isHeader) { $TableHeaderFill } elseif ($isAlt) { $TableAltFill } else { $TableBodyFill }
            if (Set-CellShading -Cell $cell -FillColor $fill) { $changed = $true }
            if (Set-CellBorders -Cell $cell -Color $TableBorderColor) { $changed = $true }

            foreach ($pNode in $cell.GetElementsByTagName("w:p")) {
                if ($pNode -isnot [System.Xml.XmlElement]) { continue }
                $p = [System.Xml.XmlElement]$pNode
                $txt = Get-ParagraphText -Paragraph $p
                if ([string]::IsNullOrWhiteSpace($txt)) { continue }
                $align = if ($isHeader) { "center" } elseif (Test-NumericLikeText -Text $txt) { "right" } else { "left" }
                if (Set-ParagraphAlignment -Paragraph $p -AlignValue $align) { $changed = $true }
                if (Set-ParagraphSpacing -Paragraph $p -BeforeTwips 20 -AfterTwips 20 -KeepNext $false) { $changed = $true }
                foreach ($runNode in $p.GetElementsByTagName("w:r")) {
                    if ($runNode -isnot [System.Xml.XmlElement]) { continue }
                    $run = [System.Xml.XmlElement]$runNode
                    $rPr = Ensure-RPr -Run $run
                    $rFonts = Ensure-ChildElement -Parent $rPr -LocalName "rFonts"
                    if (Set-AttributeIfDifferent -Element $rFonts -AttrName "ascii" -Namespace $WordNs -Value $FontName) { $changed = $true }
                    if (Set-AttributeIfDifferent -Element $rFonts -AttrName "hAnsi" -Namespace $WordNs -Value $FontName) { $changed = $true }
                    if (Set-AttributeIfDifferent -Element $rFonts -AttrName "eastAsia" -Namespace $WordNs -Value $FontName) { $changed = $true }
                    if (Set-AttributeIfDifferent -Element $rFonts -AttrName "cs" -Namespace $WordNs -Value $FontName) { $changed = $true }
                    if (Remove-ExplicitRunSize -Run $run) { $changed = $true }

                    $bold = Ensure-ChildElement -Parent $rPr -LocalName "b"
                    if ($isHeader) {
                        if (Set-AttributeIfDifferent -Element $bold -AttrName "val" -Namespace $WordNs -Value "1") { $changed = $true }
                    } else {
                        if (Set-AttributeIfDifferent -Element $bold -AttrName "val" -Namespace $WordNs -Value "0") { $changed = $true }
                    }

                    $color = Ensure-ChildElement -Parent $rPr -LocalName "color"
                    $targetColor = if ($isHeader) { "FFFFFF" } else { "000000" }
                    if (Set-AttributeIfDifferent -Element $color -AttrName "val" -Namespace $WordNs -Value $targetColor) { $changed = $true }
                }
            }
        }
    }
    return $changed
}

function Get-PreviousNonEmptyParagraphSibling {
    param([System.Xml.XmlNode]$StartNode)
    $cursor = $StartNode
    while ($null -ne $cursor) {
        if ($cursor.LocalName -eq "p") {
            $p = [System.Xml.XmlElement]$cursor
            if (-not [string]::IsNullOrWhiteSpace((Get-ParagraphText -Paragraph $p))) { return $p }
        }
        $cursor = $cursor.PreviousSibling
    }
    return $null
}

function Get-NextNonEmptyParagraphSibling {
    param([System.Xml.XmlNode]$StartNode)
    $cursor = $StartNode
    while ($null -ne $cursor) {
        if ($cursor.LocalName -eq "p") {
            $p = [System.Xml.XmlElement]$cursor
            if (-not [string]::IsNullOrWhiteSpace((Get-ParagraphText -Paragraph $p))) { return $p }
        }
        $cursor = $cursor.NextSibling
    }
    return $null
}

$files = @(Resolve-DocFiles -InputPaths $Paths)
if ($files.Count -eq 0) {
    throw "No se han encontrado DOCX/DOCM para espaciado."
}

foreach ($file in $files) {
    $archive = $null
    try {
        $archive = [System.IO.Compression.ZipFile]::Open($file, [System.IO.Compression.ZipArchiveMode]::Update)
        $docEntry = $archive.GetEntry("word/document.xml")
        if ($null -eq $docEntry) { throw "No existe word/document.xml en $file" }
        [xml]$document = Read-ZipEntryText -Entry $docEntry
        $body = Get-BodyNodeList -Document $document

        $changes = 0

        $tables = @($body.ChildNodes | Where-Object { $_.LocalName -eq "tbl" })
        foreach ($tblNode in $tables) {
            if (Set-TableVisualStyle -Table ([System.Xml.XmlElement]$tblNode) -FontName $CaptionFont) { $changes++ }
            if (Ensure-TableReadability -Table ([System.Xml.XmlElement]$tblNode) -FontName $CaptionFont -MinFontPt 9.5) { $changes++ }

            $previousParagraph = Get-PreviousNonEmptyParagraphSibling -StartNode $tblNode.PreviousSibling
            $nextParagraph = Get-NextNonEmptyParagraphSibling -StartNode $tblNode.NextSibling
            $previousIsCaption = ($null -ne $previousParagraph -and (Test-TableCaption -Paragraph $previousParagraph))
            $nextIsCaption = ($null -ne $nextParagraph -and (Test-TableCaption -Paragraph $nextParagraph))

            if ($previousIsCaption -and -not $nextIsCaption) {
                $moved = $body.RemoveChild($previousParagraph)
                if ($null -ne $tblNode.NextSibling) {
                    [void]$body.InsertBefore($moved, $tblNode.NextSibling)
                } else {
                    [void]$body.AppendChild($moved)
                }
                $changes++
            }
        }

        $nodes = @($body.ChildNodes | Where-Object { $_.LocalName -ne "sectPr" })

        for ($i = 0; $i -lt $nodes.Count; $i++) {
            $node = $nodes[$i]
            if ($node.LocalName -ne "p") { continue }
            $p = [System.Xml.XmlElement]$node
            $text = Get-ParagraphText -Paragraph $p
            if ([string]::IsNullOrWhiteSpace($text)) { continue }
            if (Test-TocParagraph -Paragraph $p) { continue }

            if (Test-HeadingParagraph -Paragraph $p) {
                $lvl = Get-HeadingLevel -Paragraph $p
                $headingChanged = $false
                switch ($lvl) {
                    1 { $headingChanged = Set-ParagraphSpacing -Paragraph $p -BeforeTwips 280 -AfterTwips 140 -KeepNext $true }
                    2 { $headingChanged = Set-ParagraphSpacing -Paragraph $p -BeforeTwips 220 -AfterTwips 120 -KeepNext $true }
                    3 { $headingChanged = Set-ParagraphSpacing -Paragraph $p -BeforeTwips 180 -AfterTwips 100 -KeepNext $true }
                    default { $headingChanged = Set-ParagraphSpacing -Paragraph $p -BeforeTwips 160 -AfterTwips 80 -KeepNext $true }
                }
                if ($headingChanged) { $changes++ }
                continue
            }

            if (Test-TableCaption -Paragraph $p) {
                if (Set-ParagraphSpacing -Paragraph $p -BeforeTwips 40 -AfterTwips 140 -KeepNext $false) { $changes++ }
                if (Set-ParagraphRunTypography -Paragraph $p -FontName $CaptionFont -FontPt $CaptionFontPt) { $changes++ }
            }
        }

        $nodes = @($body.ChildNodes | Where-Object { $_.LocalName -ne "sectPr" })
        for ($i = 0; $i -lt $nodes.Count; $i++) {
            if ($nodes[$i].LocalName -ne "tbl") { continue }

            for ($j = $i - 1; $j -ge 0; $j--) {
                if ($nodes[$j].LocalName -ne "p") { continue }
                $beforeP = [System.Xml.XmlElement]$nodes[$j]
                $beforeTxt = Get-ParagraphText -Paragraph $beforeP
                if ([string]::IsNullOrWhiteSpace($beforeTxt)) { continue }
                if (-not (Test-TableCaption -Paragraph $beforeP) -and -not (Test-HeadingParagraph -Paragraph $beforeP)) {
                    if (Set-ParagraphSpacing -Paragraph $beforeP -BeforeTwips 0 -AfterTwips 110 -KeepNext $false) { $changes++ }
                }
                break
            }

            for ($k = $i + 1; $k -lt $nodes.Count; $k++) {
                if ($nodes[$k].LocalName -ne "p") { continue }
                $afterP = [System.Xml.XmlElement]$nodes[$k]
                $afterTxt = Get-ParagraphText -Paragraph $afterP
                if ([string]::IsNullOrWhiteSpace($afterTxt)) { continue }
                if (Test-TableCaption -Paragraph $afterP) {
                    if (Set-ParagraphSpacing -Paragraph $afterP -BeforeTwips 40 -AfterTwips 140 -KeepNext $false) { $changes++ }
                    if (Set-ParagraphRunTypography -Paragraph $afterP -FontName $CaptionFont -FontPt $CaptionFontPt) { $changes++ }
                } elseif (-not (Test-HeadingParagraph -Paragraph $afterP)) {
                    if (Set-ParagraphSpacing -Paragraph $afterP -BeforeTwips 100 -AfterTwips 80 -KeepNext $false) { $changes++ }
                }
                break
            }
        }

        if ($WhatIf) {
            Write-Output ("WHATIF SPACING: {0} (ajustes potenciales: {1})" -f $file, $changes)
            continue
        }

        Write-ZipEntryText -Archive $archive -EntryName "word/document.xml" -Content $document.OuterXml
        Write-Output ("OK SPACING: {0} (ajustes: {1})" -f $file, $changes)
    } catch {
        Write-Output ("INCIDENCIA SPACING: {0} :: {1}" -f $file, $_.Exception.Message)
    } finally {
        if ($null -ne $archive) {
            $archive.Dispose()
        }
    }
}
