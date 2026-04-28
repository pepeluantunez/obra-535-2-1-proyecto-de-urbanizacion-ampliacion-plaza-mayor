param(
    [string]$ProjectConfig = ".\CONFIG\proyecto.template.json",
    [string]$OrthographyConfig = ".\CONFIG\ortotipografia_tecnica_es.json",
    [string[]]$Paths = @(".\DOCS - ANEJOS", ".\DOCS - MEMORIA"),
    [string]$ReportPath = ".\CONTROL\fill_docx_project_placeholders.md"
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
    if ($Original.Length -gt 1 -and $Original.Substring(0, 1) -ceq $Original.Substring(0, 1).ToUpperInvariant() -and $Original.Substring(1) -ceq $Original.Substring(1).ToLowerInvariant()) {
        return (Get-Culture).TextInfo.ToTitleCase($Replacement)
    }
    return $Replacement
}

function Apply-OrthographyRules {
    param(
        [string]$Text,
        [object[]]$Rules
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $Text
    }

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

function Set-ParagraphText {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [string]$Text
    )

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

    $run = $document.CreateElement("w", "r", $WordNs)
    if ($null -ne $runProps) {
        [void]$run.AppendChild($runProps)
    }

    $textNode = $document.CreateElement("w", "t", $WordNs)
    $spaceAttribute = $document.CreateAttribute("xml", "space", $XmlNs)
    $spaceAttribute.Value = "preserve"
    [void]$textNode.Attributes.Append($spaceAttribute)
    $textNode.InnerText = $Text
    [void]$run.AppendChild($textNode)
    [void]$Paragraph.AppendChild($run)
}

function Get-ProjectHeading {
    param([object]$Config)

    $heading = [string]$Config.project_heading
    if (-not [string]::IsNullOrWhiteSpace($heading)) {
        return $heading
    }

    return "PROYECTO DE URBANIZACION"
}

function Get-ProjectCover {
    param([object]$Config)

    $cover = [string]$Config.project_cover
    if (-not [string]::IsNullOrWhiteSpace($cover)) {
        return $cover
    }

    $shortName = [string]$Config.short_name
    $municipality = [string]$Config.municipality
    $province = [string]$Config.province
    $location = if (-not [string]::IsNullOrWhiteSpace($municipality)) {
        $municipality
    } elseif (-not [string]::IsNullOrWhiteSpace($province)) {
        $province
    } else {
        ""
    }

    if (-not [string]::IsNullOrWhiteSpace($shortName) -and -not [string]::IsNullOrWhiteSpace($location)) {
        return ("{0}, {1}" -f $shortName, $location).ToUpperInvariant()
    }
    if (-not [string]::IsNullOrWhiteSpace($shortName)) {
        return $shortName.ToUpperInvariant()
    }
    return ([string]$Config.project_name).ToUpperInvariant()
}

function Get-PlanningLine {
    param(
        [object]$Config,
        [string]$ProjectCover
    )

    $municipality = [string]$Config.municipality
    if ([string]::IsNullOrWhiteSpace($municipality) -and -not [string]::IsNullOrWhiteSpace($ProjectCover) -and $ProjectCover.Contains(",")) {
        $municipality = ($ProjectCover.Split(",")[-1]).Trim()
    }

    if ([string]::IsNullOrWhiteSpace($municipality)) {
        return ""
    }

    return "DEL PGOU DE $municipality"
}

function Get-DocDisplayName {
    param([System.IO.FileInfo]$File)

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name).Trim()
    if ($baseName -match '^Memoria descriptiva\b') {
        return "MEMORIA DESCRIPTIVA"
    }
    if ($baseName -match '^(Anexo|Anejo)\s+(\d+)\s*-\s*(.+)$') {
        return ("ANEJO {0}. {1}" -f $Matches[2], $Matches[3].Trim().ToUpperInvariant())
    }

    return $baseName.ToUpperInvariant()
}

function Get-XmlPartEntries {
    param([System.IO.Compression.ZipArchive]$Archive)

    return @(
        $Archive.Entries | Where-Object {
            $_.FullName -eq "word/document.xml" -or
            $_.FullName -match '^word/header\d+\.xml$'
        }
    )
}

