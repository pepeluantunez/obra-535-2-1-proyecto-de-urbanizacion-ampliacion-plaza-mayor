Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$script:ProjectTraceabilityEsCulture = [Globalization.CultureInfo]::GetCultureInfo('es-ES')

function Resolve-ProjectAbsolutePath {
    param([string]$InputPath)

    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        throw 'La ruta recibida esta vacia.'
    }

    if ([System.IO.Path]::IsPathRooted($InputPath)) {
        return [System.IO.Path]::GetFullPath($InputPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $InputPath))
}

function Resolve-ExistingProjectPath {
    param([string]$InputPath)

    $absolute = Resolve-ProjectAbsolutePath -InputPath $InputPath
    if (-not (Test-Path -LiteralPath $absolute)) {
        throw "No existe la ruta requerida: $InputPath"
    }

    return $absolute
}

function Get-ProjectTraceabilityConfig {
    param([string]$ConfigPath = '.\CONFIG\project_budget_traceability.json')

    $absolute = Resolve-ExistingProjectPath -InputPath $ConfigPath
    return Get-Content -LiteralPath $absolute -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Resolve-ExistingCandidatePaths {
    param([string[]]$Candidates)

    $resolved = New-Object System.Collections.Generic.List[string]
    foreach ($candidate in @($Candidates)) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }

        $absolute = Resolve-ProjectAbsolutePath -InputPath $candidate
        if (Test-Path -LiteralPath $absolute) {
            $resolved.Add($absolute) | Out-Null
        }
    }

    return @($resolved | Sort-Object -Unique)
}

function Resolve-FirstExistingCandidate {
    param([string[]]$Candidates)

    $resolved = @(Resolve-ExistingCandidatePaths -Candidates $Candidates)
    if ($resolved.Count -gt 0) {
        return $resolved[0]
    }

    return $null
}

function Expand-TemplateArguments {
    param(
        [string[]]$Arguments,
        [hashtable]$Variables
    )

    $expanded = @()
    foreach ($argument in @($Arguments)) {
        $value = [string]$argument
        foreach ($key in $Variables.Keys) {
            $value = $value.Replace('{' + $key + '}', [string]$Variables[$key])
        }
        $expanded += $value
    }

    return @($expanded)
}

function Invoke-PowerShellScriptFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [string[]]$Arguments = @()
    )

    & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Fallo al ejecutar $ScriptPath (exit code $LASTEXITCODE)."
    }
}

function Get-ZipEntryText {
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

function Get-OfficeVisibleText {
    param([string]$Path)

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $regex = switch ($extension) {
        '.docx' { '<w:t[^>]*>(.*?)</w:t>' }
        '.docm' { '<w:t[^>]*>(.*?)</w:t>' }
        '.xlsx' { '<t[^>]*>(.*?)</t>' }
        '.xlsm' { '<t[^>]*>(.*?)</t>' }
        default { throw "Extension Office no soportada: $Path" }
    }

    $texts = @()
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        foreach ($entry in $archive.Entries) {
            if ($entry.FullName -notmatch '^(word|xl)/.*\.xml$') {
                continue
            }

            $xml = Get-ZipEntryText -Entry $entry
            foreach ($match in [regex]::Matches($xml, $regex)) {
                $decoded = [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
                if (-not [string]::IsNullOrWhiteSpace($decoded)) {
                    $texts += $decoded
                }
            }
        }
    } finally {
        $archive.Dispose()
    }

    return ($texts -join ' ')
}

function Read-SearchableText {
    param([string]$Path)

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($extension -in @('.docx', '.docm', '.xlsx', '.xlsm')) {
        return Get-OfficeVisibleText -Path $Path
    }

    try {
        return Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    } catch {
        return Get-Content -LiteralPath $Path -Raw -Encoding Default
    }
}

function Normalize-SearchText {
    param([string]$Text)

    $normalized = [System.Net.WebUtility]::HtmlDecode($Text)
    $normalized = $normalized -replace '\s+', ' '
    return $normalized.Trim()
}

function Get-ProjectPemFromBc3 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Bc3Path,

        [string]$PreferredRootCode
    )

    $absolute = Resolve-ExistingProjectPath -InputPath $Bc3Path
    $records = New-Object System.Collections.Generic.List[object]
    foreach ($line in Get-Content -LiteralPath $absolute -Encoding Default) {
        if ($line -notlike '~C|*') {
            continue
        }

        $parts = $line.Split('|')
        if ($parts.Count -lt 5) {
            continue
        }

        $code = $parts[1].Trim()
        if (-not $code.EndsWith('##')) {
            continue
        }

        $value = 0.0
        $raw = $parts[4].Trim().Replace(',', '.')
        if (-not [double]::TryParse($raw, [Globalization.NumberStyles]::Any, [Globalization.CultureInfo]::InvariantCulture, [ref]$value)) {
            continue
        }

        $records.Add([pscustomobject]@{
            RootCode = $code
            Value = [math]::Round($value, 2)
        }) | Out-Null
    }

    if ($records.Count -eq 0) {
        throw "No se ha encontrado un concepto raiz '##' en el BC3: $absolute"
    }

    $selected = $null
    if (-not [string]::IsNullOrWhiteSpace($PreferredRootCode)) {
        $selected = $records | Where-Object { $_.RootCode -eq $PreferredRootCode } | Select-Object -First 1
    }
    if ($null -eq $selected) {
        $selected = $records[0]
    }

    return [pscustomobject]@{
        RootCode = $selected.RootCode
        Value = $selected.Value
        TextEs = $selected.Value.ToString('N2', $script:ProjectTraceabilityEsCulture)
        TextInvariant = $selected.Value.ToString('0.00', [Globalization.CultureInfo]::InvariantCulture)
        AbsolutePath = $absolute
    }
}
