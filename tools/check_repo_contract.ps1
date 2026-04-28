[CmdletBinding()]
param(
    [string]$ContractPath = ".\\CONFIG\\repo_contract.json",
    [string]$RootPath = "."
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-Result {
    param(
        [System.Collections.Generic.List[object]]$Bucket,
        [string]$Level,
        [string]$Message
    )

    $Bucket.Add([pscustomobject]@{
        Level = $Level
        Message = $Message
    })
}

function Get-RelativePath {
    param(
        [string]$BasePath,
        [string]$TargetPath
    )

    $baseUri = [System.Uri]((Resolve-Path -LiteralPath $BasePath).Path.TrimEnd('\') + '\')
    $targetUri = [System.Uri](Resolve-Path -LiteralPath $TargetPath).Path
    $relative = $baseUri.MakeRelativeUri($targetUri).ToString()
    return [System.Uri]::UnescapeDataString($relative).Replace('/', '\')
}

$rootResolved = (Resolve-Path -LiteralPath $RootPath).Path
if (-not (Test-Path -LiteralPath $ContractPath)) {
    throw "Contract file not found: $ContractPath"
}

$contract = Get-Content -LiteralPath $ContractPath -Raw | ConvertFrom-Json
$results = New-Object 'System.Collections.Generic.List[object]'
$ignoredNestedGitMarkers = @()
if ($null -ne $contract.ignored_nested_git_markers) {
    $ignoredNestedGitMarkers = @($contract.ignored_nested_git_markers)
}

foreach ($requiredFile in $contract.required_files) {
    $path = Join-Path $rootResolved $requiredFile
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Result -Bucket $results -Level "ERROR" -Message "Missing required file: $requiredFile"
    }
}

foreach ($requiredDirectory in $contract.required_directories) {
    $path = Join-Path $rootResolved $requiredDirectory
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        Add-Result -Bucket $results -Level "ERROR" -Message "Missing required directory: $requiredDirectory"
    }
}

foreach ($forbiddenPath in $contract.forbidden_paths) {
    $path = Join-Path $rootResolved $forbiddenPath
    if (Test-Path -LiteralPath $path) {
        Add-Result -Bucket $results -Level "ERROR" -Message "Forbidden path present: $forbiddenPath"
    }
}

$nestedGitDirs = Get-ChildItem -LiteralPath $rootResolved -Recurse -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -eq ".git" -and
        $_.FullName -ne (Join-Path $rootResolved ".git")
    }

foreach ($nestedGitDir in $nestedGitDirs) {
    $relative = Get-RelativePath -BasePath $rootResolved -TargetPath $nestedGitDir.FullName
    $shouldIgnore = $false
    foreach ($ignoredMarker in $ignoredNestedGitMarkers) {
        if ($relative.IndexOf($ignoredMarker, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $shouldIgnore = $true
            break
        }
    }
    if ($shouldIgnore) {
        continue
    }
    Add-Result -Bucket $results -Level "ERROR" -Message "Nested repository detected: $relative"
}

$rootMarkdownFiles = Get-ChildItem -LiteralPath $rootResolved -File | Where-Object { $_.Extension -eq ".md" }
$rootMarkdownThreshold = [int]$contract.warn_if_root_markdown_count_gt
if ($rootMarkdownFiles.Count -gt $rootMarkdownThreshold) {
    Add-Result -Bucket $results -Level "WARN" -Message "Root markdown count is $($rootMarkdownFiles.Count), above warning threshold $rootMarkdownThreshold"
}

foreach ($governanceFile in $contract.warn_on_root_governance_duplicates) {
    $path = Join-Path $rootResolved $governanceFile
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        Add-Result -Bucket $results -Level "WARN" -Message "Root governance file should be reviewed for demotion or removal: $governanceFile"
    }
}

$errors = @($results | Where-Object { $_.Level -eq "ERROR" })
$warnings = @($results | Where-Object { $_.Level -eq "WARN" })

Write-Host "Repo contract summary"
Write-Host "  Root: $rootResolved"
Write-Host "  Errors: $($errors.Count)"
Write-Host "  Warnings: $($warnings.Count)"

foreach ($warning in $warnings) {
    Write-Warning $warning.Message
}

foreach ($errorItem in $errors) {
    Write-Error $errorItem.Message -ErrorAction Continue
}

if ($errors.Count -gt 0) {
    exit 1
}
