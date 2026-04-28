param(
    [Parameter(Mandatory = $true)]
    [string[]]$Paths,
    [Parameter(Mandatory = $true)]
    [string]$ReplacementMapPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Resolve-DocFiles {
    param([string[]]$InputPaths)

    $extensions = @('.docx', '.docm')
    $resolved = @()
    foreach ($inputPath in $InputPaths) {
        $absolute = if ([IO.Path]::IsPathRooted($inputPath)) { $inputPath } else { Join-Path (Get-Location) $inputPath }
        if (-not (Test-Path -LiteralPath $absolute)) {
            throw "No existe la ruta: $inputPath"
        }

        $item = Get-Item -LiteralPath $absolute
        if ($item.PSIsContainer) {
            $resolved += Get-ChildItem -LiteralPath $item.FullName -Recurse -File |
                Where-Object { $_.Extension.ToLowerInvariant() -in $extensions } |
                Select-Object -ExpandProperty FullName
        } elseif ($item.Extension.ToLowerInvariant() -in $extensions) {
            $resolved += $item.FullName
        }
    }

    return @($resolved | Sort-Object -Unique)
}

function Get-ComparableText {
    param([string]$Text)

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

function Read-ZipEntryText {
    param([System.IO.Compression.ZipArchiveEntry]$Entry)

    $stream = $Entry.Open()
    try {
        $reader = New-Object IO.StreamReader($stream, [Text.UTF8Encoding]::new($false), $true)
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
    if ($null -ne $existing) { $existing.Delete() }

    $entry = $Archive.CreateEntry($EntryName, [System.IO.Compression.CompressionLevel]::Optimal)
    $stream = $entry.Open()
    try {
        $writer = New-Object IO.StreamWriter($stream, [Text.UTF8Encoding]::new($false))
        try {
            $writer.Write($Content)
        } finally {
            $writer.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Get-ParagraphText {
    param([System.Xml.XmlElement]$Paragraph)

    $texts = $Paragraph.GetElementsByTagName('w:t')
    if ($null -eq $texts -or $texts.Count -eq 0) { return '' }
    $parts = foreach ($node in $texts) { $node.InnerText }
    return ($parts -join '')
}

function Set-ParagraphText {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [string]$Text
    )

    $wordNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    $document = $Paragraph.OwnerDocument
    $runs = $Paragraph.GetElementsByTagName('w:r')
    $runProps = $null
    if ($runs.Count -gt 0) {
        $firstRun = $runs.Item(0)
        $props = $firstRun.GetElementsByTagName('w:rPr')
        if ($props.Count -gt 0) {
            $runProps = $props.Item(0).CloneNode($true)
        }
    }

    $toRemove = @()
    foreach ($child in $Paragraph.ChildNodes) {
        if ($child.LocalName -ne 'pPr') { $toRemove += $child }
    }
    foreach ($child in $toRemove) {
        [void]$Paragraph.RemoveChild($child)
    }

    $run = $document.CreateElement('w', 'r', $wordNs)
    if ($null -ne $runProps) { [void]$run.AppendChild($runProps) }
    $textNode = $document.CreateElement('w', 't', $wordNs)
    $textNode.InnerText = $Text
    [void]$run.AppendChild($textNode)
    [void]$Paragraph.AppendChild($run)
}

$mapObject = Get-Content -Raw -LiteralPath $ReplacementMapPath | ConvertFrom-Json -AsHashtable
$replacementMap = @{}
foreach ($key in $mapObject.Keys) {
    $replacementMap[(Get-ComparableText -Text ([string]$key))] = [string]$mapObject[$key]
}

$files = @(Resolve-DocFiles -InputPaths $Paths)
if ($files.Count -eq 0) {
    throw 'No se han encontrado DOCX o DOCM para procesar.'
}

foreach ($file in $files) {
    $archive = [System.IO.Compression.ZipFile]::Open($file, [System.IO.Compression.ZipArchiveMode]::Update)
    try {
        $entry = $archive.GetEntry('word/document.xml')
        if ($null -eq $entry) {
            Write-Output "SKIP DOCX: $file (sin word/document.xml)"
            continue
        }

        [xml]$document = Read-ZipEntryText -Entry $entry
        $changes = 0
        foreach ($paragraph in $document.GetElementsByTagName('w:p')) {
            $original = Get-ParagraphText -Paragraph $paragraph
            if ([string]::IsNullOrWhiteSpace($original)) { continue }
            $key = Get-ComparableText -Text $original
            if (-not $replacementMap.ContainsKey($key)) { continue }
            Set-ParagraphText -Paragraph $paragraph -Text $replacementMap[$key]
            $changes++
        }

        if ($changes -gt 0) {
            Write-ZipEntryText -Archive $archive -EntryName 'word/document.xml' -Content $document.OuterXml
            Write-Output "UPDATED DOCX: $file ($changes parrafos)"
        } else {
            Write-Output "UNCHANGED DOCX: $file"
        }
    } finally {
        $archive.Dispose()
    }
}
