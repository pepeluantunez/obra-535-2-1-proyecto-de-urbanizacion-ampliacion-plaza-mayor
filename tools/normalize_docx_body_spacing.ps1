param(
    [Parameter(Mandatory = $true)]
    [string[]]$Paths,
    [string]$ReferenceDocx = ".\DOCS - ANEJOS\Plantillas\Por Anejo\02-02-cartografia-topografia\10_donor_docx\Anexo 2 - Cartografia y Topografia.docx",
    [string]$ReferenceHeadingRegex = '^\s*2\.?\s*INFORMACI.*BASE\s*$',
    [string]$BodyBefore = "0",
    [string]$BodyAfter = "0",
    [string]$BodyLine = "288",
    [string]$BodyLineRule = "auto",
    [switch]$UseReferenceProfile,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$WordNs = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
$docExtensions = @(".docx", ".docm")

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
                    $_.Name -notmatch '_ORIG' -and
                    $_.Name -notmatch '_bak_' -and
                    $_.Name -notmatch '_bak' -and
                    $_.Name -notmatch '_BKP'
                } |
                Select-Object -ExpandProperty FullName
        } elseif ($item.Extension.ToLowerInvariant() -in $docExtensions) {
            if (
                $item.Name -notmatch '^~\$' -and
                $item.Name -notmatch '_ORIG' -and
                $item.Name -notmatch '_bak_' -and
                $item.Name -notmatch '_bak' -and
                $item.Name -notmatch '_BKP'
            ) {
                $resolved += $item.FullName
            }
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

function Get-ParagraphText {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns
    )
    $texts = @($Paragraph.SelectNodes(".//w:t", $Ns) | ForEach-Object { $_.InnerText })
    return (($texts -join "") -replace '\s+', ' ').Trim()
}

function Get-ParagraphStyle {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns
    )
    $styleNode = $Paragraph.SelectSingleNode("./w:pPr/w:pStyle", $Ns)
    if ($null -eq $styleNode) { return "" }
    return $styleNode.GetAttribute("val", $WordNs)
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

function Ensure-SpacingNode {
    param([System.Xml.XmlElement]$Paragraph)
    $pPr = Ensure-PPr -Paragraph $Paragraph
    foreach ($child in $pPr.ChildNodes) {
        if ($child.LocalName -eq "spacing") { return [System.Xml.XmlElement]$child }
    }
    $spacing = $Paragraph.OwnerDocument.CreateElement("w", "spacing", $WordNs)
    [void]$pPr.AppendChild($spacing)
    return $spacing
}

function Set-OrRemoveAttr {
    param(
        [System.Xml.XmlElement]$Element,
        [string]$AttrName,
        [string]$Value
    )

    $current = $Element.GetAttribute($AttrName, $WordNs)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        if (-not [string]::IsNullOrWhiteSpace($current)) {
            [void]$Element.RemoveAttribute($AttrName, $WordNs)
            return $true
        }
        return $false
    }

    if ($current -ne $Value) {
        [void]$Element.SetAttribute($AttrName, $WordNs, $Value)
        return $true
    }
    return $false
}

function Test-IsHeadingParagraph {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns
    )
    $style = Get-ParagraphStyle -Paragraph $Paragraph -Ns $Ns
    if ($style -match '^(Ttulo|Titulo|Heading)') { return $true }
    return $false
}

function Test-IsTocParagraph {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns
    )
    $style = Get-ParagraphStyle -Paragraph $Paragraph -Ns $Ns
    if ($style -match '^(TDC|TOC)') { return $true }

    $instrNodes = @($Paragraph.SelectNodes(".//w:instrText", $Ns))
    foreach ($instr in $instrNodes) {
        if ($instr.InnerText -match '(?i)\bTOC\b') { return $true }
    }
    return $false
}

function Test-IsCaptionParagraph {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns
    )
    $style = Get-ParagraphStyle -Paragraph $Paragraph -Ns $Ns
    if ($style -match '(?i)caption|leyenda') { return $true }

    $text = Get-ParagraphText -Paragraph $Paragraph -Ns $Ns
    if ([string]::IsNullOrWhiteSpace($text)) { return $false }
    return ($text -match '^\s*Tabla\s*(?:N[ºo.]?\s*)?\d+(?:[.\-:)]\s*|\s+).+')
}

