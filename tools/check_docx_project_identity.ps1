param(
    [Parameter(Mandatory = $true)]
    [string[]]$Paths,
    [string]$IdentityConfigPath = ".\CONFIG\project_identity_traceability.json",
    [string]$ReportPath = "",
    [switch]$IncludeDocument,
    [switch]$FailOnIssue
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

function Resolve-DocFiles {
    param([string[]]$InputPaths)

    $extensions = @(".docx", ".docm")
    $resolved = @()
    foreach ($inputPath in $InputPaths) {
        $absolute = Resolve-FullPathSafe -Path $inputPath
        if (-not (Test-Path -LiteralPath $absolute)) {
            throw "No existe la ruta: $inputPath"
        }

        $item = Get-Item -LiteralPath $absolute
        if ($item.PSIsContainer) {
            $resolved += Get-ChildItem -LiteralPath $item.FullName -Recurse -File |
                Where-Object { $_.Extension.ToLowerInvariant() -in $extensions -and $_.Name -notmatch '^~\$' } |
                Select-Object -ExpandProperty FullName
        } elseif ($item.Extension.ToLowerInvariant() -in $extensions) {
            $resolved += $item.FullName
        }
    }

    return @($resolved | Sort-Object -Unique)
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

function Get-PartKind {
    param([string]$EntryName)
    if ($EntryName -match '^word/header\d+\.xml$') { return "header" }
    if ($EntryName -match '^word/footer\d+\.xml$') { return "footer" }
    if ($EntryName -eq "word/document.xml") { return "document" }
    return ""
}

$configFullPath = Resolve-FullPathSafe -Path $IdentityConfigPath
if (-not (Test-Path -LiteralPath $configFullPath)) {
    throw "No existe la configuracion: $IdentityConfigPath"
}

$config = Get-Content -LiteralPath $configFullPath -Raw -Encoding utf8 | ConvertFrom-Json
$forbiddenTokens = @($config.forbidden_tokens | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
if ($forbiddenTokens.Count -eq 0) {
    throw "La configuracion no define forbidden_tokens."
}

$scanParts = @($config.scan_parts | ForEach-Object { ([string]$_).ToLowerInvariant().Trim() } | Where-Object { $_ })
if ($scanParts.Count -eq 0) {
    $scanParts = @("header", "footer")
}
if ($IncludeDocument -and $scanParts -notcontains "document") {
    $scanParts += "document"
}

$files = @(Resolve-DocFiles -InputPaths $Paths)
if ($files.Count -eq 0) {
    throw "No se han encontrado DOCX/DOCM para revisar."
}

$findings = New-Object System.Collections.Generic.List[object]

foreach ($file in $files) {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($file)
    try {
        foreach ($entry in $zip.Entries) {
            $kind = Get-PartKind -EntryName $entry.FullName
            if ([string]::IsNullOrWhiteSpace($kind) -or $scanParts -notcontains $kind) {
                continue
            }

            $xml = Read-ZipEntryText -Entry $entry
            foreach ($token in $forbiddenTokens) {
                if ($xml -match [Regex]::Escape([string]$token)) {
                    $findings.Add([pscustomobject]@{
                            archivo = $file
                            parte = $entry.FullName
                            tipo = $kind
                            token = [string]$token
                        }) | Out-Null
                }
            }
        }
    } finally {
        $zip.Dispose()
    }
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $reportFullPath = Resolve-FullPathSafe -Path $ReportPath
    $reportDir = Split-Path -Parent $reportFullPath
    if (-not (Test-Path -LiteralPath $reportDir)) {
        [void](New-Item -ItemType Directory -Path $reportDir -Force)
    }
    $findings | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportFullPath -Encoding utf8
}

if ($findings.Count -eq 0) {
    Write-Output "OK: sin incidencias de identidad de proyecto en las partes revisadas."
} else {
    $findings | Sort-Object archivo, parte, token
}

if ($FailOnIssue -and $findings.Count -gt 0) {
    throw "Se han detectado incidencias de identidad de proyecto."
}
