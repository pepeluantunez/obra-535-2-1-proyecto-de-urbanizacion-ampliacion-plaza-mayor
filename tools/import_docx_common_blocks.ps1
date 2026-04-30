param(
    [Parameter(Mandatory = $true)]
    [string]$MappingPath,
    [switch]$Apply,
    [string]$ReportPath = ".\CONTROL\import_docx_common_blocks_report.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$WordNs = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

function Resolve-FullPathSafe {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
}

function Normalize-WordXmlText {
    param([string]$XmlText)
    if ([string]::IsNullOrEmpty($XmlText)) { return $XmlText }
    $normalized = $XmlText -replace '\s+xmlns:d\d+p\d+="http://www\.w3\.org/XML/1998/namespace"', ''
    $normalized = $normalized -replace '\bd\d+p\d+:space=', 'xml:space='
    return $normalized
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

function Get-ComparableText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }

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
    $plain = ($plain -replace '\s+', ' ').Trim().ToUpperInvariant()
    return $plain
}

function Get-ParagraphText {
    param([System.Xml.XmlElement]$Paragraph)
    $texts = $Paragraph.GetElementsByTagName("w:t")
    if ($null -eq $texts -or $texts.Count -eq 0) { return "" }
    $chunks = foreach ($node in $texts) { $node.InnerText }
    return ($chunks -join "")
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

function Test-HeadingParagraph {
    param([System.Xml.XmlElement]$Paragraph)
    if ($Paragraph.LocalName -ne "p") { return $false }
    $style = Get-ParagraphStyle -Paragraph $Paragraph
    if ($style -match '^(TDC|TOC)') { return $false }
    if ($style -match '^(Ttulo|Titulo|Heading)') { return $true }
    $txt = Get-ParagraphText -Paragraph $Paragraph
    return ($txt -match '^\s*(\d+(?:\.\d+)*\.?|[a-zA-Z]\))\s*')
}

function Get-BodyNodeList {
    param([xml]$Document)
    foreach ($child in $Document.DocumentElement.ChildNodes) {
        if ($child.LocalName -eq "body") {
            $list = New-Object System.Collections.Generic.List[System.Xml.XmlNode]
            foreach ($node in $child.ChildNodes) {
                if ($node.LocalName -eq "sectPr") { continue }
                $list.Add($node) | Out-Null
            }
            return [pscustomobject]@{
                Body = $child
                Nodes = $list
            }
        }
    }
    throw "No se ha encontrado w:body en document.xml"
}

function Find-HeadingIndex {
    param(
        [System.Collections.Generic.List[System.Xml.XmlNode]]$Nodes,
        [string]$HeadingText
    )

    $needle = Get-ComparableText -Text $HeadingText
    for ($i = 0; $i -lt $Nodes.Count; $i++) {
        $node = $Nodes[$i]
        if ($node.LocalName -ne "p") { continue }
        $p = [System.Xml.XmlElement]$node
        if (-not (Test-HeadingParagraph -Paragraph $p)) { continue }
        $txt = Get-ComparableText -Text (Get-ParagraphText -Paragraph $p)
        if ($txt -eq $needle) { return $i }
    }
    return -1
}

function Find-NextHeadingIndex {
    param(
        [System.Collections.Generic.List[System.Xml.XmlNode]]$Nodes,
        [int]$StartIndex
    )
    for ($i = $StartIndex + 1; $i -lt $Nodes.Count; $i++) {
        $node = $Nodes[$i]
        if ($node.LocalName -ne "p") { continue }
        $p = [System.Xml.XmlElement]$node
        if (Test-HeadingParagraph -Paragraph $p) { return $i }
    }
    return $Nodes.Count
}

function Open-DocXml {
    param([string]$Path)
    $archive = [System.IO.Compression.ZipFile]::Open($Path, [System.IO.Compression.ZipArchiveMode]::Update)
    $entry = $archive.GetEntry("word/document.xml")
    if ($null -eq $entry) {
        $archive.Dispose()
        throw "Sin word/document.xml: $Path"
    }
    [xml]$doc = Normalize-WordXmlText -XmlText (Read-ZipEntryText -Entry $entry)
    return [pscustomobject]@{
        Archive = $archive
        Entry = $entry
        Xml = $doc
    }
}

$mappingFullPath = Resolve-FullPathSafe -Path $MappingPath
if (-not (Test-Path -LiteralPath $mappingFullPath)) {
    throw "No existe mapping: $MappingPath"
}
$mapping = Get-Content -LiteralPath $mappingFullPath -Raw -Encoding utf8 | ConvertFrom-Json

$report = New-Object System.Collections.Generic.List[object]

foreach ($job in @($mapping.jobs)) {
    $donorPath = Resolve-FullPathSafe -Path ([string]$job.donor)
    if (-not (Test-Path -LiteralPath $donorPath)) {
        throw "No existe donor: $($job.donor)"
    }

    $donorHandle = Open-DocXml -Path $donorPath
    try {
        $donorBody = Get-BodyNodeList -Document $donorHandle.Xml
        $donorNodes = $donorBody.Nodes

        foreach ($targetJob in @($job.targets)) {
            $targetPath = Resolve-FullPathSafe -Path ([string]$targetJob.path)
            if (-not (Test-Path -LiteralPath $targetPath)) {
                throw "No existe target: $($targetJob.path)"
            }

            $targetHandle = Open-DocXml -Path $targetPath
            try {
                $targetBody = Get-BodyNodeList -Document $targetHandle.Xml
                $targetNodes = $targetBody.Nodes
                $targetBodyNode = $targetBody.Body

                $changedSections = 0
                foreach ($section in @($targetJob.sections)) {
                    $fromHeading = [string]$section.from
                    $toHeading = if ([string]::IsNullOrWhiteSpace([string]$section.to)) { $fromHeading } else { [string]$section.to }

                    $dStart = Find-HeadingIndex -Nodes $donorNodes -HeadingText $fromHeading
                    if ($dStart -lt 0) {
                        $report.Add([pscustomobject]@{
                                mode = if ($Apply) { "apply" } else { "dry-run" }
                                job = [string]$job.name
                                target = $targetPath
                                from = $fromHeading
                                to = $toHeading
                                status = "missing_source_heading"
                            }) | Out-Null
                        continue
                    }
                    $dEnd = Find-NextHeadingIndex -Nodes $donorNodes -StartIndex $dStart

                    $tStart = Find-HeadingIndex -Nodes $targetNodes -HeadingText $toHeading
                    if ($tStart -lt 0) {
                        $report.Add([pscustomobject]@{
                                mode = if ($Apply) { "apply" } else { "dry-run" }
                                job = [string]$job.name
                                target = $targetPath
                                from = $fromHeading
                                to = $toHeading
                                status = "missing_target_heading"
                            }) | Out-Null
                        continue
                    }
                    $tEnd = Find-NextHeadingIndex -Nodes $targetNodes -StartIndex $tStart

                    $sourceCount = [Math]::Max(0, $dEnd - $dStart - 1)
                    $targetCount = [Math]::Max(0, $tEnd - $tStart - 1)

                    if ($Apply) {
                        $insertRef = if ($tEnd -lt $targetNodes.Count) { $targetNodes[$tEnd] } else { $null }

                        for ($k = $tEnd - 1; $k -gt $tStart; $k--) {
                            [void]$targetBodyNode.RemoveChild($targetNodes[$k])
                            $targetNodes.RemoveAt($k)
                        }

                        $insertIndex = $tStart + 1
                        for ($k = $dStart + 1; $k -lt $dEnd; $k++) {
                            $clone = $targetHandle.Xml.ImportNode($donorNodes[$k], $true)
                            if ($null -ne $insertRef) {
                                [void]$targetBodyNode.InsertBefore($clone, $insertRef)
                            } else {
                                [void]$targetBodyNode.AppendChild($clone)
                            }
                            $targetNodes.Insert($insertIndex, $clone)
                            $insertIndex++
                        }
                        $changedSections++
                    }

                    $report.Add([pscustomobject]@{
                            mode = if ($Apply) { "apply" } else { "dry-run" }
                            job = [string]$job.name
                            target = $targetPath
                            from = $fromHeading
                            to = $toHeading
                            source_nodes = $sourceCount
                            target_nodes_before = $targetCount
                            status = "ok"
                        }) | Out-Null
                }

                if ($Apply -and $changedSections -gt 0) {
                    Write-ZipEntryText -Archive $targetHandle.Archive -EntryName "word/document.xml" -Content $targetHandle.Xml.OuterXml
                }
            } finally {
                $targetHandle.Archive.Dispose()
            }
        }
    } finally {
        $donorHandle.Archive.Dispose()
    }
}

$reportFullPath = Resolve-FullPathSafe -Path $ReportPath
$reportDir = Split-Path -Parent $reportFullPath
if (-not (Test-Path -LiteralPath $reportDir)) {
    [void](New-Item -ItemType Directory -Path $reportDir -Force)
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportFullPath -Encoding utf8

$summary = $report | Group-Object status | ForEach-Object { "{0}={1}" -f $_.Name, $_.Count }
Write-Output ("IMPORT DOCX COMMON BLOCKS: mode={0}; {1}" -f ($(if ($Apply) { "apply" } else { "dry-run" }), ($summary -join "; ")))
