param(
    [Parameter(Mandatory = $true)]
    [string[]]$Paths,
    [int]$StartNumber = 1,
    [string]$CaptionPrefix = 'Tabla',
    [string]$DefaultDescription = 'Descripcion',
    [bool]$UseMontserrat = $true,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.IO.Compression.FileSystem

$docExtensions = @('.docx', '.docm')

function Resolve-DocFiles {
    param([string[]]$InputPaths)

    $resolved = @()
    foreach ($inputPath in $InputPaths) {
        $absolute = if ([System.IO.Path]::IsPathRooted($inputPath)) { $inputPath } else { Join-Path (Get-Location) $inputPath }
        if (-not (Test-Path -LiteralPath $absolute)) { throw "No existe la ruta: $inputPath" }

        $item = Get-Item -LiteralPath $absolute
        if ($item.PSIsContainer) {
            Get-ChildItem -LiteralPath $item.FullName -Recurse -File |
                Where-Object { $_.Extension.ToLowerInvariant() -in $docExtensions } |
                ForEach-Object { $resolved += $_.FullName }
        } else {
            if ($item.Extension.ToLowerInvariant() -notin $docExtensions) {
                throw "Extension no soportada para autofix de captions: $($item.FullName)"
            }
            $resolved += $item.FullName
        }
    }
    return @($resolved | Sort-Object -Unique)
}

function Read-ZipEntryText {
    param([System.IO.Compression.ZipArchiveEntry]$Entry)
    $stream = $Entry.Open()
    try {
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true)
        try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
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
    $entry = $Archive.CreateEntry($EntryName)
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

function Get-ParagraphText {
    param([string]$ParagraphXml)
    $parts = @()
    foreach ($m in [regex]::Matches($ParagraphXml, '<w:t(?:\s[^>]*)?>(.*?)</w:t>')) {
        $txt = [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value)
        if (-not [string]::IsNullOrWhiteSpace($txt)) { $parts += $txt.Trim() }
    }
    return ($parts -join ' ').Trim()
}

function Get-CaptionNumber {
    param(
        [string]$Text,
        [string]$Prefix
    )
    $pattern = '^\s*' + [regex]::Escape($Prefix) + '\s*(?:N[ºo.]?\s*)?(\d+)(?:[.\-:)]\s*|\s+)(.+)$'
    $m = [regex]::Match($Text, $pattern, 'IgnoreCase')
    if (-not $m.Success) { return $null }
    return [int]$m.Groups[1].Value
}

function New-CaptionParagraphXml {
    param(
        [string]$Prefix,
        [int]$Number,
        [string]$Description,
        [bool]$UseFont
    )
    $captionText = "{0} {1}. {2}" -f $Prefix, $Number, $Description
    $safeText = [System.Security.SecurityElement]::Escape($captionText)
    if ($UseFont) {
        return "<w:p><w:r><w:rPr><w:rFonts w:ascii=`"Montserrat`" w:hAnsi=`"Montserrat`" w:eastAsia=`"Montserrat`" w:cs=`"Montserrat`"/></w:rPr><w:t xml:space=`"preserve`">$safeText</w:t></w:r></w:p>"
    }
    return "<w:p><w:r><w:t xml:space=`"preserve`">$safeText</w:t></w:r></w:p>"
}

$files = @(Resolve-DocFiles -InputPaths $Paths)
if ($files.Count -eq 0) { throw 'No se han encontrado DOCX/DOCM para autofix.' }

foreach ($file in $files) {
    $archive = [System.IO.Compression.ZipFile]::Open($file, [System.IO.Compression.ZipArchiveMode]::Update)
    try {
        $docEntry = $archive.GetEntry('word/document.xml')
        if ($null -eq $docEntry) { throw "No existe word/document.xml en $file" }
        $documentXml = Read-ZipEntryText -Entry $docEntry

        $bodyMatch = [regex]::Match($documentXml, '(?s)(<w:body\b[^>]*>)(.*?)(</w:body>)')
        if (-not $bodyMatch.Success) { throw "No se ha podido localizar w:body en $file" }

        $bodyStart = $bodyMatch.Groups[1].Value
        $bodyInner = $bodyMatch.Groups[2].Value
        $bodyEnd = $bodyMatch.Groups[3].Value

        $nodeMatches = [regex]::Matches($bodyInner, '(?s)<w:p\b.*?</w:p>|<w:tbl\b.*?</w:tbl>')
        if ($nodeMatches.Count -eq 0) {
            Write-Output ("SIN CAMBIOS: {0} (sin nodos p/tbl detectables)" -f $file)
            continue
        }

        $maxExisting = $StartNumber - 1
        foreach ($m in $nodeMatches) {
            if (-not $m.Value.StartsWith('<w:p')) { continue }
            $txt = Get-ParagraphText -ParagraphXml $m.Value
            $n = Get-CaptionNumber -Text $txt -Prefix $CaptionPrefix
            if ($null -ne $n -and $n -gt $maxExisting) { $maxExisting = $n }
        }
        $nextNumber = $maxExisting + 1

        $sb = New-Object System.Text.StringBuilder
        $lastIndex = 0
        $lastNonEmptyParagraph = ''
        $tableCount = 0
        $inserted = 0

        foreach ($m in $nodeMatches) {
            [void]$sb.Append($bodyInner.Substring($lastIndex, $m.Index - $lastIndex))
            $nodeXml = $m.Value

            if ($nodeXml.StartsWith('<w:p')) {
                $txt = Get-ParagraphText -ParagraphXml $nodeXml
                if (-not [string]::IsNullOrWhiteSpace($txt)) {
                    $lastNonEmptyParagraph = $txt
                }
                [void]$sb.Append($nodeXml)
            } else {
                $tableCount++
                $hasCaption = $false
                if (-not [string]::IsNullOrWhiteSpace($lastNonEmptyParagraph)) {
                    $captionNum = Get-CaptionNumber -Text $lastNonEmptyParagraph -Prefix $CaptionPrefix
                    if ($null -ne $captionNum) { $hasCaption = $true }
                }

                if (-not $hasCaption) {
                    $captionXml = New-CaptionParagraphXml -Prefix $CaptionPrefix -Number $nextNumber -Description $DefaultDescription -UseFont $UseMontserrat
                    [void]$sb.Append($captionXml)
                    $lastNonEmptyParagraph = "{0} {1}. {2}" -f $CaptionPrefix, $nextNumber, $DefaultDescription
                    $nextNumber++
                    $inserted++
                }

                [void]$sb.Append($nodeXml)
            }
            $lastIndex = $m.Index + $m.Length
        }
        [void]$sb.Append($bodyInner.Substring($lastIndex))

        if ($inserted -eq 0) {
            Write-Output ("SIN CAMBIOS: {0} (tablas: {1}, captions ya presentes)" -f $file, $tableCount)
            continue
        }

        if ($WhatIf) {
            Write-Output ("WHATIF: {0} (tablas: {1}, captions a insertar: {2})" -f $file, $tableCount, $inserted)
            continue
        }

        $newBody = $bodyStart + $sb.ToString() + $bodyEnd
        $newDocumentXml = $documentXml.Substring(0, $bodyMatch.Index) + $newBody + $documentXml.Substring($bodyMatch.Index + $bodyMatch.Length)
        Write-ZipEntryText -Archive $archive -EntryName 'word/document.xml' -Content $newDocumentXml
        Write-Output ("OK: {0} (tablas: {1}, captions insertados: {2})" -f $file, $tableCount, $inserted)
    } finally {
        $archive.Dispose()
    }
}