function Test-HeaderPlaceholderBlock {
    param([string[]]$Texts)

    if ($Texts.Count -lt 4) {
        return $false
    }

    return (
        $Texts[0] -eq (Get-ComparableText "PROYECTO (ORDINARIO) DE URBANIZACION") -and
        $Texts[1] -eq (Get-ComparableText "[NOMBRE DEL PROYECTO]") -and
        $Texts[2] -eq (Get-ComparableText "DEL PGOU DE [CIUDAD DEL PROYECTO]") -and
        $Texts[3] -eq (Get-ComparableText "[NOMBRE DEL DOCX]")
    )
}

function Test-ProjectHeaderBlock {
    param(
        [string[]]$Texts,
        [string]$ProjectHeading,
        [string]$ProjectName,
        [string]$PlanningLine,
        [string]$DocDisplayName
    )

    if ($Texts.Count -lt 4) {
        return $false
    }

    $headingTexts = @(
        (Get-ComparableText "PROYECTO ORDINARIO DE URBANIZACION"),
        (Get-ComparableText "PROYECTO (ORDINARIO) DE URBANIZACION"),
        (Get-ComparableText $ProjectHeading)
    )
    $nameTexts = @(
        (Get-ComparableText "[NOMBRE DEL PROYECTO]"),
        (Get-ComparableText $ProjectName)
    )
    $planningTexts = @(
        (Get-ComparableText "DEL PGOU DE [CIUDAD DEL PROYECTO]"),
        (Get-ComparableText $PlanningLine)
    )
    $docTexts = @(
        (Get-ComparableText "[NOMBRE DEL DOCX]"),
        (Get-ComparableText $DocDisplayName)
    )

    return ($headingTexts -contains $Texts[0]) -and ($nameTexts -contains $Texts[1]) -and ($planningTexts -contains $Texts[2]) -and ($docTexts -contains $Texts[3])
}

function Test-DonorCoverBlock {
    param([string[]]$Texts)

    if ($Texts.Count -lt 3) {
        return $false
    }

    $headingTexts = @(
        (Get-ComparableText "PROYECTO ORDINARIO DE URBANIZACION"),
        (Get-ComparableText "PROYECTO (ORDINARIO) DE URBANIZACION")
    )
    $coverTexts = @(
        (Get-ComparableText "MEJORA DE LA CARRETERA DE GUADALMAR, MALAGA")
    )

    $isAnnexPlaceholder = (
        ($Texts[2] -match '^ANEJO N' -and $Texts[2].Contains('TITULO DEL ANEJO')) -or
        $Texts[2] -eq (Get-ComparableText "[NOMBRE DEL DOCX]")
    )

    return ($headingTexts -contains $Texts[0]) -and ($coverTexts -contains $Texts[1]) -and $isAnnexPlaceholder
}

function Test-ProjectCoverBlock {
    param(
        [string[]]$Texts,
        [string]$ProjectHeading,
        [string]$ProjectCover,
        [string]$DocDisplayName
    )

    if ($Texts.Count -lt 3) {
        return $false
    }

    $headingTexts = @(
        (Get-ComparableText "PROYECTO ORDINARIO DE URBANIZACION"),
        (Get-ComparableText "PROYECTO (ORDINARIO) DE URBANIZACION"),
        (Get-ComparableText $ProjectHeading)
    )
    $coverTexts = @(
        (Get-ComparableText "MEJORA DE LA CARRETERA DE GUADALMAR, MALAGA"),
        (Get-ComparableText $ProjectCover)
    )
    $docTexts = @(
        (Get-ComparableText "[NOMBRE DEL DOCX]"),
        (Get-ComparableText $DocDisplayName)
    )

    return ($headingTexts -contains $Texts[0]) -and ($coverTexts -contains $Texts[1]) -and ($docTexts -contains $Texts[2])
}

