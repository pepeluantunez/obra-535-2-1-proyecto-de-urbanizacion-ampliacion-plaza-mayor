param(
    [Parameter(Mandatory = $true)]
    [string[]]$Paths
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.IO.Compression.FileSystem

$officeExtensions = @('.docx', '.docm', '.xlsx', '.xlsm', '.pptx', '.pptm')
$suspiciousTokens = @(
    [string][char]0x00C3,
    [string][char]0x00C2,
    [string][char]0x00E2,
    [string][char]0xFFFD,
    (([string][char]0x00EF) + [char]0x00BF + [char]0x00BD),
    'URBANIZACI?N',
    'M?LAGA',
    '?NDICE',
    'N.?',
    'n.?',
    'ejecuci?n',
    'elaboraci?n',
    'geod?sico',
    'Geod?sico',
    'Espa?a',
    'verificaci?n',
    'Instrucci?n',
    'geom?trico',
    'Elevaci?n',
    'Inclinaci?n',
    'iluminaci?n',
    'C?ncavo'
)

function Resolve-OfficeFiles {
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
                Where-Object { $_.Extension.ToLowerInvariant() -in $officeExtensions } |
                ForEach-Object { $resolved += $_.FullName }
            continue
        }

        if ($item.Extension.ToLowerInvariant() -notin $officeExtensions) {
            throw "Extension no soportada para control Office: $($item.FullName)"
        }

        $resolved += $item.FullName
    }

    return @($resolved | Sort-Object -Unique)
}

function Get-ZipText {
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

function Get-VisibleOfficeText {
    param(
        [string]$Extension,
        [hashtable]$EntryMap
    )

    $chunks = @()
    $regex = switch ($Extension) {
        '.docx' { '<w:t[^>]*>(.*?)</w:t>' }
        '.docm' { '<w:t[^>]*>(.*?)</w:t>' }
        '.xlsx' { '<t[^>]*>(.*?)</t>' }
        '.xlsm' { '<t[^>]*>(.*?)</t>' }
        '.pptx' { '<a:t>(.*?)</a:t>' }
        '.pptm' { '<a:t>(.*?)</a:t>' }
        default { return '' }
    }

    foreach ($entryName in ($EntryMap.Keys | Sort-Object)) {
        foreach ($match in [regex]::Matches($EntryMap[$entryName], $regex)) {
            $decoded = [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
            if (-not [string]::IsNullOrWhiteSpace($decoded)) {
                $chunks += $decoded
            }
        }
    }

    return ($chunks -join ' ')
}

function Find-SuspiciousContent {
    param(
        [string]$Text,
        [string]$Scope,
        [string[]]$Tokens
    )

    $results = @()
    $lineNumber = 0
    foreach ($line in ($Text -split "`r?`n")) {
        $lineNumber++
        foreach ($token in $Tokens) {
            if (-not $line.Contains($token)) { continue }
            $snippet = $line.Trim()
            if ($snippet.Length -gt 180) {
                $snippet = $snippet.Substring(0, 180)
            }
            $results += [pscustomobject]@{
                Scope = $Scope
                Line = $lineNumber
                Token = $token
                Snippet = $snippet
            }
        }
    }
    return @($results)
}

$files = @(Resolve-OfficeFiles -InputPaths $Paths)
if ($files.Count -eq 0) {
    throw 'No se han encontrado archivos Office compatibles.'
}

$hasFailures = $false
foreach ($file in $files) {
    $entryMap = @{}
    $archive = [System.IO.Compression.ZipFile]::OpenRead($file)
    try {
        foreach ($entry in $archive.Entries) {
            if ($entry.FullName -notmatch '^(word|xl|ppt)/.*\.xml$') { continue }
            $entryMap[$entry.FullName] = Get-ZipText -Entry $entry
        }
    } finally {
        $archive.Dispose()
    }

    $findings = @()
    foreach ($entryName in ($entryMap.Keys | Sort-Object)) {
        foreach ($finding in (Find-SuspiciousContent -Text $entryMap[$entryName] -Scope $entryName -Tokens $suspiciousTokens)) {
            $findings += $finding
        }
    }

    $visibleText = Get-VisibleOfficeText -Extension ([System.IO.Path]::GetExtension($file).ToLowerInvariant()) -EntryMap $entryMap
    foreach ($finding in (Find-SuspiciousContent -Text $visibleText -Scope 'visible-text-estimate' -Tokens $suspiciousTokens)) {
        $findings += $finding
    }

    if ($findings.Count -eq 0) {
        Write-Output "OK OFFICE: $file"
        continue
    }

    $hasFailures = $true
    Write-Output "FALLO OFFICE: $file"
    foreach ($finding in ($findings | Select-Object -First 25)) {
        Write-Output ("  [{0}:{1}] token='{2}' texto='{3}'" -f $finding.Scope, $finding.Line, $