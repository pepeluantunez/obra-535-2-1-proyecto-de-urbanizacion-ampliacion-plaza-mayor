param(
    [string]$ProjectConfig = ".\CONFIG\proyecto.template.json",
    [string]$OpeningsConfig = ".\CONFIG\apertura_anejos_plaza_mayor.json",
    [string]$OrthographyConfig = ".\CONFIG\ortotipografia_tecnica_es.json",
    [string]$TargetRoot = ".\DOCS - ANEJOS",
    [string]$TemplateDocPath = ".\DOCS - ANEJOS\Plantillas\PLANTILLA_MAESTRA_ANEJOS.docx",
    [string]$ReportPath = ".\CONTROL\annex_openings_standardization.md",
    [switch]$RunSyncFromGuadalmar
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Resolve-FullPathSafe {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
}

function Get-ShortPathIfAvailable {
    param([string]$Path)

    $escapedPath = '"' + $Path.Replace('"', '""') + '"'
    $shortPath = & cmd.exe /d /c "for %I in ($escapedPath) do @echo %~sI" 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    $candidate = @($shortPath | Select-Object -Last 1)[0]
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        return $null
    }

    $candidate = $candidate.Trim()
    if (-not (Test-Path -LiteralPath $candidate)) {
        return $null
    }

    return $candidate
}

function Open-FileStreamRobust {
    param(
        [System.IO.FileInfo]$File,
        [System.IO.FileMode]$Mode,
        [System.IO.FileAccess]$Access,
        [System.IO.FileShare]$Share
    )

    try {
        return $File.Open($Mode, $Access, $Share)
    } catch {
        $shortPath = Get-ShortPathIfAvailable -Path $File.FullName
        if (-not [string]::IsNullOrWhiteSpace($shortPath)) {
            return [System.IO.File]::Open($shortPath, $Mode, $Access, $Share)
        }
        throw
    }
}

function Open-ZipReadArchiveRobust {
    param([System.IO.FileInfo]$File)

    $stream = Open-FileStreamRobust -File $File -Mode ([System.IO.FileMode]::Open) -Access ([System.IO.FileAccess]::Read) -Share ([System.IO.FileShare]::ReadWrite)
    $archive = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Read, $false)
    return [pscustomobject]@{
        Stream = $stream
        Archive = $archive
    }
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