function Update-ParagraphBlocks {
    param(
        [System.Xml.XmlElement[]]$Paragraphs,
        [string]$ProjectHeading,
        [string]$ProjectName,
        [string]$ProjectCover,
        [string]$PlanningLine,
        [string]$DocDisplayName
    )

    $changed = $false
    for ($i = 0; $i -lt $Paragraphs.Count; $i++) {
        $currentTexts = @()
        for ($offset = 0; $offset -lt 4 -and ($i + $offset) -lt $Paragraphs.Count; $offset++) {
            $currentTexts += (Get-ComparableText (Get-ParagraphText -Paragraph $Paragraphs[$i + $offset]))
        }

        if ((Test-HeaderPlaceholderBlock -Texts $currentTexts) -or (Test-ProjectHeaderBlock -Texts $currentTexts -ProjectHeading $ProjectHeading -ProjectName $ProjectName -PlanningLine $PlanningLine -DocDisplayName $DocDisplayName)) {
            Set-ParagraphText -Paragraph $Paragraphs[$i] -Text $ProjectHeading
            Set-ParagraphText -Paragraph $Paragraphs[$i + 1] -Text $ProjectName
            Set-ParagraphText -Paragraph $Paragraphs[$i + 2] -Text $PlanningLine
            Set-ParagraphText -Paragraph $Paragraphs[$i + 3] -Text $DocDisplayName
            $changed = $true
            $i += 3
            continue
        }

        if (($i + 2) -lt $Paragraphs.Count) {
            $coverTexts = @(
                (Get-ComparableText (Get-ParagraphText -Paragraph $Paragraphs[$i])),
                (Get-ComparableText (Get-ParagraphText -Paragraph $Paragraphs[$i + 1])),
                (Get-ComparableText (Get-ParagraphText -Paragraph $Paragraphs[$i + 2]))
            )
            if ((Test-DonorCoverBlock -Texts $coverTexts) -or (Test-ProjectCoverBlock -Texts $coverTexts -ProjectHeading $ProjectHeading -ProjectCover $ProjectCover -DocDisplayName $DocDisplayName)) {
                Set-ParagraphText -Paragraph $Paragraphs[$i] -Text $ProjectHeading
                Set-ParagraphText -Paragraph $Paragraphs[$i + 1] -Text $ProjectCover
                Set-ParagraphText -Paragraph $Paragraphs[$i + 2] -Text $DocDisplayName
                $changed = $true
                $i += 2
            }
        }
    }

    return $changed
}

function Update-SingleParagraphs {
    param(
        [System.Xml.XmlElement[]]$Paragraphs,
        [string]$ProjectHeading,
        [string]$ProjectName,
        [string]$ProjectCover,
        [string]$PlanningLine,
        [string]$DocDisplayName
    )

    $changed = $false
    foreach ($paragraph in $Paragraphs) {
        $original = Get-ParagraphText -Paragraph $paragraph
        if ([string]::IsNullOrWhiteSpace($original)) {
            continue
        }

        $comparable = Get-ComparableText -Text $original
        $replacement = $null

        switch ($comparable) {
            { $_ -eq (Get-ComparableText "PROYECTO (ORDINARIO) DE URBANIZACION") } { $replacement = $ProjectHeading; break }
            { $_ -eq (Get-ComparableText "PROYECTO ORDINARIO DE URBANIZACION") } { $replacement = $ProjectHeading; break }
            { $_ -eq (Get-ComparableText "[NOMBRE DEL PROYECTO]") } { $replacement = $ProjectName; break }
            { $_ -eq (Get-ComparableText "DEL PGOU DE [CIUDAD DEL PROYECTO]") } { $replacement = $PlanningLine; break }
            { $_ -eq (Get-ComparableText "[NOMBRE DEL DOCX]") } { $replacement = $DocDisplayName; break }
            { $_ -eq (Get-ComparableText "MEJORA DE LA CARRETERA DE GUADALMAR, MALAGA") } { $replacement = $ProjectCover; break }
            { $_ -match '^ANEJO N' -and $_.Contains('TITULO DEL ANEJO') } { $replacement = $DocDisplayName; break }
        }

        if ($null -ne $replacement -and $replacement -ne $original) {
            Set-ParagraphText -Paragraph $paragraph -Text $replacement
            $changed = $true
        }
    }

    return $changed
}