function Get-ReferenceBodySpacing {
    param(
        [string]$DocxPath,
        [string]$HeadingRegex
    )

    $zip = [System.IO.Compression.ZipFile]::OpenRead($DocxPath)
    try {
        $docEntry = $zip.GetEntry("word/document.xml")
        if ($null -eq $docEntry) {
            throw "No existe word/document.xml en referencia: $DocxPath"
        }

        [xml]$doc = Read-ZipEntryText -Entry $docEntry
        $ns = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
        $ns.AddNamespace("w", $WordNs)

        $paragraphs = @($doc.SelectNodes("//w:body/w:p", $ns))
        $targetParagraph = $null

        for ($i = 0; $i -lt $paragraphs.Count; $i++) {
            $p = [System.Xml.XmlElement]$paragraphs[$i]
            $text = Get-ParagraphText -Paragraph $p -Ns $ns
            if ($text -notmatch $HeadingRegex) { continue }

            for ($j = $i + 1; $j -lt $paragraphs.Count; $j++) {
                $candidate = [System.Xml.XmlElement]$paragraphs[$j]
                $candidateText = Get-ParagraphText -Paragraph $candidate -Ns $ns
                if ([string]::IsNullOrWhiteSpace($candidateText)) { continue }
                if ($candidateText -match '^\s*\d+[\.\)]') { break }
                $targetParagraph = $candidate
                break
            }
            break
        }

        if ($null -eq $targetParagraph) {
            throw "No se encontró un párrafo de referencia tras el heading '$HeadingRegex' en $DocxPath"
        }

        $spacing = $targetParagraph.SelectSingleNode("./w:pPr/w:spacing", $ns)
        return [pscustomobject]@{
            Before = if ($spacing) { $spacing.GetAttribute("before", $WordNs) } else { "" }
            After = if ($spacing) { $spacing.GetAttribute("after", $WordNs) } else { "" }
            Line = if ($spacing) { $spacing.GetAttribute("line", $WordNs) } else { "" }
            LineRule = if ($spacing) { $spacing.GetAttribute("lineRule", $WordNs) } else { "" }
            ParagraphText = (Get-ParagraphText -Paragraph $targetParagraph -Ns $ns)
        }
    } finally {
        $zip.Dispose()
    }
}

function Get-PreviousNonEmptyParagraphIndex {
    param(
        [System.Xml.XmlElement[]]$Paragraphs,
        [System.Xml.XmlNamespaceManager]$Ns,
        [int]$Start
    )
    for ($i = $Start; $i -ge 0; $i--) {
        $txt = Get-ParagraphText -Paragraph $Paragraphs[$i] -Ns $Ns
        if (-not [string]::IsNullOrWhiteSpace($txt)) { return $i }
    }
    return -1
}

function Set-ParagraphSpacingProfile {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [string]$Before,
        [string]$After,
        [string]$Line,
        [string]$LineRule
    )

    $spacing = Ensure-SpacingNode -Paragraph $Paragraph
    $changed = $false
    if (Set-OrRemoveAttr -Element $spacing -AttrName "before" -Value $Before) { $changed = $true }
    if (Set-OrRemoveAttr -Element $spacing -AttrName "after" -Value $After) { $changed = $true }
    if (Set-OrRemoveAttr -Element $spacing -AttrName "line" -Value $Line) { $changed = $true }
    if (Set-OrRemoveAttr -Element $spacing -AttrName "lineRule" -Value $LineRule) { $changed = $true }
    return $changed
}

