param(
    [Parameter(Mandatory = $true)]
    [string[]]$Paths,
    [string]$ConfigPath = ".\CONFIG\ortotipografia_tecnica_es.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$docExtensions = @(".docx", ".docm")

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

function Open-ZipReadArchiveRobust {
    param([System.IO.FileInfo]$File)

    try {
        $stream = $File.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    } catch {
        $shortPath = Get-ShortPathIfAvailable -Path $File.FullName
        if ([string]::IsNullOrWhiteSpace($shortPath)) {
            throw
        }
        $stream = [System.IO.File]::Open($shortPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    }

    $archive = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Read, $false)
    return [pscustomobject]@{
        Stream = $stream
        Archive = $archive
    }
}

function Resolve-DocFiles {
    param([string[]]$InputPaths)

    $resolved = @()
    foreach ($inputPath in $InputPaths) {
        $absolute = if ([System.IO.Path]::IsPathRooted($inputPath)) {
            $inputPath
        } else {
            Join-Path (Get-Location) $inputPath
        }

        if (-not (Test-Path -LiteralPath $absolute)) {
            throw "No existe la ruta: $inputPath"
        }

        $item = Get-Item -LiteralPath $absolute
        if ($item.PSIsContainer) {
            Get-ChildItem -LiteralPath $item.FullName -Recurse -File |
                Where-Object { $_.Extension.ToLowerInvariant() -in $docExtensions } |
                ForEach-Object { $resolved += $_.FullName }
            continue
        }

        if ($item.Extension.ToLowerInvariant() -notin $docExtensions) {
            throw "Extension no soportada para revision ortotipografica: $($item.FullName)"
        }

        $resolved += $item.FullName
    }

    return @($resolved | Sort-Object -Unique)
}

function Read-ZipEntryText {
    param([System.IO.Compression.ZipArchiveEntry]$Entry)

    $stream = $Entry.Open()
    try {
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true)
        try {
            return $reader.ReadToEnd()
        } finally {
            $reader.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Normalize-VisibleText {
    param([string]$Xml)

    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($match in [regex]::Matches($Xml, '<w:t(?:\s[^>]*)?>(.*?)</w:t>')) {
        $decoded = [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
        if (-not [string]::IsNullOrWhiteSpace($decoded)) {
            $parts.Add($decoded.Trim())
        }
    }

    $text = ($parts -join " ")
    $text = $text -replace '\s+', ' '
    return $text.Trim()
}

function Get-MatchContext {
    param(
        [string]$Text,
        [int]$Index,
        [int]$Length
    )

    $start = [Math]::Max(0, $Index - 45)
    $end = [Math]::Min($Text.Length, $Index + $Length + 45)
    return $Text.Substring($start, $end - $start).Trim()
}

$configResolved = if ([System.IO.Path]::IsPathRooted($ConfigPath)) {
    $ConfigPath
} else {
    Join-Path (Get-Location) $ConfigPath
}

if (-not (Test-Path -LiteralPath $configResolved)) {
    throw "No existe ConfigPath: $ConfigPath"
}

$rules = Get-Content -LiteralPath $configResolved -Raw -Encoding UTF8 | ConvertFrom-Json
$files = @(Resolve-DocFiles -InputPaths $Paths)
if ($files.Count -eq 0) {
    throw "No se han encontrado DOCX o DOCM compatibles."
}

$hasIssues = $false
foreach ($file in $files) {
    $fileInfo = Get-Item -LiteralPath $file
    $zipHandle = Open-ZipReadArchiveRobust -File $fileInfo
    $archive = $zipHandle.Archive
    try {
        $entry = $archive.GetEntry("word/document.xml")
        if ($null -eq $entry) {
            throw "No existe word/document.xml en $file"
        }

        $visibleText = Normalize-VisibleText -Xml (Read-ZipEntryText -Entry $entry)
        $fileIssues = New-Object System.Collections.Generic.List[object]

        foreach ($rule in $rules) {
            $pattern = "(?i)(?<![\\p{L}])$([regex]::Escape($rule.bad))(?![\\p{L}])"
            foreach ($match in [regex]::Matches($visibleText, $pattern)) {
                $fileIssues.Add([pscustomobject]@{
                    Found = $match.Value
                    Suggestion = $rule.good
                    Context = Get-MatchContext -Text $visibleText -Index $match.Index -Length $match.Length
                }) | Out-Null
            }
        }

        if ($fileIssues.Count -eq 0) {
            Write-Output "OK ORTO: $file"
            continue
        }

        $hasIssues = $true
        foreach ($issue in $fileIssues | Select-Object -First 20) {
            Write-Output ("WARN ORTO: {0} | '{1}' -> '{2}' | {3}" -f $file, $issue.Found, $issue.Suggestion, $issue.Context)
        }
    } finally {
        $archive.Dispose()
        $zipHandle.Stream.Dispose()
    }
}

if ($hasIssues) {
    exit 1
}