function Update-DocxFile {
    param(
        [System.IO.FileInfo]$File,
        [object]$Config,
        [object[]]$OrthographyRules
    )

    $projectHeading = Apply-OrthographyRules -Text (Get-ProjectHeading -Config $Config) -Rules $OrthographyRules
    $projectCover = Apply-OrthographyRules -Text (Get-ProjectCover -Config $Config) -Rules $OrthographyRules
    $projectName = Apply-OrthographyRules -Text ([string]$Config.project_name) -Rules $OrthographyRules
    $planningLine = Apply-OrthographyRules -Text (Get-PlanningLine -Config $Config -ProjectCover $projectCover) -Rules $OrthographyRules
    $docDisplayName = Apply-OrthographyRules -Text (Get-DocDisplayName -File $File) -Rules $OrthographyRules
    $modifiedParts = New-Object System.Collections.Generic.List[string]

    $archive = [System.IO.Compression.ZipFile]::Open($File.FullName, [System.IO.Compression.ZipArchiveMode]::Update)
    try {
        foreach ($entry in Get-XmlPartEntries -Archive $archive) {
            [xml]$document = Normalize-WordXmlText -XmlText (Read-ZipEntryText -Entry $entry)
            $paragraphs = @(
                $document.GetElementsByTagName("w:p") |
                Where-Object {
                    $_ -is [System.Xml.XmlElement] -and
                    -not [string]::IsNullOrWhiteSpace((Get-ParagraphText -Paragraph $_))
                }
            )
            if ($paragraphs.Count -eq 0) {
                continue
            }

            $partChanged = $false
            if (Update-ParagraphBlocks -Paragraphs $paragraphs -ProjectHeading $projectHeading -ProjectName $projectName -ProjectCover $projectCover -PlanningLine $planningLine -DocDisplayName $docDisplayName) {
                $partChanged = $true
            }
            if (Update-SingleParagraphs -Paragraphs $paragraphs -ProjectHeading $projectHeading -ProjectName $projectName -ProjectCover $projectCover -PlanningLine $planningLine -DocDisplayName $docDisplayName) {
                $partChanged = $true
            }

            if ($partChanged) {
                Write-ZipEntryText -Archive $archive -EntryName $entry.FullName -Content $document.OuterXml
                $modifiedParts.Add($entry.FullName) | Out-Null
            }
        }
    } finally {
        $archive.Dispose()
    }

    return [pscustomobject]@{
        Path = $File.FullName
        Modified = ($modifiedParts.Count -gt 0)
        Parts = $modifiedParts.ToArray()
    }
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
            if ($item.Extension -ieq ".docx" -and $item.Name -notmatch '^~\$') {
                $files.Add($item) | Out-Null
            }
            continue
        }

        foreach ($file in Get-ChildItem -LiteralPath $item.FullName -Recurse -File -Filter "*.docx") {
            if ($file.Name -match '^~\$') {
                continue
            }
            if ($file.Name -match '^_bak_' -or $file.Name -match 'backup') {
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

$projectConfigResolved = Resolve-FullPathSafe -Path $ProjectConfig
$orthographyConfigResolved = Resolve-FullPathSafe -Path $OrthographyConfig
$reportResolved = Resolve-FullPathSafe -Path $ReportPath
$workspaceRoot = (Get-Location).Path

$config = Get-Content -LiteralPath $projectConfigResolved -Raw -Encoding UTF8 | ConvertFrom-Json
$orthographyRules = Get-Content -LiteralPath $orthographyConfigResolved -Raw -Encoding UTF8 | ConvertFrom-Json
$targetFiles = Get-TargetFiles -InputPaths $Paths
$results = foreach ($file in $targetFiles) {
    Update-DocxFile -File $file -Config $config -OrthographyRules $orthographyRules
}

$reportLines = New-Object System.Collections.Generic.List[string]
$reportLines.Add("# Relleno de placeholders DOCX") | Out-Null
$reportLines.Add("") | Out-Null
$reportLines.Add("| Documento | Estado | Partes actualizadas |") | Out-Null
$reportLines.Add("| --- | --- | --- |") | Out-Null

foreach ($result in $results) {
    $state = if ($result.Modified) { "UPDATED" } else { "UNCHANGED" }
    $parts = if ($result.Parts.Count -gt 0) { ($result.Parts -join ", ") } else { "-" }
    $relativePath = $result.Path
    if ($relativePath.StartsWith($workspaceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relativePath = $relativePath.Substring($workspaceRoot.Length).TrimStart('\')
    }
    $reportLines.Add("| $relativePath | $state | $parts |") | Out-Null
}

$reportDirectory = Split-Path -Path $reportResolved -Parent
if (-not (Test-Path -LiteralPath $reportDirectory)) {
    New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
}
[System.IO.File]::WriteAllLines($reportResolved, $reportLines, [System.Text.UTF8Encoding]::new($false))

$results