$profile = $null
if ($UseReferenceProfile) {
    $referencePath = Resolve-FullPathSafe -Path $ReferenceDocx
    if (-not (Test-Path -LiteralPath $referencePath)) {
        throw "No existe el DOCX de referencia: $ReferenceDocx"
    }
    $profile = Get-ReferenceBodySpacing -DocxPath $referencePath -HeadingRegex $ReferenceHeadingRegex
    Write-Output ("REFERENCE SPACING: before='{0}' after='{1}' line='{2}' lineRule='{3}'" -f $profile.Before, $profile.After, $profile.Line, $profile.LineRule)
} else {
    $profile = [pscustomobject]@{
        Before = $BodyBefore
        After = $BodyAfter
        Line = $BodyLine
        LineRule = $BodyLineRule
        ParagraphText = ""
    }
    Write-Output ("FIXED SPACING: before='{0}' after='{1}' line='{2}' lineRule='{3}'" -f $profile.Before, $profile.After, $profile.Line, $profile.LineRule)
}

$files = @(Resolve-DocFiles -InputPaths $Paths)
if ($files.Count -eq 0) {
    throw "No se han encontrado DOCX/DOCM para procesar."
}

foreach ($file in $files) {
    $archive = $null
    try {
        $archive = [System.IO.Compression.ZipFile]::Open($file, [System.IO.Compression.ZipArchiveMode]::Update)
        $docEntry = $archive.GetEntry("word/document.xml")
        if ($null -eq $docEntry) {
            Write-Output ("SKIP: {0} (sin word/document.xml)" -f $file)
            continue
        }

        [xml]$doc = Read-ZipEntryText -Entry $docEntry
        $ns = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
        $ns.AddNamespace("w", $WordNs)

        $changes = 0
        [System.Xml.XmlElement[]]$paragraphs = @($doc.SelectNodes("//w:body/w:p", $ns))
        foreach ($pNode in $paragraphs) {
            if ($pNode -isnot [System.Xml.XmlElement]) { continue }
            $p = [System.Xml.XmlElement]$pNode

            $text = Get-ParagraphText -Paragraph $p -Ns $ns
            if ([string]::IsNullOrWhiteSpace($text)) { continue }
            if (Test-IsTocParagraph -Paragraph $p -Ns $ns) { continue }
            if (Test-IsHeadingParagraph -Paragraph $p -Ns $ns) { continue }
            if (Test-IsCaptionParagraph -Paragraph $p -Ns $ns) { continue }

            if (Set-ParagraphSpacingProfile -Paragraph $p -Before $profile.Before -After $profile.After -Line $profile.Line -LineRule $profile.LineRule) { $changes++ }
        }

        # Portada/indice: mantener hueco visual entre
        # linea de proyecto -> linea de anejo -> indice.
        for ($i = 0; $i -lt $paragraphs.Count; $i++) {
            $currentText = Get-ParagraphText -Paragraph $paragraphs[$i] -Ns $ns
            if ([string]::IsNullOrWhiteSpace($currentText)) { continue }
            if ($currentText -notmatch '^(?i)ÍNDICE$|^(?i)INDICE$') { continue }

            $anejoIdx = Get-PreviousNonEmptyParagraphIndex -Paragraphs $paragraphs -Ns $ns -Start ($i - 1)
            if ($anejoIdx -ge 0) {
                if (Set-ParagraphSpacingProfile -Paragraph $paragraphs[$anejoIdx] -Before "0" -After "240" -Line $profile.Line -LineRule $profile.LineRule) { $changes++ }
            }

            $projectIdx = if ($anejoIdx -ge 0) { Get-PreviousNonEmptyParagraphIndex -Paragraphs $paragraphs -Ns $ns -Start ($anejoIdx - 1) } else { -1 }
            if ($projectIdx -ge 0) {
                if (Set-ParagraphSpacingProfile -Paragraph $paragraphs[$projectIdx] -Before "0" -After "240" -Line $profile.Line -LineRule $profile.LineRule) { $changes++ }
            }
        }

        if ($WhatIf) {
            Write-Output ("WHATIF BODY SPACING: {0} (ajustes potenciales: {1})" -f $file, $changes)
            continue
        }

        Write-ZipEntryText -Archive $archive -EntryName "word/document.xml" -Content $doc.OuterXml
        Write-Output ("OK BODY SPACING: {0} (ajustes: {1})" -f $file, $changes)
    } catch {
        Write-Output ("INCIDENCIA BODY SPACING: {0} :: {1}" -f $file, $_.Exception.Message)
    } finally {
        if ($null -ne $archive) { $archive.Dispose() }
    }
}
