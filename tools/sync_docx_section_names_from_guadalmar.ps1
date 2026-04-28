param(
    [string]$SourceRoot = "..\MEJORA CARRETERA GUADALMAR\PROYECTO 535\535.2\535.2.2 Mejora Carretera Guadalmar\POU 2026\DOCS\Documentos de Trabajo",
    [string]$TargetRoot = ".\DOCS - ANEJOS",
    [string]$ReportPath = ".\CONTROL\guadalmar_docx_structure_sync.md"
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

function New-WordNamespaceManager {
    param([xml]$Document)

    $ns = New-Object System.Xml.XmlNamespaceManager($Document.NameTable)
    $ns.AddNamespace("w", "http://schemas.openxmlformats.org/wordprocessingml/2006/main")
    return $ns
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

    $styleNode = $null
    foreach ($child in $Paragraph.ChildNodes) {
        if ($child.LocalName -ne "pPr") {
            continue
        }
        foreach ($subChild in $child.ChildNodes) {
            if ($subChild.LocalName -eq "pStyle") {
                $styleNode = $subChild
                break
            }
        }
        if ($null -ne $styleNode) {
            break
        }
    }
    if ($null -eq $styleNode) {
        return ""
    }
    return $styleNode.GetAttribute("val", "http://schemas.openxmlformats.org/wordprocessingml/2006/main")
}

function Test-StructuralParagraph {
    param([System.Xml.XmlElement]$Paragraph)

    if ($Paragraph.LocalName -ne "p") {
        return $false
    }

    $style = Get-ParagraphStyle -Paragraph $Paragraph
    return ($style -match '^(TDC|Ttulo|Titulo|Heading)')
}

function Test-TocParagraph {
    param([System.Xml.XmlElement]$Paragraph)

    $style = Get-ParagraphStyle -Paragraph $Paragraph
    return ($style -match '^TDC')
}

function Test-BodyHeadingParagraph {
    param([System.Xml.XmlElement]$Paragraph)

    $style = Get-ParagraphStyle -Paragraph $Paragraph
    return ($style -match '^(Ttulo|Titulo|Heading)')
}

function Test-AnnexTitleParagraph {
    param([System.Xml.XmlElement]$Paragraph)

    if (-not (Test-BodyHeadingParagraph -Paragraph $Paragraph)) {
        return $false
    }

    $style = Get-ParagraphStyle -Paragraph $Paragraph
    $text = Normalize-StructureText -Style $style -Text (Get-ParagraphText -Paragraph $Paragraph)
    return ($text -match '^(ANEJO|ANEXO)\b')
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
    if ($level -lt 2) {
        $level = 2
    }
    if ($level -gt 4) {
        $level = 4
    }
    return "TDC$level"
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

function Normalize-StructureText {
    param(
        [string]$Style,
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $normalized = ($Text -replace '\s+', ' ').Trim()
    if ($Style -match '^TDC') {
        $normalized = $normalized -replace '\s*\d+$', ''
    }
    return $normalized.Trim()
}

function Get-BodyParagraphNodes {
    param([xml]$Document)

    $paragraphs = New-Object System.Collections.Generic.List[System.Xml.XmlElement]
    foreach ($node in $Document.GetElementsByTagName("w:p")) {
        if ($node -isnot [System.Xml.XmlElement]) {
            continue
        }
        if ($node.ParentNode -eq $null -or $node.ParentNode.LocalName -ne "body") {
            continue
        }
        $paragraphs.Add($node) | Out-Null
    }

    return $paragraphs.ToArray()
}

function Get-TocParagraphNodes {
    param([xml]$Document)

    $paragraphs = New-Object System.Collections.Generic.List[System.Xml.XmlElement]
    foreach ($node in $Document.GetElementsByTagName("w:p")) {
        if ($node -isnot [System.Xml.XmlElement]) {
            continue
        }
        if (Test-TocParagraph -Paragraph $node) {
            $paragraphs.Add($node) | Out-Null
        }
    }

    return $paragraphs.ToArray()
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

function Get-SourceStructureData {
    param([System.IO.FileInfo]$DocFile)

    $zipHandle = Open-ZipReadArchiveRobust -File $DocFile
    $stream = $zipHandle.Stream
    $zip = $zipHandle.Archive
    try {
        $entry = $zip.GetEntry("word/document.xml")
        if ($null -eq $entry) {
            throw "No se ha encontrado word/document.xml en $($DocFile.FullName)"
        }
        [xml]$document = Normalize-WordXmlText -XmlText (Read-ZipEntryText -Entry $entry)
    } finally {
        $zip.Dispose()
        $stream.Dispose()
    }

    $bodyHeadings = New-Object System.Collections.Generic.List[object]
    foreach ($paragraph in Get-BodyParagraphNodes -Document $document) {
        if (-not (Test-BodyHeadingParagraph -Paragraph $paragraph)) {
            continue
        }

        $style = Get-ParagraphStyle -Paragraph $paragraph
        $text = Normalize-StructureText -Style $style -Text (Get-ParagraphText -Paragraph $paragraph)
        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }
        if (Test-AnnexTitleParagraph -Paragraph $paragraph) {
            continue
        }

        $bodyHeadings.Add([pscustomobject]@{
            Style = $style
            Text = $text
            Node = $paragraph
        }) | Out-Null
    }

    $tocEntries = New-Object System.Collections.Generic.List[object]
    foreach ($heading in $bodyHeadings) {
        $tocEntries.Add([pscustomobject]@{
            Style = Get-TocStyleForHeadingStyle -HeadingStyle $heading.Style
            Text = $heading.Text
        }) | Out-Null
    }

    return [pscustomobject]@{
        BodyHeadings = $bodyHeadings.ToArray()
        TocEntries = $tocEntries.ToArray()
    }
}

function Get-CanonicalSourceDoc {
    param([System.IO.DirectoryInfo]$SourceFolder)

    $badNamePattern = '(?i)MAQUETADO|ACTUALIZADO|PRE_|\.pre_|TABLAS_RESTANTES|TEMPORAL|NORMAS T[ÉE]CNICAS|LEVANTAMIENTO'
    $candidates = Get-ChildItem -LiteralPath $SourceFolder.FullName -File -Filter "*.docx" |
        Where-Object { $_.Name -notmatch '^~\$' }

    $preferred = @($candidates | Where-Object { $_.Name -notmatch $badNamePattern } | Sort-Object Name)
    if ($preferred.Count -gt 0) {
        return $preferred[0]
    }

    $fallback = @($candidates | Sort-Object Name)
    if ($fallback.Count -gt 0) {
        return $fallback[0]
    }

    return $null
}

function Sync-TargetDocStructure {
    param(
        [System.IO.FileInfo]$TargetDocFile,
        [object[]]$SourceBodyHeadings,
        [object[]]$SourceTocEntries
    )

    if ($SourceBodyHeadings.Count -eq 0) {
        throw "No se ha detectado estructura reutilizable en $($TargetDocFile.FullName)"
    }

    $stream = Open-FileStreamRobust -File $TargetDocFile -Mode ([System.IO.FileMode]::Open) -Access ([System.IO.FileAccess]::ReadWrite) -Share ([System.IO.FileShare]::Read)
    $zip = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Update, $false)
    try {
        $entry = $zip.GetEntry("word/document.xml")
        if ($null -eq $entry) {
            throw "No se ha encontrado word/document.xml en $($TargetDocFile.FullName)"
        }

        [xml]$document = Normalize-WordXmlText -XmlText (Read-ZipEntryText -Entry $entry)
        $body = Get-DocumentBody -Document $document
        if ($null -eq $body) {
            throw "No se ha encontrado w:body en $($TargetDocFile.FullName)"
        }

        $sectPr = $null
        foreach ($child in @($body.ChildNodes)) {
            if ($child.LocalName -eq "sectPr") {
                $sectPr = $child
            }
        }

        $tocSdt = $null
        $tocContent = $null
        $tocTemplate = $null
        foreach ($child in @($body.ChildNodes)) {
            if ($child.LocalName -ne "sdt") {
                continue
            }
            $candidateParagraphs = @($child.GetElementsByTagName("w:p") | Where-Object { $_ -is [System.Xml.XmlElement] -and (Test-TocParagraph -Paragraph $_) })
            if ($candidateParagraphs.Count -eq 0) {
                continue
            }
            $tocSdt = $child
            $tocTemplate = $candidateParagraphs[0]
            foreach ($sdtChild in $child.ChildNodes) {
                if ($sdtChild.LocalName -eq "sdtContent") {
                    $tocContent = $sdtChild
                    break
                }
            }
            break
        }

        if ($null -ne $tocContent -and $null -ne $tocTemplate) {
            foreach ($node in @($tocContent.ChildNodes)) {
                [void]$tocContent.RemoveChild($node)
            }

            foreach ($tocEntry in $SourceTocEntries) {
                $paragraph = $document.ImportNode($tocTemplate, $true)
                Set-ParagraphStyle -Paragraph $paragraph -Style $tocEntry.Style
                Set-ParagraphText -Paragraph $paragraph -Text $tocEntry.Text
                [void]$tocContent.AppendChild($paragraph)
            }
        }

        $firstBodyHeading = $null
        $lastTocBodyNode = $null
        foreach ($child in @($body.ChildNodes)) {
            if ($child.LocalName -eq "sdt" -and $child -eq $tocSdt) {
                $lastTocBodyNode = $child
                continue
            }
            if ($child.LocalName -eq "p" -and (Test-BodyHeadingParagraph -Paragraph $child)) {
                $firstBodyHeading = $child
                break
            }
        }

        if ($null -ne $lastTocBodyNode -and $null -ne $firstBodyHeading) {
            $cleanupNodes = New-Object System.Collections.Generic.List[System.Xml.XmlNode]
            $capture = $false
            foreach ($child in @($body.ChildNodes)) {
                if ($child -eq $lastTocBodyNode) {
                    $capture = $true
                    continue
                }
                if (-not $capture) {
                    continue
                }
                if ($child -eq $firstBodyHeading) {
                    break
                }
                if ($child.LocalName -eq "p") {
                    $cleanupNodes.Add($child) | Out-Null
                }
            }
            foreach ($node in $cleanupNodes) {
                [void]$body.RemoveChild($node)
            }
        }

        $bodyHeadingNodes = New-Object System.Collections.Generic.List[System.Xml.XmlNode]
        foreach ($child in @($body.ChildNodes)) {
            if ($child.LocalName -eq "p" -and (Test-BodyHeadingParagraph -Paragraph $child)) {
                $bodyHeadingNodes.Add($child) | Out-Null
            }
        }
        foreach ($node in $bodyHeadingNodes) {
            [void]$body.RemoveChild($node)
        }

        foreach ($sourceParagraph in $SourceBodyHeadings) {
            $imported = $document.ImportNode($sourceParagraph.Node, $true)
            if ($imported.LocalName -eq "p") {
                Set-ParagraphText -Paragraph $imported -Text $sourceParagraph.Text
            }
            if ($null -ne $sectPr) {
                [void]$body.InsertBefore($imported, $sectPr)
            } else {
                [void]$body.AppendChild($imported)
            }
        }

        Write-ZipEntryText -Archive $zip -EntryName "word/document.xml" -Content $document.OuterXml
    } finally {
        $zip.Dispose()
        $stream.Dispose()
    }
}

$sourceResolved = Resolve-FullPathSafe -Path $SourceRoot
$targetResolved = Resolve-FullPathSafe -Path $TargetRoot
$reportResolved = Resolve-FullPathSafe -Path $ReportPath

if (-not (Test-Path -LiteralPath $sourceResolved)) {
    throw "No existe SourceRoot: $SourceRoot"
}
if (-not (Test-Path -LiteralPath $targetResolved)) {
    throw "No existe TargetRoot: $TargetRoot"
}

$reportDir = Split-Path -Parent $reportResolved
if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

$sourceFolders = Get-ChildItem -LiteralPath $sourceResolved -Directory |
    Where-Object { $_.Name -match '^\d+\.-' }
$targetFolders = Get-ChildItem -LiteralPath $targetResolved -Directory |
    Where-Object { $_.Name -match '^\d+\.-' } |
    Sort-Object { [int](($_.Name -split '\.-', 2)[0]) }

$reportRows = New-Object System.Collections.Generic.List[object]

foreach ($targetFolder in $targetFolders) {
    $annexNumber = [int](($targetFolder.Name -split '\.-', 2)[0])
    $sourceFolder = $sourceFolders | Where-Object { $_.Name -match ("^{0}\.-" -f $annexNumber) } | Select-Object -First 1
    if ($null -eq $sourceFolder) {
        $reportRows.Add([pscustomobject]@{
            Anejo = $targetFolder.Name
            Estado = "WARN"
            Fuente = ""
            Destino = ""
            Apartados = 0
            Incidencia = "Sin carpeta homologa en Guadalmar"
        }) | Out-Null
        continue
    }

    $sourceDoc = Get-CanonicalSourceDoc -SourceFolder $sourceFolder
    $targetDoc = Get-ChildItem -LiteralPath $targetFolder.FullName -File -Filter "*.docx" |
        Where-Object { $_.Name -notmatch '^~\$' } |
        Sort-Object Name |
        Select-Object -First 1

    if ($null -eq $sourceDoc -or $null -eq $targetDoc) {
        $reportRows.Add([pscustomobject]@{
            Anejo = $targetFolder.Name
            Estado = "WARN"
            Fuente = if ($sourceDoc) { $sourceDoc.FullName } else { "" }
            Destino = if ($targetDoc) { $targetDoc.FullName } else { "" }
            Apartados = 0
            Incidencia = "No se ha podido resolver origen o destino"
        }) | Out-Null
        continue
    }

    try {
        $sourceStructure = Get-SourceStructureData -DocFile $sourceDoc
        if ($sourceStructure.BodyHeadings.Count -eq 0) {
            $reportRows.Add([pscustomobject]@{
                Anejo = $targetFolder.Name
                Estado = "WARN"
                Fuente = $sourceDoc.FullName
                Destino = $targetDoc.FullName
                Apartados = 0
                Incidencia = "El DOCX origen no aporta apartados estructurados reutilizables"
            }) | Out-Null
            continue
        }

        Sync-TargetDocStructure -TargetDocFile $targetDoc -SourceBodyHeadings $sourceStructure.BodyHeadings -SourceTocEntries $sourceStructure.TocEntries
        $reportRows.Add([pscustomobject]@{
            Anejo = $targetFolder.Name
            Estado = "OK"
            Fuente = $sourceDoc.FullName
            Destino = $targetDoc.FullName
            Apartados = $sourceStructure.BodyHeadings.Count
            Incidencia = ""
        }) | Out-Null
    } catch {
        $reportRows.Add([pscustomobject]@{
            Anejo = $targetFolder.Name
            Estado = "WARN"
            Fuente = $sourceDoc.FullName
            Destino = $targetDoc.FullName
            Apartados = 0
            Incidencia = $_.Exception.Message
        }) | Out-Null
    }
}

$md = New-Object System.Collections.Generic.List[string]
[void]$md.Add("# Sincronizacion de apartados DOCX desde Guadalmar")
[void]$md.Add("")
[void]$md.Add("- Fecha: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))")
[void]$md.Add("- Solo se han sincronizado nombres de apartados e indice estructural; no se ha copiado redaccion tecnica donor.")
[void]$md.Add("")
[void]$md.Add("| Anejo | Estado | Apartados importados | Fuente | Destino | Incidencia |")
[void]$md.Add("|---|---|---:|---|---|---|")
foreach ($row in $reportRows) {
    [void]$md.Add("| $($row.Anejo) | $($row.Estado) | $($row.Apartados) | $($row.Fuente) | $($row.Destino) | $($row.Incidencia) |")
}
$md | Set-Content -LiteralPath $reportResolved -Encoding UTF8

$reportRows
