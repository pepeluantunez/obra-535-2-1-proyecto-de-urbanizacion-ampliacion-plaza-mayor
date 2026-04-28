param(
    [string[]]$Paths,
    [string]$ProjectName = "",
    [string]$OutputPath = "",
    [switch]$FailOnIssue
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Resolve-AbsolutePath {
    param([string]$Path)
    (Resolve-Path -LiteralPath $Path).Path
}

function Get-VisibleTextFromOfficeEntry {
    param(
        [System.IO.Compression.ZipArchive]$Zip,
        [string]$EntryName
    )

    $entry = $Zip.GetEntry($EntryName)
    if ($null -eq $entry) { return "" }
    $stream = $entry.Open()
    try {
        $reader = New-Object System.IO.StreamReader($stream)
        $xml = $reader.ReadToEnd()
    } finally {
        if ($reader) { $reader.Dispose() }
        if ($stream) { $stream.Dispose() }
    }
    $text = $xml -replace '</w:p>|</a:p>|</row>|</si>', "`n"
    $text = $text -replace '<[^>]+>', ' '
    $text = [System.Net.WebUtility]::HtmlDecode($text)
    $text = $text -replace '\s+', ' '
    $text.Trim()
}

function Get-TextFromPath {
    param([string]$Path)

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($extension) {
        ".docx" {
            $zip = $null
            try {
                $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
                return (Get-VisibleTextFromOfficeEntry -Zip $zip -EntryName "word/document.xml")
            } finally {
                if ($zip) { $zip.Dispose() }
            }
        }
        ".docm" {
            $zip = $null
            try {
                $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
                return (Get-VisibleTextFromOfficeEntry -Zip $zip -EntryName "word/document.xml")
            } finally {
                if ($zip) { $zip.Dispose() }
            }
        }
        ".xlsx" {
            $zip = $null
            try {
                $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
                $parts = @(
                    "xl/sharedStrings.xml",
                    "xl/workbook.xml"
                )
                $texts = foreach ($part in $parts) {
                    Get-VisibleTextFromOfficeEntry -Zip $zip -EntryName $part
                }
                return (($texts -join " ") -replace '\s+', ' ').Trim()
            } finally {
                if ($zip) { $zip.Dispose() }
            }
        }
        ".xlsm" {
            $zip = $null
            try {
                $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
                $parts = @(
                    "xl/sharedStrings.xml",
                    "xl/workbook.xml"
                )
                $texts = foreach ($part in $parts) {
                    Get-VisibleTextFromOfficeEntry -Zip $zip -EntryName $part
                }
                return (($texts -join " ") -replace '\s+', ' ').Trim()
            } finally {
                if ($zip) { $zip.Dispose() }
            }
        }
        default {
            return (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop)
        }
    }
}

function Test-DocumentNamePresence {
    param(
        [string]$BaseName,
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($BaseName)) {
        return $true
    }

    if ($Text -match [regex]::Escape($BaseName)) {
        return $true
    }

    if ($BaseName -match '(?i)^anexo\s+(\d+)\s*-\s*(.+)$') {
        $number = $matches[1]
        $title = ($matches[2] -replace '\s+', ' ').Trim()
        [object[]]$tokens = @($title -split '\s+' | Where-Object { $_.Length -ge 4 })
        $hasAnnexNumber = $Text -match "(?i)\b(anexo|anejo)\s+$number\b"
        $tokenMatches = @($tokens | Where-Object { $Text -match "(?i)\b$([regex]::Escape($_))\b" }).Count
        return ($hasAnnexNumber -and ($tokens.Count -eq 0 -or $tokenMatches -ge [Math]::Max(1, [Math]::Floor($tokens.Count / 2))))
    }

    return $false
}

if (-not $Paths -or $Paths.Count -eq 0) {
    throw "Debes indicar al menos una ruta en -Paths."
}

$resolvedFiles = New-Object System.Collections.Generic.List[string]
foreach ($inputPath in $Paths) {
    $absolute = Resolve-AbsolutePath -Path $inputPath
    if ((Get-Item -LiteralPath $absolute) -is [System.IO.DirectoryInfo]) {
        Get-ChildItem -LiteralPath $absolute -Recurse -File |
            Where-Object {
                $_.Extension.ToLowerInvariant() -in @(".docx", ".docm", ".xlsx", ".xlsm") -and
                $_.Name -notmatch '^~\$'
            } |
            ForEach-Object { $resolvedFiles.Add($_.FullName) | Out-Null }
    } else {
        $resolvedFiles.Add($absolute) | Out-Null
    }
}

$projectNameEffective = if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    (Split-Path -Path (Get-Location).Path -Leaf) -replace '^\d+(?:\.\d+)*\s*-\s*', ''
} else {
    $ProjectName.Trim()
}

$placeholderPattern = '(?i)\bpendiente\b|\bxxx\b|_{3,}|\[completar[^\]]*\]|nombre del proyecto|titulo del proyecto|insertar|lorem ipsum'
$results = New-Object System.Collections.Generic.List[object]

foreach ($file in ($resolvedFiles | Sort-Object -Unique)) {
    $text = Get-TextFromPath -Path $file
    $placeholderCount = if ([string]::IsNullOrWhiteSpace($text)) { 0 } else { [regex]::Matches($text, $placeholderPattern).Count }
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file)
    $missingProjectName = if ([string]::IsNullOrWhiteSpace($projectNameEffective)) { $false } else { -not ($text -match [regex]::Escape($projectNameEffective)) }
    $missingAnnexName = if ($baseName -match '(?i)^anexo') { -not (Test-DocumentNamePresence -BaseName $baseName -Text $text) } else { $false }
    $results.Add([pscustomobject]@{
        archivo = $file
        placeholders = $placeholderCount
        falta_nombre_proyecto = $missingProjectName
        falta_nombre_documento = $missingAnnexName
        incidencias = @(
            $(if ($placeholderCount -gt 0) { "$placeholderCount marcador(es)" }),
            $(if ($missingProjectName) { "no aparece el nombre del proyecto" }),
            $(if ($missingAnnexName) { "no aparece el nombre base del documento" })
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    }) | Out-Null
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputAbsolute = if ([System.IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path (Get-Location).Path $OutputPath }
    $results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $outputAbsolute -Encoding UTF8
}

$results

$hasIssues = @($results | Where-Object {
    $_.placeholders -gt 0 -or $_.falta_nombre_proyecto -or $_.falta_nombre_documento
}).Count -gt 0

if ($FailOnIssue -and $hasIssues) {
    throw "Se han detectado plantillas o documentos con huecos pendientes."
}
