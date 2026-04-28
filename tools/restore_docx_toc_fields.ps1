param(
    [string]$TemplateDocPath = ".\DOCS - ANEJOS\Plantillas\PLANTILLA_MAESTRA_ANEJOS.docx",
    [string[]]$Paths = @(".\DOCS - ANEJOS"),
    [string]$ReportPath = ".\CONTROL\restore_docx_toc_fields.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$WordNs = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
$XmlNs = "http://www.w3.org/XML/1998/namespace"

function Resolve-FullPathSafe {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Ruta no valida."
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
}

function Read-ZipEntryText {
    param([System.IO.Compression.ZipArchiveEntry]$Entry)

    $stream = $Entry.Open()
    try {
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.UTF8Encoding]::new($false), $true)
        try {
            return $reader.ReadToEnd()
        } finally {
            $reader.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Write-ZipEntryText {
    param(
        [System.IO.Compression.ZipArchive]$Archive,
        [string]$EntryName,
        [string]$Content
    )

    $existing = $Archive.GetEntry($EntryName)
    if ($null -ne $existing) {
        $existing.Delete()
    }

    $entry = $Archive.CreateEntry($EntryName, [System.IO.Compression.CompressionLevel]::Optimal)
    $stream = $entry.Open()
    try {
        $writer = New-Object System.IO.StreamWriter($stream, [System.Text.UTF8Encoding]::new($false))
        try {
            $writer.Write($Content)
        } finally {
            $writer.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Normalize-WordXmlText {
    param([string]$XmlText)

    if ([string]::IsNullOrEmpty($XmlText)) {
        return $XmlText
    }

    $normalized = $XmlText -replace '\s+xmlns:d\d+p\d+="http://www\.w3\.org/XML/1998/namespace"', ''
    $normalized = $normalized -replace '\bd\d+p\d+:space=', 'xml:space='
    return $normalized
}

function Get-NamespaceManager {
    param([xml]$Document)

    $ns = New-Object System.Xml.XmlNamespaceManager($Document.NameTable)
    [void]$ns.AddNamespace("w", $WordNs)
    return $ns
}

function Ensure-UpdateFieldsOnOpen {
    param([xml]$SettingsDocument)

    $root = $SettingsDocument.DocumentElement
    if ($null -eq $root) {
        throw "settings.xml invalido"
    }

    $updateFields = $null
    foreach ($child in $root.ChildNodes) {
        if ($child.LocalName -eq "updateFields") {
            $updateFields = $child
            break
        }
    }

    if ($null -eq $updateFields) {
        $updateFields = $SettingsDocument.CreateElement("w", "updateFields", $WordNs)
        [void]$root.AppendChild($updateFields)
    }

    [void]$updateFields.SetAttribute("val", $WordNs, "true")
}

function Get-TargetFiles {
    param([string[]]$InputPaths)

    $files = New-Object System.Collections.Generic.List[System.IO.FileInfo]
    foreach ($inputPath in $InputPaths) {
        $resolved = Resolve-FullPathSafe -Path $inputPath
        if (-not (Test-Path -LiteralPath $resolved)) {
            continue
        }

        $item = Get-Item -LiteralPath $resolved
        if ($item -is [System.IO.FileInfo]) {
            if ($item.Extension -ieq ".docx" -and $item.Name -notmatch '^~\$' -and $item.Name -notmatch '^_bak_' -and $item.Name -notmatch 'backup') {
                $files.Add($item) | Out-Null
            }
            continue
        }

        foreach ($file in Get-ChildItem -LiteralPath $item.FullName -Recurse -File -Filter "Anexo *.docx") {
            if ($file.Name -match '^~\$' -or $file.Name -match '^_bak_' -or $file.Name -match 'backup') {
                continue
            }
            if ($file.FullName -match '\\DOCS - ANEJOS\\Plantillas\\') {
                continue
            }
            $files.Add($file) | Out-Null
        }
    }

    return @($files | Sort-Object FullName -Unique)
}

function Get-DocumentBody {
    param([xml]$Document)

    foreach ($child in $Document.DocumentElement.ChildNodes) {
        if ($child.LocalName -eq "body") {
            return $child
        }
    }

    return $null
}

function Get-ParagraphStyle {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns
    )

    $styleNode = $Paragraph.SelectSingleNode('./w:pPr/w:pStyle', $Ns)
    if ($null -eq $styleNode) {
        return ""
    }

    return $styleNode.GetAttribute("val", $WordNs)
}

function Get-ParagraphText {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns
    )

    $texts = $Paragraph.SelectNodes('.//w:t', $Ns)
    if ($null -eq $texts -or $texts.Count -eq 0) {
        return ""
    }

    $chunks = foreach ($node in $texts) { $node.InnerText }
    return ($chunks -join "").Trim()
}

function Get-StyleLevel {
    param([string]$Style)

    if ($Style -match '(\d+)$') {
        return [int]$Matches[1]
    }

    return 2
}

function Get-TocStyleForHeadingStyle {
    param([string]$HeadingStyle)

    $level = Get-StyleLevel -Style $HeadingStyle
    if ($level -lt 2) { $level = 2 }
    if ($level -gt 4) { $level = 4 }
    return "TDC$level"
}

function Get-NextSiblingElement {
    param([System.Xml.XmlNode]$Node)

    $candidate = $Node.NextSibling
    while ($null -ne $candidate -and $candidate.NodeType -ne [System.Xml.XmlNodeType]::Element) {
        $candidate = $candidate.NextSibling
    }
    return $candidate
}

function Import-ElementFromOuterXml {
    param(
        [xml]$Document,
        [string]$OuterXml
    )

    [xml]$wrapper = "<root xmlns:w=`"$WordNs`">$OuterXml</root>"
    return $Document.ImportNode($wrapper.DocumentElement.FirstChild, $true)
}

function Get-TocHandle {
    param(
        [System.Xml.XmlElement]$Body,
        [System.Xml.XmlNamespaceManager]$Ns
    )

    foreach ($child in @($Body.ChildNodes)) {
        if ($child.LocalName -ne "sdt") {
            continue
        }

        $paragraphs = @($child.SelectNodes('.//w:p[w:pPr/w:pStyle[starts-with(@w:val,"TDC")]]', $Ns))
        if ($paragraphs.Count -eq 0) {
            continue
        }

        $content = $child.SelectSingleNode('./w:sdtContent', $Ns)
        if ($null -eq $content) {
            continue
        }

        return [pscustomobject]@{
            Type = "sdt"
            Sdt = $child
            Content = $content
            AfterNode = $child
        }
    }

    $flatTocParagraphs = New-Object System.Collections.Generic.List[System.Xml.XmlElement]
    foreach ($child in @($Body.ChildNodes)) {
        if ($child.LocalName -eq "p") {
            $style = Get-ParagraphStyle -Paragraph $child -Ns $Ns
            if ($style -match '^TDC') {
                $flatTocParagraphs.Add($child) | Out-Null
                continue
            }
        }

        if ($flatTocParagraphs.Count -gt 0) {
            break
        }
    }

    if ($flatTocParagraphs.Count -gt 0) {
        return [pscustomobject]@{
            Type = "flat"
            FirstParagraph = $flatTocParagraphs[0]
            LastParagraph = $flatTocParagraphs[$flatTocParagraphs.Count - 1]
            AfterNode = $flatTocParagraphs[$flatTocParagraphs.Count - 1]
        }
    }

    return $null
}

function Get-BodyHeadingEntries {
    param(
        [System.Xml.XmlElement]$Body,
        [System.Xml.XmlNode]$AfterNode,
        [System.Xml.XmlNamespaceManager]$Ns
    )

    $capture = ($null -eq $AfterNode)
    $entries = New-Object System.Collections.Generic.List[object]

    foreach ($child in @($Body.ChildNodes)) {
        if (-not $capture) {
            if ($child -eq $AfterNode) {
                $capture = $true
            }
            continue
        }

        if ($child.LocalName -ne "p") {
            continue
        }

        $style = Get-ParagraphStyle -Paragraph $child -Ns $Ns
        if ($style -notmatch '^(Ttulo|Titulo|Heading)') {
            continue
        }

        $text = Get-ParagraphText -Paragraph $child -Ns $Ns
        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }

        $entries.Add([pscustomobject]@{
                Node = $child
                Style = $style
                Text = $text
            }) | Out-Null
    }

    return $entries.ToArray()
}

function Remove-TocBookmarks {
    param(
        [xml]$Document,
        [System.Xml.XmlNamespaceManager]$Ns
    )

    $bookmarkStarts = @($Document.SelectNodes('//w:bookmarkStart[starts-with(@w:name,"_Toc")]', $Ns))
    if ($bookmarkStarts.Count -eq 0) {
        return
    }

    $ids = New-Object System.Collections.Generic.HashSet[string]
    foreach ($bookmarkStart in $bookmarkStarts) {
        [void]$ids.Add($bookmarkStart.GetAttribute("id", $WordNs))
    }

    foreach ($bookmarkStart in @($bookmarkStarts)) {
        if ($null -ne $bookmarkStart.ParentNode) {
            [void]$bookmarkStart.ParentNode.RemoveChild($bookmarkStart)
        }
    }

    $bookmarkEnds = @($Document.SelectNodes('//w:bookmarkEnd', $Ns))
    foreach ($bookmarkEnd in @($bookmarkEnds)) {
        if ($ids.Contains($bookmarkEnd.GetAttribute("id", $WordNs)) -and $null -ne $bookmarkEnd.ParentNode) {
            [void]$bookmarkEnd.ParentNode.RemoveChild($bookmarkEnd)
        }
    }
}

function Get-NextBookmarkId {
    param(
        [xml]$Document,
        [System.Xml.XmlNamespaceManager]$Ns
    )

    $maxId = -1
    $bookmarkStarts = @($Document.SelectNodes('//w:bookmarkStart', $Ns))
    foreach ($bookmarkStart in $bookmarkStarts) {
        $rawId = $bookmarkStart.GetAttribute("id", $WordNs)
        $parsedId = 0
        if ([int]::TryParse($rawId, [ref]$parsedId) -and $parsedId -gt $maxId) {
            $maxId = $parsedId
        }
    }

    return ($maxId + 1)
}

function Ensure-HeadingBookmark {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [string]$BookmarkName,
        [ref]$NextBookmarkId
    )

    $document = $Paragraph.OwnerDocument
    $bookmarkId = [string]$NextBookmarkId.Value
    $NextBookmarkId.Value++

    $bookmarkStart = $document.CreateElement("w", "bookmarkStart", $WordNs)
    [void]$bookmarkStart.SetAttribute("id", $WordNs, $bookmarkId)
    [void]$bookmarkStart.SetAttribute("name", $WordNs, $BookmarkName)

    $bookmarkEnd = $document.CreateElement("w", "bookmarkEnd", $WordNs)
    [void]$bookmarkEnd.SetAttribute("id", $WordNs, $bookmarkId)

    $insertBefore = $Paragraph.FirstChild
    if ($null -ne $insertBefore -and $insertBefore.LocalName -eq "pPr") {
        $insertBefore = $insertBefore.NextSibling
    }

    if ($null -ne $insertBefore) {
        [void]$Paragraph.InsertBefore($bookmarkStart, $insertBefore)
    } else {
        [void]$Paragraph.AppendChild($bookmarkStart)
    }
    [void]$Paragraph.AppendChild($bookmarkEnd)
}

function Set-ParagraphStyle {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [string]$Style,
        [System.Xml.XmlNamespaceManager]$Ns
    )

    $pPr = $Paragraph.SelectSingleNode('./w:pPr', $Ns)
    if ($null -eq $pPr) {
        $pPr = $Paragraph.OwnerDocument.CreateElement("w", "pPr", $WordNs)
        if ($Paragraph.HasChildNodes) {
            [void]$Paragraph.InsertBefore($pPr, $Paragraph.FirstChild)
        } else {
            [void]$Paragraph.AppendChild($pPr)
        }
    }

    $styleNode = $pPr.SelectSingleNode('./w:pStyle', $Ns)
    if ($null -eq $styleNode) {
        $styleNode = $Paragraph.OwnerDocument.CreateElement("w", "pStyle", $WordNs)
        if ($pPr.HasChildNodes) {
            [void]$pPr.InsertBefore($styleNode, $pPr.FirstChild)
        } else {
            [void]$pPr.AppendChild($styleNode)
        }
    }

    [void]$styleNode.SetAttribute("val", $WordNs, $Style)
}

function Update-TocParagraph {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [string]$TocStyle,
        [string]$HeadingText,
        [string]$BookmarkName,
        [System.Xml.XmlNamespaceManager]$Ns,
        [bool]$MarkTocFieldDirty
    )

    Set-ParagraphStyle -Paragraph $Paragraph -Style $TocStyle -Ns $Ns

    $hyperlink = $Paragraph.SelectSingleNode('.//w:hyperlink', $Ns)
    if ($null -eq $hyperlink) {
        throw "Entrada TOC sin hyperlink reutilizable."
    }

    [void]$hyperlink.SetAttribute("anchor", $WordNs, $BookmarkName)

    $linkTexts = @($hyperlink.SelectNodes('.//w:t', $Ns))
    if ($linkTexts.Count -lt 2) {
        throw "Entrada TOC sin nodos de texto suficientes."
    }
    $linkTexts[0].InnerText = $HeadingText

    $pageRefInstr = $hyperlink.SelectSingleNode('.//w:instrText[contains(.,"PAGEREF")]', $Ns)
    if ($null -eq $pageRefInstr) {
        throw "Entrada TOC sin campo PAGEREF reutilizable."
    }
    $pageRefInstr.InnerText = [regex]::Replace($pageRefInstr.InnerText, '_Toc[^\s]+', $BookmarkName)

    $pageFieldBegin = $hyperlink.SelectSingleNode('.//w:fldChar[@w:fldCharType="begin"]', $Ns)
    if ($null -ne $pageFieldBegin) {
        [void]$pageFieldBegin.SetAttribute("dirty", $WordNs, "true")
    }

    if ($MarkTocFieldDirty) {
        $tocInstr = $Paragraph.SelectSingleNode('./w:r/w:instrText[contains(.,"TOC ")]', $Ns)
        if ($null -ne $tocInstr) {
            $tocFieldBegin = $Paragraph.SelectSingleNode('./w:r/w:fldChar[@w:fldCharType="begin"]', $Ns)
            if ($null -ne $tocFieldBegin) {
                [void]$tocFieldBegin.SetAttribute("dirty", $WordNs, "true")
            }
        }
    }
}

function Get-TemplateTocDefinition {
    param([string]$TemplatePath)

    $resolved = Resolve-FullPathSafe -Path $TemplatePath
    $zip = [System.IO.Compression.ZipFile]::OpenRead($resolved)
    try {
        $entry = $zip.GetEntry("word/document.xml")
        if ($null -eq $entry) {
            throw "La plantilla no contiene word/document.xml"
        }

        [xml]$document = Normalize-WordXmlText -XmlText (Read-ZipEntryText -Entry $entry)
        $ns = New-Object System.Xml.XmlNamespaceManager($document.NameTable)
        [void]$ns.AddNamespace("w", $WordNs)
        $body = Get-DocumentBody -Document $document
        $tocHandle = Get-TocHandle -Body $body -Ns $ns
        if ($null -eq $tocHandle -or $tocHandle.Type -ne "sdt") {
            throw "La plantilla no contiene un TOC sdt reutilizable."
        }

        $entryTemplates = @{}
        foreach ($style in @("TDC2", "TDC3", "TDC4")) {
            $node = $tocHandle.Content.SelectSingleNode('.//w:p[w:pPr/w:pStyle[@w:val="' + $style + '"] and not(.//w:instrText[contains(.,"TOC ")])]', $ns)
            if ($null -eq $node) {
                $node = $tocHandle.Content.SelectSingleNode('.//w:p[w:pPr/w:pStyle[@w:val="' + $style + '"]]', $ns)
            }
            if ($null -eq $node) {
                throw "La plantilla no contiene una entrada donor para $style."
            }
            $entryTemplates[$style] = $node.OuterXml
        }

        return [pscustomobject]@{
            SdtOuterXml = $tocHandle.Sdt.OuterXml
            EntryTemplates = $entryTemplates
        }
    } finally {
        $zip.Dispose()
    }
}

function Ensure-TocSdt {
    param(
        [xml]$Document,
        [System.Xml.XmlElement]$Body,
        [object]$TocHandle,
        [object]$TemplateDefinition,
        [System.Xml.XmlNamespaceManager]$Ns
    )

    if ($null -ne $TocHandle -and $TocHandle.Type -eq "sdt") {
        return $TocHandle
    }

    $sdt = Import-ElementFromOuterXml -Document $Document -OuterXml $TemplateDefinition.SdtOuterXml
    if ($null -ne $TocHandle -and $TocHandle.Type -eq "flat") {
        [void]$Body.InsertBefore($sdt, $TocHandle.FirstParagraph)
        $current = $TocHandle.FirstParagraph
        while ($null -ne $current) {
            $next = Get-NextSiblingElement -Node $current
            [void]$Body.RemoveChild($current)
            if ($current -eq $TocHandle.LastParagraph) {
                break
            }
            $current = $next
        }
    } else {
        $firstElement = $Body.FirstChild
        while ($null -ne $firstElement -and $firstElement.NodeType -ne [System.Xml.XmlNodeType]::Element) {
            $firstElement = $firstElement.NextSibling
        }
        if ($null -ne $firstElement) {
            [void]$Body.InsertBefore($sdt, $firstElement)
        } else {
            [void]$Body.AppendChild($sdt)
        }
    }

    return Get-TocHandle -Body $Body -Ns $Ns
}

function Sync-TocEntries {
    param(
        [xml]$Document,
        [System.Xml.XmlElement]$Body,
        [object]$TocHandle,
        [object]$TemplateDefinition,
        [System.Xml.XmlNamespaceManager]$Ns
    )

    $tocHandle = Ensure-TocSdt -Document $Document -Body $Body -TocHandle $TocHandle -TemplateDefinition $TemplateDefinition -Ns $Ns
    if ($null -eq $tocHandle -or $tocHandle.Type -ne "sdt") {
        throw "No se ha podido preparar un TOC sdt editable."
    }

    $headings = @(Get-BodyHeadingEntries -Body $Body -AfterNode $tocHandle.AfterNode -Ns $Ns)
    if ($headings.Count -eq 0) {
        throw "No se han detectado headings de cuerpo tras el indice."
    }

    Remove-TocBookmarks -Document $Document -Ns $Ns
    $nextBookmarkId = Get-NextBookmarkId -Document $Document -Ns $Ns

    $content = $tocHandle.Content
    $existingEntries = @($content.SelectNodes('./w:p[w:pPr/w:pStyle[starts-with(@w:val,"TDC")]]', $Ns))
    if ($existingEntries.Count -eq 0) {
        throw "El TOC sdt no contiene parrafos TDC reutilizables."
    }

    $previousEntry = $null
    for ($i = 0; $i -lt $headings.Count; $i++) {
        $heading = $headings[$i]
        $tocStyle = Get-TocStyleForHeadingStyle -HeadingStyle $heading.Style
        $bookmarkName = "_TocPM{0:D6}" -f ($i + 1)

        Ensure-HeadingBookmark -Paragraph $heading.Node -BookmarkName $bookmarkName -NextBookmarkId ([ref]$nextBookmarkId)

        $entry = $null
        if ($i -lt $existingEntries.Count) {
            $entry = $existingEntries[$i]
        } else {
            $templateOuterXml = $TemplateDefinition.EntryTemplates[$tocStyle]
            $entry = Import-ElementFromOuterXml -Document $Document -OuterXml $templateOuterXml
            if ($null -ne $previousEntry) {
                $nextSibling = Get-NextSiblingElement -Node $previousEntry
                if ($null -ne $nextSibling) {
                    [void]$content.InsertBefore($entry, $nextSibling)
                } else {
                    [void]$content.AppendChild($entry)
                }
            } else {
                [void]$content.AppendChild($entry)
            }
        }

        Update-TocParagraph -Paragraph $entry -TocStyle $tocStyle -HeadingText $heading.Text -BookmarkName $bookmarkName -Ns $Ns -MarkTocFieldDirty ($i -eq 0)
        $previousEntry = $entry
    }

    for ($i = $headings.Count; $i -lt $existingEntries.Count; $i++) {
        $entry = $existingEntries[$i]
        if ($null -ne $entry.ParentNode) {
            [void]$entry.ParentNode.RemoveChild($entry)
        }
    }

    return [pscustomobject]@{
        HeadingCount = $headings.Count
        BookmarkCount = $headings.Count
        TocEntryCount = $headings.Count
    }
}

function Repair-DocxToc {
    param(
        [System.IO.FileInfo]$File,
        [object]$TemplateDefinition
    )

    $archive = [System.IO.Compression.ZipFile]::Open($File.FullName, [System.IO.Compression.ZipArchiveMode]::Update)
    try {
        $docEntry = $archive.GetEntry("word/document.xml")
        if ($null -eq $docEntry) {
            throw "No existe word/document.xml"
        }

        [xml]$document = Normalize-WordXmlText -XmlText (Read-ZipEntryText -Entry $docEntry)
        $ns = New-Object System.Xml.XmlNamespaceManager($document.NameTable)
        [void]$ns.AddNamespace("w", $WordNs)
        $body = Get-DocumentBody -Document $document
        if ($null -eq $body) {
            throw "document.xml sin body"
        }

        $tocHandle = Get-TocHandle -Body $body -Ns $ns
        $tocStats = Sync-TocEntries -Document $document -Body $body -TocHandle $tocHandle -TemplateDefinition $TemplateDefinition -Ns $ns
        Write-ZipEntryText -Archive $archive -EntryName "word/document.xml" -Content $document.OuterXml

        $settingsEntry = $archive.GetEntry("word/settings.xml")
        if ($null -eq $settingsEntry) {
            throw "No existe word/settings.xml"
        }
        [xml]$settings = Normalize-WordXmlText -XmlText (Read-ZipEntryText -Entry $settingsEntry)
        Ensure-UpdateFieldsOnOpen -SettingsDocument $settings
        Write-ZipEntryText -Archive $archive -EntryName "word/settings.xml" -Content $settings.OuterXml
    } finally {
        $archive.Dispose()
    }

    return [pscustomobject]@{
        Path = $File.FullName
        Estado = "UPDATED"
        Incidencia = ""
        Headings = $tocStats.HeadingCount
        TocEntries = $tocStats.TocEntryCount
        TocBookmarks = $tocStats.BookmarkCount
    }
}

$templateDefinition = Get-TemplateTocDefinition -TemplatePath $TemplateDocPath
$targetFiles = Get-TargetFiles -InputPaths $Paths
$results = foreach ($file in $targetFiles) {
    try {
        Repair-DocxToc -File $file -TemplateDefinition $templateDefinition
    } catch {
        [pscustomobject]@{
            Path = $file.FullName
            Estado = "WARN"
            Incidencia = $_.Exception.Message
            Headings = 0
            TocEntries = 0
            TocBookmarks = 0
        }
    }
}

$reportResolved = Resolve-FullPathSafe -Path $ReportPath
$reportDirectory = Split-Path -Path $reportResolved -Parent
if (-not (Test-Path -LiteralPath $reportDirectory)) {
    New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
}

$workspaceRoot = (Get-Location).Path
$reportLines = New-Object System.Collections.Generic.List[string]
$reportLines.Add("# Restauracion de TOC DOCX con campos y marcadores") | Out-Null
$reportLines.Add("") | Out-Null
$reportLines.Add("| Documento | Estado | Headings | Entradas TOC | Marcadores TOC | Incidencia |") | Out-Null
$reportLines.Add("| --- | --- | --- | --- | --- | --- |") | Out-Null

foreach ($result in $results) {
    $relativePath = $result.Path
    if ($relativePath.StartsWith($workspaceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relativePath = $relativePath.Substring($workspaceRoot.Length).TrimStart('\')
    }
    $reportLines.Add("| $relativePath | $($result.Estado) | $($result.Headings) | $($result.TocEntries) | $($result.TocBookmarks) | $($result.Incidencia) |") | Out-Null
}

[System.IO.File]::WriteAllLines($reportResolved, $reportLines, [System.Text.UTF8Encoding]::new($false))

$results