function Read-ZipEntryBytes {
    param([System.IO.Compression.ZipArchiveEntry]$Entry)

    $stream = $Entry.Open()
    try {
        $buffer = New-Object System.IO.MemoryStream
        try {
            $stream.CopyTo($buffer)
            return $buffer.ToArray()
        } finally {
            $buffer.Dispose()
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

function Write-ZipEntryBytes {
    param(
        [System.IO.Compression.ZipArchive]$Archive,
        [string]$EntryName,
        [byte[]]$Bytes
    )

    $existing = $Archive.GetEntry($EntryName)
    if ($null -ne $existing) {
        $existing.Delete()
    }

    $entry = $Archive.CreateEntry($EntryName, [System.IO.Compression.CompressionLevel]::Optimal)
    $stream = $entry.Open()
    try {
        $stream.Write($Bytes, 0, $Bytes.Length)
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

function Get-ComparableText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $normalized = $Text.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $normalized.ToCharArray()) {
        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
        if ($category -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($ch)
        }
    }

    $plain = $sb.ToString().Normalize([Text.NormalizationForm]::FormC)
    $plain = $plain.Replace(([string][char]0x2026), '...')
    $plain = $plain.Replace(([string][char]0x2013), '-')
    $plain = $plain.Replace(([string][char]0x2014), '-')
    $plain = $plain.Replace(([string][char]0x00A0), ' ')
    return (($plain -replace '\s+', ' ').Trim()).ToUpperInvariant()
}

function Convert-WordCase {
    param(
        [string]$Original,
        [string]$Replacement
    )

    if ($Original -ceq $Original.ToUpperInvariant()) {
        return $Replacement.ToUpperInvariant()
    }
    if ($Original.Length -gt 1 -and $Original.Substring(0,1) -ceq $Original.Substring(0,1).ToUpperInvariant() -and $Original.Substring(1) -ceq $Original.Substring(1).ToLowerInvariant()) {
        return (Get-Culture).TextInfo.ToTitleCase($Replacement)
    }
    return $Replacement
}

function Apply-OrthographyRules {
    param(
        [string]$Text,
        [object[]]$Rules
    )

    $updated = $Text
    foreach ($rule in $Rules) {
        $pattern = "(?i)(?<![\p{L}])$([regex]::Escape([string]$rule.bad))(?![\p{L}])"
        $updated = [regex]::Replace($updated, $pattern, {
                param($match)
                Convert-WordCase -Original $match.Value -Replacement ([string]$rule.good)
            })
    }
    return $updated
}

function Get-ParagraphText {
    param([System.Xml.XmlElement]$Paragraph)

    $texts = $Paragraph.GetElementsByTagName("w:t")
    if ($null -eq $texts -or $texts.Count -eq 0) {
        return ""
    }

    $chunks = foreach ($node in $texts) { $node.InnerText }
    return ($chunks -join "").Trim()
}

function Get-ParagraphStyle {
    param([System.Xml.XmlElement]$Paragraph)

    foreach ($child in $Paragraph.ChildNodes) {
        if ($child.LocalName -ne "pPr") {
            continue
        }
        foreach ($subChild in $child.ChildNodes) {
            if ($subChild.LocalName -eq "pStyle") {
                return $subChild.GetAttribute("val", "http://schemas.openxmlformats.org/wordprocessingml/2006/main")
            }
        }
    }
    return ""
}

function Test-BodyHeadingParagraph {
    param([System.Xml.XmlElement]$Paragraph)
    $style = Get-ParagraphStyle -Paragraph $Paragraph
    return ($style -match '^(Ttulo|Titulo|Heading)')
}

function Test-TocParagraph {
    param([System.Xml.XmlElement]$Paragraph)
    $style = Get-ParagraphStyle -Paragraph $Paragraph
    return ($style -match '^TDC')
}

function Ensure-ParagraphProperties {
    param([System.Xml.XmlElement]$Paragraph)

    foreach ($child in $Paragraph.ChildNodes) {
        if ($child.LocalName -eq "pPr") {
            return $child
        }
    }

    $pPr = $Paragraph.OwnerDocument.CreateElement("w", "pPr", "http://schemas.openxmlformats.org/wordprocessingml/2006/main")
    if ($Paragraph.HasChildNodes) {
        [void]$Paragraph.InsertBefore($pPr, $Paragraph.FirstChild)
    } else {
        [void]$Paragraph.AppendChild($pPr)
    }
    return $pPr
}

function Set-ParagraphStyle {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [string]$Style
    )

    $wordNs = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    $pPr = Ensure-ParagraphProperties -Paragraph $Paragraph
    $styleNode = $null
    foreach ($child in $pPr.ChildNodes) {
        if ($child.LocalName -eq "pStyle") {
            $styleNode = $child
            break
        }
    }

    if ($null -eq $styleNode) {
        $styleNode = $Paragraph.OwnerDocument.CreateElement("w", "pStyle", $wordNs)
        if ($pPr.HasChildNodes) {
            [void]$pPr.InsertBefore($styleNode, $pPr.FirstChild)
        } else {
            [void]$pPr.AppendChild($styleNode)
        }
    }

    [void]$styleNode.SetAttribute("val", $wordNs, $Style)
}

function Set-ParagraphText {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [string]$Text
    )

    $wordNs = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    $document = $Paragraph.OwnerDocument
    $runs = $Paragraph.GetElementsByTagName("w:r")
    $firstRun = if ($runs.Count -gt 0) { $runs.Item(0) } else { $null }
    $runProps = $null
    if ($null -ne $firstRun) {
        $runPropsNodes = $firstRun.GetElementsByTagName("w:rPr")
        $firstRunProps = if ($runPropsNodes.Count -gt 0) { $runPropsNodes.Item(0) } else { $null }
        if ($null -ne $firstRunProps) {
            $runProps = $firstRunProps.CloneNode($true)
        }
    }

    $toRemove = @()
    foreach ($child in $Paragraph.ChildNodes) {
        if ($child.LocalName -ne "pPr") {
            $toRemove += $child
        }
    }
    foreach ($child in $toRemove) {
        [void]$Paragraph.RemoveChild($child)
    }

    $run = $document.CreateElement("w", "r", $wordNs)
    if ($null -ne $runProps) {
        [void]$run.AppendChild($runProps)
    }

    $textNode = $document.CreateElement("w", "t", $wordNs)
    $spaceAttribute = $document.CreateAttribute("xml", "space", "http://www.w3.org/XML/1998/namespace")
    $spaceAttribute.Value = "preserve"
    [void]$textNode.Attributes.Append($spaceAttribute)
    $textNode.InnerText = $Text
    [void]$run.AppendChild($textNode)
    [void]$Paragraph.AppendChild($run)
}

function Replace-ParagraphWithTemplateClone {
    param(
        [System.Xml.XmlElement]$Body,
        [System.Xml.XmlElement]$Paragraph,
        [string]$ParagraphTemplateXml,
        [string]$Text
    )

    $replacement = New-ParagraphFromXml -Document $Paragraph.OwnerDocument -ParagraphXml $ParagraphTemplateXml -Text $Text
    [void]$Body.InsertBefore($replacement, $Paragraph)
    [void]$Body.RemoveChild($Paragraph)
    return $replacement
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

function Get-DocumentBody {
    param([xml]$Document)
    foreach ($child in $Document.DocumentElement.ChildNodes) {
        if ($child.LocalName -eq "body") {
            return $child
        }
    }
    return $null
}

function Get-TemplateParagraph {
    param([string]$TemplatePath)

    $templateFile = Get-Item -LiteralPath $TemplatePath
    $zipHandle = Open-ZipReadArchiveRobust -File $templateFile
    try {
        $entry = $zipHandle.Archive.GetEntry("word/document.xml")
        [xml]$document = Normalize-WordXmlText -XmlText (Read-ZipEntryText -Entry $entry)
        $body = Get-DocumentBody -Document $document
        $tocHandle = Get-TocHandle -Body $body
        if ($null -eq $tocHandle) {
            throw "La plantilla no contiene un indice reutilizable"
        }

        $capture = $false
        foreach ($child in $body.ChildNodes) {
            if (-not $capture) {
                if ($child -eq $tocHandle.AfterNode) {
                    $capture = $true
                }
                continue
            }
            if ($child.LocalName -ne "p") {
                continue
            }
            if (Test-BodyHeadingParagraph -Paragraph $child) {
                $next = Get-NextSiblingElement -Node $child
                if ($null -ne $next -and $next.LocalName -eq "p" -and -not (Test-BodyHeadingParagraph -Paragraph $next)) {
                    $text = Get-ParagraphText -Paragraph $next
                    $style = Get-ParagraphStyle -Paragraph $next
                    if (-not [string]::IsNullOrWhiteSpace($text) -and $style -ne 'Prrafodelista') {
                        return $next.OuterXml
                    }
                }
            }
        }
    } finally {
        $zipHandle.Archive.Dispose()
        $zipHandle.Stream.Dispose()
    }

    throw "No se ha podido resolver un parrafo base desde $TemplatePath"
}

function Get-TemplateOpeningScaffold {
    param([string]$TemplatePath)

    $templateFile = Get-Item -LiteralPath $TemplatePath
    $zipHandle = Open-ZipReadArchiveRobust -File $templateFile
    try {
        $entry = $zipHandle.Archive.GetEntry("word/document.xml")
        [xml]$document = Normalize-WordXmlText -XmlText (Read-ZipEntryText -Entry $entry)
        $body = Get-DocumentBody -Document $document
        $tocHandle = Get-TocHandle -Body $body
        if ($null -eq $tocHandle) {
            throw "La plantilla no contiene un indice reutilizable"
        }

        $headings = @(Get-BodyHeadingEntries -Body $body -AfterNode $tocHandle.AfterNode)
        if ($headings.Count -eq 0) {
            throw "La plantilla no contiene apartados de cuerpo tras el indice"
        }

        $firstHeadingNode = $headings[0].Node
        $capture = $false
        $nodes = New-Object System.Collections.Generic.List[string]
        foreach ($child in @($body.ChildNodes)) {
            if (-not $capture) {
                if ($child -eq $tocHandle.AfterNode) {
                    $capture = $true
                }
                continue
            }

            if ($child -eq $firstHeadingNode) {
                break
            }

            if ($child.NodeType -eq [System.Xml.XmlNodeType]::Element) {
                $nodes.Add($child.OuterXml) | Out-Null
            }
        }

        if ($nodes.Count -eq 0) {
            throw "La plantilla no contiene bloque de apertura entre indice y cuerpo"
        }

        return $nodes.ToArray()
    } finally {
        $zipHandle.Archive.Dispose()
        $zipHandle.Stream.Dispose()
    }
}

function Resolve-PackagePartPath {
    param(
        [string]$BasePartPath,
        [string]$RelativeTarget
    )

    if ([string]::IsNullOrWhiteSpace($RelativeTarget) -or $RelativeTarget -match '^[a-zA-Z]+:') {
        return $null
    }

    $segments = New-Object System.Collections.Generic.List[string]
    $baseDir = Split-Path -Path $BasePartPath -Parent
    foreach ($segment in (($baseDir -replace '\\', '/') -split '/')) {
        if (-not [string]::IsNullOrWhiteSpace($segment)) {
            $segments.Add($segment) | Out-Null
        }
    }

    foreach ($segment in (($RelativeTarget -replace '\\', '/') -split '/')) {
        if ([string]::IsNullOrWhiteSpace($segment) -or $segment -eq '.') {
            continue
        }
        if ($segment -eq '..') {
            if ($segments.Count -gt 0) {
                $segments.RemoveAt($segments.Count - 1)
            }
            continue
        }
        $segments.Add($segment) | Out-Null
    }

    return ($segments -join '/')
}

function Get-SourcePartFromRelationshipEntry {
    param([string]$RelationshipEntryName)

    $relsDir = Split-Path -Path $RelationshipEntryName -Parent
    $partDir = Split-Path -Path $relsDir -Parent
    $partName = [System.IO.Path]::GetFileNameWithoutExtension([System.IO.Path]::GetFileName($RelationshipEntryName))
    if ([string]::IsNullOrWhiteSpace($partDir)) {
        return $partName
    }
    return (($partDir -replace '\\', '/') + '/' + $partName)
}

function New-BodyNodeFromXml {
    param(
        [xml]$Document,
        [string]$NodeXml
    )

    [xml]$wrapper = "<root xmlns:w='http://schemas.openxmlformats.org/wordprocessingml/2006/main' xmlns:r='http://schemas.openxmlformats.org/officeDocument/2006/relationships'>$NodeXml</root>"
    return $Document.ImportNode($wrapper.DocumentElement.FirstChild, $true)
}

function Insert-BodyNodesBefore {
    param(
        [System.Xml.XmlElement]$Body,
        [System.Xml.XmlNode]$BeforeNode,
        [xml]$Document,
        [string[]]$NodeXmls
    )

    foreach ($nodeXml in $NodeXmls) {
        $node = New-BodyNodeFromXml -Document $Document -NodeXml $nodeXml
        if ($null -ne $BeforeNode) {
            [void]$Body.InsertBefore($node, $BeforeNode)
        } else {
            [void]$Body.AppendChild($node)
        }
    }
}

function Get-LayoutFingerprints {
    param([System.IO.Compression.ZipArchive]$Archive)

    $result = @{}
    foreach ($entry in @($Archive.Entries | Where-Object {
                $_.FullName -match '^word/(header|footer)\d+\.xml$' -or
                $_.FullName -match '^word/_rels/(header|footer)\d+\.xml\.rels$'
            })) {
        $result[$entry.FullName] = [Convert]::ToBase64String((Read-ZipEntryBytes -Entry $entry))
    }
    return $result
}

function Assert-LayoutFingerprintsUnchanged {
    param(
        [System.IO.Compression.ZipArchive]$Archive,
        [hashtable]$BeforeFingerprints
    )

    $afterFingerprints = Get-LayoutFingerprints -Archive $Archive
    $beforeKeys = @($BeforeFingerprints.Keys | Sort-Object)
    $afterKeys = @($afterFingerprints.Keys | Sort-Object)
    if (($beforeKeys -join '|') -ne ($afterKeys -join '|')) {
        throw "La normalizacion de aperturas ha alterado el conjunto de headers/footers; se aborta para no tocar partes fuera de alcance."
    }

    foreach ($key in $beforeKeys) {
        if ($BeforeFingerprints[$key] -ne $afterFingerprints[$key]) {
            throw "La normalizacion de aperturas ha modificado $key; se aborta para no tocar cabeceras ni pies."
        }
    }
}

function New-ParagraphFromXml {
    param(
        [xml]$Document,
        [string]$ParagraphXml,
        [string]$Text
    )

    [xml]$wrapper = "<root xmlns:w='http://schemas.openxmlformats.org/wordprocessingml/2006/main'>$ParagraphXml</root>"
    $paragraph = $Document.ImportNode($wrapper.DocumentElement.FirstChild, $true)
    Set-ParagraphText -Paragraph $paragraph -Text $Text
    return $paragraph
}

function Get-TocHandle {
    param([System.Xml.XmlElement]$Body)

    foreach ($child in @($Body.ChildNodes)) {
        if ($child.LocalName -ne "sdt") {
            continue
        }
        $paragraphs = @($child.GetElementsByTagName("w:p") | Where-Object { $_ -is [System.Xml.XmlElement] -and (Test-TocParagraph -Paragraph $_) })
        if ($paragraphs.Count -eq 0) {
            continue
        }
        $content = $null
        foreach ($sdtChild in $child.ChildNodes) {
            if ($sdtChild.LocalName -eq "sdtContent") {
                $content = $sdtChild
                break
            }
        }
        if ($null -ne $content) {
            return [pscustomobject]@{
                Type = "sdt"
                Sdt = $child
                AfterNode = $child
                Content = $content
                TemplateParagraph = $paragraphs[0]
            }
        }
    }

    $flatTocParagraphs = New-Object System.Collections.Generic.List[System.Xml.XmlElement]
    foreach ($child in @($Body.ChildNodes)) {
        if ($child.LocalName -eq "p" -and (Test-TocParagraph -Paragraph $child)) {
            $flatTocParagraphs.Add($child) | Out-Null
            continue
        }

        if ($flatTocParagraphs.Count -gt 0) {
            break
        }
    }

    if ($flatTocParagraphs.Count -gt 0) {
        return [pscustomobject]@{
            Type = "flat"
            Sdt = $flatTocParagraphs[$flatTocParagraphs.Count - 1]
            AfterNode = $flatTocParagraphs[$flatTocParagraphs.Count - 1]
            FirstParagraph = $flatTocParagraphs[0]
            LastParagraph = $flatTocParagraphs[$flatTocParagraphs.Count - 1]
            TemplateParagraph = $flatTocParagraphs[0]
        }
    }

    return $null
}

function Get-BodyHeadingEntries {
    param(
        [System.Xml.XmlElement]$Body,
        [System.Xml.XmlNode]$AfterNode
    )

    $entries = New-Object System.Collections.Generic.List[object]
    $capture = ($null -eq $AfterNode)
    foreach ($child in @($Body.ChildNodes)) {
        if (-not $capture) {
            if ($child -eq $AfterNode) {
                $capture = $true
            }
            continue
        }
        if ($child.LocalName -eq "p" -and (Test-BodyHeadingParagraph -Paragraph $child)) {
            $text = Get-ParagraphText -Paragraph $child
            if (Test-IsAnnexLabelHeading -Text $text) {
                continue
            }
            $entries.Add([pscustomobject]@{
                Node = $child
                Style = Get-ParagraphStyle -Paragraph $child
                Text = $text
            }) | Out-Null
        }
    }
    return $entries.ToArray()
}

function Test-IsObjectHeading {
    param([string]$Text)
    $comparable = Get-ComparableText -Text $Text
    return ($comparable -match '^(1[\.\- ]+)?OBJETO\b')
}

function Test-IsAnnexLabelHeading {
    param([string]$Text)
    $comparable = Get-ComparableText -Text $Text
    return ($comparable -match '^(\d+[\.\- ]+)?(ANEJO|ANEXO)\s+\d+\b')
}

function Get-NormalizedBodyHeadingStyle {
    param([string]$Style)

    $level = Get-StyleLevel -Style $Style
    if ($level -le 2) {
        return 'Ttulo2'
    }
    if ($level -eq 3) {
        return 'Ttulo3'
    }
    if ($level -eq 4) {
        return 'Ttulo4'
    }
    return ('Ttulo{0}' -f $level)
}

function Set-TopHeadingNumber {
    param(
        [string]$Text,
        [int]$TopNumber
    )

    if ($Text -match '^\s*\d+') {
        return ($Text -replace '^\s*\d+', [string]$TopNumber)
    }
    return ("{0}. {1}" -f $TopNumber, $Text.Trim())
}

function Set-SubHeadingTopNumber {
    param(
        [string]$Text,
        [int]$TopNumber
    )

    if ($Text -match '^\s*\d+') {
        return ($Text -replace '^\s*\d+', [string]$TopNumber)
    }
    return $Text
}

function Build-HeadingPlan {
    param(
        [object[]]$ExistingEntries,
        [string]$ObjectHeadingText,
        [object[]]$OrthographyRules
    )

    if ($ExistingEntries.Count -eq 0) {
        return [pscustomobject]@{
            InsertObject = $true
            Entries = @([pscustomobject]@{ Style = 'Ttulo2'; Text = $ObjectHeadingText })
        }
    }

    $insertObject = -not (Test-IsObjectHeading -Text $ExistingEntries[0].Text)
    $topCounter = if ($insertObject) { 2 } else { 1 }
    $currentTop = if ($insertObject) { 1 } else { 0 }
    $result = New-Object System.Collections.Generic.List[object]

    if ($insertObject) {
        $result.Add([pscustomobject]@{ Style = 'Ttulo2'; Text = $ObjectHeadingText }) | Out-Null
    }

    foreach ($entry in $ExistingEntries) {
        $styleLevel = Get-StyleLevel -Style $entry.Style
        $text = $entry.Text

        if (-not $insertObject -and $result.Count -eq 0 -and (Test-IsObjectHeading -Text $text)) {
            $newText = $ObjectHeadingText
            $currentTop = 1
            $topCounter = 2
        } elseif ($styleLevel -le 2) {
            $newText = Set-TopHeadingNumber -Text $text -TopNumber $topCounter
            $currentTop = $topCounter
            $topCounter++
        } else {
            $newText = Set-SubHeadingTopNumber -Text $text -TopNumber $currentTop
        }

        $newText = Apply-OrthographyRules -Text $newText -Rules $OrthographyRules
        $result.Add([pscustomobject]@{ Style = (Get-NormalizedBodyHeadingStyle -Style $entry.Style); Text = $newText; Node = $entry.Node }) | Out-Null
    }

    return [pscustomobject]@{
        InsertObject = $insertObject
        Entries = $result.ToArray()
    }
}

function Get-NextSiblingElement {
    param([System.Xml.XmlNode]$Node)
    $next = $Node.NextSibling
    while ($null -ne $next -and $next.NodeType -ne [System.Xml.XmlNodeType]::Element) {
        $next = $next.NextSibling
    }
    return $next
}

function Ensure-ParagraphAfterHeading {
    param(
        [System.Xml.XmlElement]$Body,
        [System.Xml.XmlElement]$HeadingNode,
        [string]$Text,
        [string]$ParagraphTemplateXml
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $next = Get-NextSiblingElement -Node $HeadingNode
    if ($null -ne $next -and $next.LocalName -eq "p" -and -not (Test-BodyHeadingParagraph -Paragraph $next)) {
        return (Replace-ParagraphWithTemplateClone -Body $Body -Paragraph $next -ParagraphTemplateXml $ParagraphTemplateXml -Text $Text)
    }

    $paragraph = New-ParagraphFromXml -Document $HeadingNode.OwnerDocument -ParagraphXml $ParagraphTemplateXml -Text $Text
    if ($null -ne $next) {
        [void]$Body.InsertBefore($paragraph, $next)
    } else {
        [void]$Body.AppendChild($paragraph)
    }
    return $paragraph
}

function Update-ProjectCoverTexts {
    param(
        [System.Xml.XmlElement]$Body,
        [int]$AnnexNumber,
        [string]$AnnexTitle,
        [string]$ProjectHeading,
        [string]$ProjectCover,
        [object[]]$OrthographyRules
    )

    $annexLabel = "ANEJO $AnnexNumber. $AnnexTitle"
    foreach ($child in @($Body.ChildNodes)) {
        if ($child.LocalName -eq "sdt") {
            break
        }
        if ($child.LocalName -ne "p") {
            continue
        }
        $text = Get-ParagraphText -Paragraph $child
        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }
        $comparable = Get-ComparableText -Text $text
        if ($comparable.Contains('PROYECTO') -and $comparable.Contains('URBANIZACION')) {
            Set-ParagraphText -Paragraph $child -Text $ProjectHeading
            continue
        }
        if ($comparable.Contains('GUADALMAR') -or $comparable.Contains('PLAZA MAYOR') -or $comparable.Contains('MALAGA')) {
            Set-ParagraphText -Paragraph $child -Text $ProjectCover
            continue
        }
        if ($comparable.StartsWith('ANEJO ') -or $comparable.StartsWith('ANEXO ')) {
            Set-ParagraphText -Paragraph $child -Text (Apply-OrthographyRules -Text $annexLabel -Rules $OrthographyRules)
        }
    }
}

function Update-OpeningScaffoldTexts {
    param(
        [System.Xml.XmlElement]$Body,
        [System.Xml.XmlNode]$AfterNode,
        [System.Xml.XmlNode]$BeforeNode,
        [int]$AnnexNumber,
        [string]$AnnexTitle,
        [string]$ProjectHeading,
        [string]$ProjectCover,
        [object[]]$OrthographyRules
    )

    $annexLabel = "ANEJO $AnnexNumber. $AnnexTitle"
    $capture = ($null -eq $AfterNode)
    foreach ($child in @($Body.ChildNodes)) {
        if (-not $capture) {
            if ($child -eq $AfterNode) {
                $capture = $true
            }
            continue
        }
        if ($child -eq $BeforeNode) {
            break
        }
        if ($child.LocalName -ne "p") {
            continue
        }
        $text = Get-ParagraphText -Paragraph $child
        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }
        $comparable = Get-ComparableText -Text $text
        if ($comparable.Contains('PROYECTO') -and $comparable.Contains('URBANIZACION')) {
            Set-ParagraphText -Paragraph $child -Text $ProjectHeading
            continue
        }
        if ($comparable.Contains('GUADALMAR') -or $comparable.Contains('PLAZA MAYOR') -or $comparable.Contains('MALAGA')) {
            Set-ParagraphText -Paragraph $child -Text $ProjectCover
            continue
        }
        if ($comparable.StartsWith('ANEJO ') -or $comparable.StartsWith('ANEXO ')) {
            Set-ParagraphText -Paragraph $child -Text (Apply-OrthographyRules -Text $annexLabel -Rules $OrthographyRules)
        }
    }
}

function Test-BackgroundHeading {
    param([string]$Text)
    $comparable = Get-ComparableText -Text $Text
    return ($comparable -match 'ANTECEDENTES|INFORMACION DE PARTIDA|DATOS DE PARTIDA|INFORMACION DE BASE')
}

function Test-NormativaHeading {
    param([string]$Text)
    $comparable = Get-ComparableText -Text $Text
    return ($comparable -match 'NORMATIVA|LEGISLACION APLICABLE')
}

function Rebuild-Toc {
    param(
        [System.Xml.XmlElement]$Body,
        [object]$TocHandle,
        [object[]]$HeadingEntries
    )

    # Guardarrail: reconstruir el TOC por clonado/plano rompe campos, marcadores y numeros de pagina.
    # La regeneracion del indice debe pasar por restore_docx_toc_fields.ps1 o por Word, nunca por texto plano.
    return
}

function Cleanup-PreambleBetweenTocAndBody {
    param(
        [System.Xml.XmlElement]$Body,
        [System.Xml.XmlNode]$AfterNode,
        [System.Xml.XmlNode]$FirstHeadingNode
    )

    if ($null -eq $AfterNode -or $null -eq $FirstHeadingNode) {
        return
    }

    $capture = $false
    $toRemove = New-Object System.Collections.Generic.List[System.Xml.XmlNode]
    foreach ($child in @($Body.ChildNodes)) {
        if ($child -eq $AfterNode) {
            $capture = $true
            continue
        }
        if (-not $capture) {
            continue
        }
        if ($child -eq $FirstHeadingNode) {
            break
        }
        if ($child.NodeType -eq [System.Xml.XmlNodeType]::Element) {
            $toRemove.Add($child) | Out-Null
        }
    }

    foreach ($node in $toRemove) {
        [void]$Body.RemoveChild($node)
    }
}

function Remove-AnnexLabelHeadings {
    param(
        [System.Xml.XmlElement]$Body,
        [System.Xml.XmlNode]$AfterNode
    )

    $capture = ($null -eq $AfterNode)
    $toRemove = New-Object System.Collections.Generic.List[System.Xml.XmlNode]
    foreach ($child in @($Body.ChildNodes)) {
        if (-not $capture) {
            if ($child -eq $AfterNode) {
                $capture = $true
            }
            continue
        }

        if ($child.LocalName -ne "p" -or -not (Test-BodyHeadingParagraph -Paragraph $child)) {
            continue
        }

        $text = Get-ParagraphText -Paragraph $child
        if (Test-IsAnnexLabelHeading -Text $text) {
            $toRemove.Add($child) | Out-Null
        }
    }

    foreach ($node in $toRemove) {
        [void]$Body.RemoveChild($node)
    }
}

$projectConfigResolved = Resolve-FullPathSafe -Path $ProjectConfig
$openingsConfigResolved = Resolve-FullPathSafe -Path $OpeningsConfig
$orthographyConfigResolved = Resolve-FullPathSafe -Path $OrthographyConfig
$templateDocResolved = Resolve-FullPathSafe -Path $TemplateDocPath
$reportResolved = Resolve-FullPathSafe -Path $ReportPath

if ($RunSyncFromGuadalmar) {
    & (Join-Path (Get-Location).Path "tools\sync_docx_section_names_from_guadalmar.ps1") | Out-Null
}

$projectConfig = Get-Content -LiteralPath $projectConfigResolved -Raw -Encoding UTF8 | ConvertFrom-Json
$openings = Get-Content -LiteralPath $openingsConfigResolved -Raw -Encoding UTF8 | ConvertFrom-Json
$orthographyRules = Get-Content -LiteralPath $orthographyConfigResolved -Raw -Encoding UTF8 | ConvertFrom-Json
$paragraphTemplateXml = Get-TemplateParagraph -TemplatePath $templateDocResolved
$openingScaffoldXml = @(Get-TemplateOpeningScaffold -TemplatePath $templateDocResolved)

$targetRootResolved = Resolve-FullPathSafe -Path $TargetRoot
$reportRows = New-Object System.Collections.Generic.List[object]

foreach ($annex in $openings.annexes) {
    $folder = Get-ChildItem -LiteralPath $targetRootResolved -Directory | Where-Object { $_.Name -match ("^{0}\.-" -f [int]$annex.number) } | Select-Object -First 1
    if ($null -eq $folder) {
        $reportRows.Add([pscustomobject]@{
            Anejo = [int]$annex.number
            Estado = "WARN"
            Documento = ""
            Apartados = 0
            Incidencia = "No se ha encontrado carpeta de anejo"
        }) | Out-Null
        continue
    }

    $docFile = Get-ChildItem -LiteralPath $folder.FullName -File -Filter "*.docx" | Where-Object {
        $_.Name -notmatch '^~\$' -and
        $_.Name -notmatch '^_bak_' -and
        $_.Name -notmatch 'backup'
    } | Sort-Object Name | Select-Object -First 1
    if ($null -eq $docFile) {
        $reportRows.Add([pscustomobject]@{
            Anejo = [int]$annex.number
            Estado = "WARN"
            Documento = ""
            Apartados = 0
            Incidencia = "No se ha encontrado DOCX"
        }) | Out-Null
        continue
    }

    try {
        $stream = Open-FileStreamRobust -File $docFile -Mode ([System.IO.FileMode]::Open) -Access ([System.IO.FileAccess]::ReadWrite) -Share ([System.IO.FileShare]::Read)
        $archive = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Update, $false)
        try {
            $layoutFingerprintsBefore = Get-LayoutFingerprints -Archive $archive

            $entry = $archive.GetEntry("word/document.xml")
            if ($null -eq $entry) {
                throw "No existe word/document.xml"
            }

            [xml]$document = Normalize-WordXmlText -XmlText (Read-ZipEntryText -Entry $entry)
            $body = Get-DocumentBody -Document $document
            if ($null -eq $body) {
                throw "No se ha encontrado w:body"
            }

            $tocHandle = Get-TocHandle -Body $body
            Remove-AnnexLabelHeadings -Body $body -AfterNode $(if ($null -ne $tocHandle) { $tocHandle.AfterNode } else { $null })
            $existingHeadings = @(Get-BodyHeadingEntries -Body $body -AfterNode $(if ($null -ne $tocHandle) { $tocHandle.AfterNode } else { $null }))
            if ($existingHeadings.Count -eq 0) {
                throw "No se han detectado apartados de cuerpo reutilizables"
            }

            $headingPlan = Build-HeadingPlan -ExistingEntries $existingHeadings -ObjectHeadingText '1. OBJETO' -OrthographyRules $orthographyRules
            $plannedEntries = @($headingPlan.Entries)
            $firstExistingHeadingNode = $existingHeadings[0].Node

            Cleanup-PreambleBetweenTocAndBody -Body $body -AfterNode $(if ($null -ne $tocHandle) { $tocHandle.AfterNode } else { $null }) -FirstHeadingNode $firstExistingHeadingNode

            $objectHeadingNode = $null
            $bodyEntriesToApply = @()
            if ($headingPlan.InsertObject) {
                $objectHeadingNode = $document.ImportNode($firstExistingHeadingNode, $true)
                Set-ParagraphStyle -Paragraph $objectHeadingNode -Style $plannedEntries[0].Style
                Set-ParagraphText -Paragraph $objectHeadingNode -Text $plannedEntries[0].Text
                [void]$body.InsertBefore($objectHeadingNode, $firstExistingHeadingNode)
                $bodyEntriesToApply = @($plannedEntries | Select-Object -Skip 1)
            } else {
                $objectHeadingNode = $existingHeadings[0].Node
                $bodyEntriesToApply = $plannedEntries
            }

            Insert-BodyNodesBefore -Body $body -BeforeNode $objectHeadingNode -Document $document -NodeXmls $openingScaffoldXml
            Update-ProjectCoverTexts -Body $body -AnnexNumber ([int]$annex.number) -AnnexTitle ([string]$annex.title) -ProjectHeading ([string]$openings.project_heading) -ProjectCover ([string]$openings.project_cover) -OrthographyRules $orthographyRules
            Update-OpeningScaffoldTexts -Body $body -AfterNode $(if ($null -ne $tocHandle) { $tocHandle.AfterNode } else { $null }) -BeforeNode $objectHeadingNode -AnnexNumber ([int]$annex.number) -AnnexTitle ([string]$annex.title) -ProjectHeading ([string]$openings.project_heading) -ProjectCover ([string]$openings.project_cover) -OrthographyRules $orthographyRules

            for ($i = 0; $i -lt $existingHeadings.Count; $i++) {
                $node = $existingHeadings[$i].Node
                $planned = $bodyEntriesToApply[$i]
                Set-ParagraphStyle -Paragraph $node -Style $planned.Style
                Set-ParagraphText -Paragraph $node -Text $planned.Text
            }

            $objectText = Apply-OrthographyRules -Text ([string]$annex.object_text) -Rules $orthographyRules
            [void](Ensure-ParagraphAfterHeading -Body $body -HeadingNode $objectHeadingNode -Text $objectText -ParagraphTemplateXml $paragraphTemplateXml)

            $backgroundSeed = [string]$openings.common_background
            if (-not [string]::IsNullOrWhiteSpace([string]$annex.additional_background)) {
                $backgroundSeed = "$backgroundSeed $([string]$annex.additional_background)"
            }
            $backgroundText = Apply-OrthographyRules -Text $backgroundSeed -Rules $orthographyRules
            $normativaText = Apply-OrthographyRules -Text ([string]$openings.common_normativa) -Rules $orthographyRules

            $allHeadings = @(Get-BodyHeadingEntries -Body $body -AfterNode $(if ($null -ne $tocHandle) { $tocHandle.AfterNode } else { $null }))
            foreach ($heading in $allHeadings) {
                if (Test-IsObjectHeading -Text $heading.Text) {
                    continue
                }
                if (Test-BackgroundHeading -Text $heading.Text) {
                    [void](Ensure-ParagraphAfterHeading -Body $body -HeadingNode $heading.Node -Text $backgroundText -ParagraphTemplateXml $paragraphTemplateXml)
                    continue
                }
                if (Test-NormativaHeading -Text $heading.Text) {
                    [void](Ensure-ParagraphAfterHeading -Body $body -HeadingNode $heading.Node -Text $normativaText -ParagraphTemplateXml $paragraphTemplateXml)
                }
            }

            $finalHeadings = @(Get-BodyHeadingEntries -Body $body -AfterNode $(if ($null -ne $tocHandle) { $tocHandle.AfterNode } else { $null }))
            $tocEntries = foreach ($heading in $finalHeadings) {
                [pscustomobject]@{
                    Style = $heading.Style
                    Text = Apply-OrthographyRules -Text $heading.Text -Rules $orthographyRules
                }
            }

            if ($null -ne $tocHandle) {
                Rebuild-Toc -Body $body -TocHandle $tocHandle -HeadingEntries $tocEntries
            }

            Write-ZipEntryText -Archive $archive -EntryName "word/document.xml" -Content $document.OuterXml
            Assert-LayoutFingerprintsUnchanged -Archive $archive -BeforeFingerprints $layoutFingerprintsBefore

            $reportRows.Add([pscustomobject]@{
                Anejo = [int]$annex.number
                Estado = "OK"
                Documento = $docFile.FullName
                Apartados = $finalHeadings.Count
                Incidencia = ""
            }) | Out-Null
        } finally {
            $archive.Dispose()
            $stream.Dispose()
        }
    } catch {
        $reportRows.Add([pscustomobject]@{
            Anejo = [int]$annex.number
            Estado = "WARN"
            Documento = $docFile.FullName
            Apartados = 0
            Incidencia = $_.Exception.Message
        }) | Out-Null
    }
}

$reportDir = Split-Path -Parent $reportResolved
if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

$md = New-Object System.Collections.Generic.List[string]
[void]$md.Add("# Normalizacion de apertura de anejos")
[void]$md.Add("")
[void]$md.Add("- Fecha: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))")
[void]$md.Add("- Criterio aplicado: `1. OBJETO` comun, introduccion especifica por anejo, resto de apartados particulares del anejo y homogeneizacion de indice.")
[void]$md.Add("")
[void]$md.Add("| Anejo | Estado | Apartados finales | Documento | Incidencia |")
[void]$md.Add("|---|---|---:|---|---|")
foreach ($row in $reportRows | Sort-Object Anejo) {
    [void]$md.Add("| $($row.Anejo) | $($row.Estado) | $($row.Apartados) | $($row.Documento) | $($row.Incidencia) |")
}
$md | Set-Content -LiteralPath $reportResolved -Encoding UTF8

$reportRows | Sort-Object Anejo

