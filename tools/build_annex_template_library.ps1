param(
    [string]$ProfileConfig = ".\CONFIG\annex_template_profiles.json",
    [string]$OutputRoot,
    [string]$ReportPath = ".\CONTROL\annex_template_library.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Resolve-FullPathSafe {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
}

function Convert-ToSafeFolderName {
    param([string]$Text)

    $value = $Text.ToLowerInvariant()
    $value = $value.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $value.ToCharArray()) {
        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
        if ($category -eq [Globalization.UnicodeCategory]::NonSpacingMark) {
            continue
        }
        [void]$sb.Append($ch)
    }

    $plain = $sb.ToString().Normalize([Text.NormalizationForm]::FormC)
    $plain = $plain -replace '[^a-z0-9\- ]', ''
    $plain = $plain -replace '\s+', '-'
    $plain = $plain -replace '-+', '-'
    return $plain.Trim('-')
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        [void](New-Item -ItemType Directory -Path $Path -Force)
    }
}

function Copy-IfExists {
    param(
        [string]$SourcePath,
        [string]$DestinationFolder
    )

    if ([string]::IsNullOrWhiteSpace($SourcePath) -or -not (Test-Path -LiteralPath $SourcePath)) {
        return $null
    }

    Ensure-Directory -Path $DestinationFolder
    $targetPath = Join-Path $DestinationFolder ([System.IO.Path]::GetFileName($SourcePath))
    Copy-Item -LiteralPath $SourcePath -Destination $targetPath -Force
    return $targetPath
}

$configPath = Resolve-FullPathSafe -Path $ProfileConfig
if (-not (Test-Path -LiteralPath $configPath)) {
    throw "No se encuentra la configuracion de perfiles: $configPath"
}

$config = Get-Content -LiteralPath $configPath -Raw -Encoding utf8 | ConvertFrom-Json
$outputRootPath = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    Resolve-FullPathSafe -Path ([string]$config.default_output_root)
} else {
    Resolve-FullPathSafe -Path $OutputRoot
}
$reportFullPath = Resolve-FullPathSafe -Path $ReportPath
$masterTemplate = Resolve-FullPathSafe -Path ([string]$config.master_template)

Ensure-Directory -Path $outputRootPath
Ensure-Directory -Path (Split-Path -Parent $reportFullPath)

$rows = New-Object System.Collections.Generic.List[object]

foreach ($profile in $config.profiles) {
    $folderName = "{0:D2}-{1}" -f [int]$profile.number, (Convert-ToSafeFolderName -Text ([string]$profile.slug))
    $packageRoot = Join-Path $outputRootPath $folderName
    $masterRoot = Join-Path $packageRoot "00_master"
    $docxRoot = Join-Path $packageRoot "10_donor_docx"
    $excelRoot = Join-Path $packageRoot "20_donor_excel"
    $supportRoot = Join-Path $packageRoot "30_support"

    Ensure-Directory -Path $packageRoot

    $copiedMaster = Copy-IfExists -SourcePath $masterTemplate -DestinationFolder $masterRoot
    $copiedDocx = Copy-IfExists -SourcePath (Resolve-FullPathSafe -Path ([string]$profile.donor_docx)) -DestinationFolder $docxRoot

    $copiedExcels = New-Object System.Collections.Generic.List[string]
    foreach ($excel in @($profile.donor_excels)) {
        $copied = Copy-IfExists -SourcePath (Resolve-FullPathSafe -Path ([string]$excel)) -DestinationFolder $excelRoot
        if (-not [string]::IsNullOrWhiteSpace($copied)) {
            $copiedExcels.Add($copied) | Out-Null
        }
    }

    $copiedSupport = New-Object System.Collections.Generic.List[string]
    foreach ($support in @($profile.support_files)) {
        $copied = Copy-IfExists -SourcePath (Resolve-FullPathSafe -Path ([string]$support)) -DestinationFolder $supportRoot
        if (-not [string]::IsNullOrWhiteSpace($copied)) {
            $copiedSupport.Add($copied) | Out-Null
        }
    }

    $manifest = [ordered]@{
        number = [int]$profile.number
        slug = [string]$profile.slug
        title = [string]$profile.title
        family = [string]$profile.family
        reusability = [string]$profile.reusability
        notes = [string]$profile.notes
        variable_inputs = @($profile.variable_inputs)
        copied_assets = [ordered]@{
            master_template = $copiedMaster
            donor_docx = $copiedDocx
            donor_excels = $copiedExcels.ToArray()
            support_files = $copiedSupport.ToArray()
        }
    }

    $manifestPath = Join-Path $packageRoot "profile.manifest.json"
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding utf8

    $status = "OK"
    if ([string]::IsNullOrWhiteSpace($copiedDocx)) {
        $status = "WARN_NO_DOCX"
    }

    $rows.Add([pscustomobject]@{
            Number = [int]$profile.number
            Title = [string]$profile.title
            Status = $status
            PackageRoot = $packageRoot
            DocxCopied = -not [string]::IsNullOrWhiteSpace($copiedDocx)
            ExcelCount = $copiedExcels.Count
            SupportCount = $copiedSupport.Count
        }) | Out-Null
}

$md = New-Object System.Collections.Generic.List[string]
$null = $md.Add("# Biblioteca de plantillas donor por anejo")
$null = $md.Add("")
$null = $md.Add("- Fecha: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))")
$null = $md.Add("- Salida: $outputRootPath")
$null = $md.Add("")
$null = $md.Add("| Anejo | Estado | DOCX donor | Excels | Soportes | Paquete |")
$null = $md.Add("|---|---|---|---:|---:|---|")
foreach ($row in $rows | Sort-Object Number) {
    $docxText = if ($row.DocxCopied) { "si" } else { "no" }
    $null = $md.Add("| $($row.Number) | $($row.Status) | $docxText | $($row.ExcelCount) | $($row.SupportCount) | $($row.PackageRoot) |")
}

$md -join [Environment]::NewLine | Set-Content -LiteralPath $reportFullPath -Encoding utf8
Write-Output "Biblioteca construida en: $outputRootPath"
