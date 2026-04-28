param(
    [string]$TargetDocPath = ".\DOCS - ANEJOS\14.- Control de Calidad\Anexo 14 - Control de Calidad.docx",
    [string]$DonorDocPath = ".\DOCS - ANEJOS\Plantillas\Por Anejo\14-14-control-de-calidad\10_donor_docx\Anexo 14 - Control de calidad.docx",
    [string]$ReportPath = ".\CONTROL\repair_anexo14_tables_from_guadalmar.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$WordNs = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

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

function New-Ns {
    param([xml]$Document)

    $ns = New-Object System.Xml.XmlNamespaceManager($Document.NameTable)
    [void]$ns.AddNamespace("w", $WordNs)
    return $ns
}

function Get-Body {
    param([xml]$Document)

    foreach ($child in $Document.DocumentElement.ChildNodes) {
        if ($child.LocalName -eq "body") {
            return $child
        }
    }
    return $null
}

function Get-ParagraphText {
    param([System.Xml.XmlNode]$Paragraph)

    return (($Paragraph.SelectNodes('.//*[local-name()="t"]') | ForEach-Object { $_.InnerText }) -join '').Trim()
}

function Get-NextElementSibling {
    param([System.Xml.XmlNode]$Node)

    $candidate = $Node.NextSibling
    while ($null -ne $candidate -and $candidate.NodeType -ne [System.Xml.XmlNodeType]::Element) {
        $candidate = $candidate.NextSibling
    }
    return $candidate
}

function Import-NodeFromXml {
    param(
        [xml]$Document,
        [string]$OuterXml
    )

    [xml]$wrapper = "<root xmlns:w=`"$WordNs`">$OuterXml</root>"
    return $Document.ImportNode($wrapper.DocumentElement.FirstChild, $true)
}

function Get-DonorBlocks {
    param([xml]$Document)

    $ns = New-Ns -Document $Document
    $body = Get-Body -Document $Document
    $blocks = New-Object System.Collections.Generic.List[object]

    foreach ($child in @($body.ChildNodes)) {
        if ($child.LocalName -ne "p") {
            continue
        }

        $text = Get-ParagraphText -Paragraph $child
        if ($text -notmatch '^Tabla\s+([1-7])\.') {
            continue
        }

        $number = [int]$Matches[1]
        $tableNode = Get-NextElementSibling -Node $child
        while ($null -ne $tableNode -and $tableNode.LocalName -ne "tbl") {
            $tableNode = Get-NextElementSibling -Node $tableNode
        }
        if ($null -eq $tableNode) {
            throw "No se ha encontrado la tabla donor tras $text"
        }

        $blocks.Add([pscustomobject]@{
                Number = $number
                CaptionText = $text
                CaptionXml = $child.OuterXml
                TableXml = $tableNode.OuterXml
            }) | Out-Null
    }

    if ($blocks.Count -ne 7) {
        throw "Se esperaban 7 bloques donor y se han detectado $($blocks.Count)."
    }

    return @($blocks | Sort-Object Number)
}

function Get-TargetRanges {
    param([xml]$Document)

    $body = Get-Body -Document $Document
    $ranges = New-Object System.Collections.Generic.List[object]

    foreach ($child in @($body.ChildNodes)) {
        if ($child.LocalName -ne "p") {
            continue
        }

        $text = Get-ParagraphText -Paragraph $child
        if ($text -notmatch '^2\.([1-7])\.') {
            continue
        }

        $number = [int]$Matches[1]
        $firstNode = Get-NextElementSibling -Node $child
        if ($null -eq $firstNode) {
            throw "No hay bloque sustituible tras $text"
        }

        $current = $firstNode
        $tableNode = $null
        while ($null -ne $current) {
            if ($current.LocalName -eq "tbl") {
                $tableNode = $current
                break
            }
            $current = Get-NextElementSibling -Node $current
        }
        if ($null -eq $tableNode) {
            throw "No se ha encontrado la tabla destino tras $text"
        }

        $ranges.Add([pscustomobject]@{
                Number = $number
                HeadingText = $text
                FirstNode = $firstNode
                LastNode = $tableNode
            }) | Out-Null
    }

    if ($ranges.Count -ne 7) {
        throw "Se esperaban 7 bloques destino y se han detectado $($ranges.Count)."
    }

    return @($ranges | Sort-Object Number)
}

function Repair-Tables {
    param(
        [xml]$TargetDocument,
        [object[]]$DonorBlocks
    )

    $body = Get-Body -Document $TargetDocument
    $ranges = Get-TargetRanges -Document $TargetDocument
    $changes = New-Object System.Collections.Generic.List[string]

    foreach ($range in $ranges) {
        $donor = $DonorBlocks | Where-Object { $_.Number -eq $range.Number } | Select-Object -First 1
        if ($null -eq $donor) {
            throw "No existe donor para la tabla $($range.Number)."
        }

        $insertBefore = Get-NextElementSibling -Node $range.LastNode
        $current = $range.FirstNode
        while ($null -ne $current) {
            $next = Get-NextElementSibling -Node $current
            [void]$body.RemoveChild($current)
            if ($current -eq $range.LastNode) {
                break
            }
            $current = $next
        }

        $captionNode = Import-NodeFromXml -Document $TargetDocument -OuterXml $donor.CaptionXml
        $tableNode = Import-NodeFromXml -Document $TargetDocument -OuterXml $donor.TableXml

        if ($null -ne $insertBefore) {
            [void]$body.InsertBefore($captionNode, $insertBefore)
            [void]$body.InsertBefore($tableNode, $insertBefore)
        } else {
            [void]$body.AppendChild($captionNode)
            [void]$body.AppendChild($tableNode)
        }

        $changes.Add("Tabla $($range.Number): $($donor.CaptionText)") | Out-Null
    }

    return $changes.ToArray()
}

$targetResolved = Resolve-FullPathSafe -Path $TargetDocPath
$donorResolved = Resolve-FullPathSafe -Path $DonorDocPath
$reportResolved = Resolve-FullPathSafe -Path $ReportPath

$donorArchive = [System.IO.Compression.ZipFile]::OpenRead($donorResolved)
try {
    [xml]$donorDocument = Normalize-WordXmlText -XmlText (Read-ZipEntryText -Entry $donorArchive.GetEntry("word/document.xml"))
    $donorBlocks = Get-DonorBlocks -Document $donorDocument
} finally {
    $donorArchive.Dispose()
}

$targetArchive = [System.IO.Compression.ZipFile]::Open($targetResolved, [System.IO.Compression.ZipArchiveMode]::Update)
try {
    [xml]$targetDocument = Normalize-WordXmlText -XmlText (Read-ZipEntryText -Entry $targetArchive.GetEntry("word/document.xml"))
    $changes = Repair-Tables -TargetDocument $targetDocument -DonorBlocks $donorBlocks
    Write-ZipEntryText -Archive $targetArchive -EntryName "word/document.xml" -Content $targetDocument.OuterXml
} finally {
    $targetArchive.Dispose()
}

$reportDir = Split-Path -Path $reportResolved -Parent
if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Reparacion de tablas de Anexo 14 desde Guadalmar") | Out-Null
$lines.Add("") | Out-Null
foreach ($change in $changes) {
    $lines.Add("- $change") | Out-Null
}
[System.IO.File]::WriteAllLines($reportResolved, $lines, [System.Text.UTF8Encoding]::new($false))

[pscustomobject]@{
    Target = $targetResolved
    Donor = $donorResolved
    TablesRepaired = $changes.Count
}
