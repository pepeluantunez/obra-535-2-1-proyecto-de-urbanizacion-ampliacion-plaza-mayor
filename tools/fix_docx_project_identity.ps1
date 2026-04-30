param(
    [Parameter(Mandatory = $true)]
    [string[]]$Paths,
    [string]$IdentityConfigPath = ".\CONFIG\project_identity_traceability.json",
    [switch]$IncludeDocument,
    [switch]$IncludeTemplates,
    [switch]$CreateBackup
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
                Where-Object {
                    $_.Extension.ToLowerInvariant() -in $extensions -and
                    $_.Name -notmatch '^~\$' -and
                    ($IncludeTemplates -or $_.FullName -notmatch '\\Plantillas\\') -and
                    ($IncludeTemplates -or $_.FullName -notmatch '\\10_donor_docx\\')
                } |
                Select-Object -ExpandProperty FullName
        } elseif ($item.Extension.ToLowerInvariant() -in $extensions) {
            if (-not $IncludeTemplates -and $item.FullName -match '\\Plantillas\\') { continue }
            if (-not $IncludeTemplates -and $item.FullName -match '\\10_donor_docx\\') { continue }
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
$rules = @($config.replacement_rules)
if ($rules.Count -eq 0) {
    throw "La configuracion no define replacement_rules."
}

$scanParts = @($config.scan_parts | ForEach-Object { ([string]$_).ToLowerInvariant().Trim() } | Where-Object { $_ })
if ($scanParts.Count -eq 0) {
    $scanParts = @("header", "footer")
}
if ($IncludeDocument -and $scanParts -notcontains "document") {
    $scanParts += "document"
}

$normalizedRules = New-Object System.Collections.Generic.List[object]
foreach ($rule in $rules) {
    $find = [string]$rule.find
    $replace = [string]$rule.replace
    if ([string]::IsNullOrWhiteSpace($find)) { continue }
    $parts = @($rule.parts | ForEach-Object { ([string]$_).ToLowerInvariant().Trim() } | Where-Object { $_ })
    if ($parts.Count -eq 0) { $parts = @("header", "footer") }
    if ($IncludeDocument -and $parts -notcontains "document") {
        $parts += "document"
    }
    $normalizedRules.Add([pscustomobject]@{
            find = $find
            replace = $replace
            parts = $parts
        }) | Out-Null
}

$files = @(Resolve-DocFiles -InputPaths $Paths)
if ($files.Count -eq 0) {
    throw "No se han encontrado DOCX/DOCM para corregir."
}

$changes = New-Object System.Collections.Generic.List[object]

foreach ($file in $files) {
    if ($CreateBackup) {
        $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupPath = Join-Path (Split-Path -Parent $file) ("{0}_bak_identity_{1}{2}" -f [System.IO.Path]::GetFileNameWithoutExtension($file), $stamp, [System.IO.Path]::GetExtension($file))
        Copy-Item -LiteralPath $file -Destination $backupPath -Force
    }

    $zip = $null
    try {
        $zip = [System.IO.Compression.ZipFile]::Open($file, [System.IO.Compression.ZipArchiveMode]::Update)
        foreach ($entry in @($zip.Entries)) {
            $kind = Get-PartKind -EntryName $entry.FullName
            if ([string]::IsNullOrWhiteSpace($kind) -or $scanParts -notcontains $kind) {
                continue
            }

            $xml = Read-ZipEntryText -Entry $entry
            $updated = $xml
            $countPart = 0

            foreach ($rule in $normalizedRules) {
                if ($rule.parts -notcontains $kind) { continue }
                $pattern = [Regex]::Escape([string]$rule.find)
                $before = [regex]::Matches($updated, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase).Count
                if ($before -eq 0) { continue }
                $updated = [regex]::Replace($updated, $pattern, [string]$rule.replace, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                $countPart += $before
            }

            if ($countPart -gt 0 -and $updated -ne $xml) {
                Write-ZipEntryText -Archive $zip -EntryName $entry.FullName -Content $updated
                $changes.Add([pscustomobject]@{
                        archivo = $file
                        parte = $entry.FullName
                        tipo = $kind
                        reemplazos = $countPart
                    }) | Out-Null
            }
        }
    } catch {
        Write-Output ("INCIDENCIA IDENTITY: {0} :: {1}" -f $file, $_.Exception.Message)
    } finally {
        if ($null -ne $zip) {
            $zip.Dispose()
        }
    }
}

if ($changes.Count -eq 0) {
    Write-Output "UNCHANGED: no se aplicaron reemplazos."
} else {
    $changes | Sort-Object archivo, parte
}
