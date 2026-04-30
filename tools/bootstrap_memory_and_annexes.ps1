param(
    [string]$ProjectConfig = ".\CONFIG\proyecto.template.json",
    [switch]$SkipChecks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-AbsolutePath {
    param([string]$Path)
    (Resolve-Path -LiteralPath $Path).Path
}

function Invoke-OptionalScript {
    param(
        [string]$Path,
        [hashtable]$Arguments
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    & $Path @Arguments
    return $true
}

$configResolved = Resolve-AbsolutePath -Path $ProjectConfig
$config = Get-Content -LiteralPath $configResolved -Raw | ConvertFrom-Json
$projectName = [string]$config.project_name
if ([string]::IsNullOrWhiteSpace($projectName)) {
    throw "El fichero de configuracion no contiene 'project_name'."
}

$memoryRoot = Join-Path (Get-Location).Path "DOCS - MEMORIA"
if (-not (Test-Path -LiteralPath $memoryRoot)) {
    New-Item -ItemType Directory -Path $memoryRoot -Force | Out-Null
}

$templateMemory = Join-Path (Get-Location).Path "DOCS - ANEJOS\Plantillas\PLANTILLA_MAESTRA_MEMORIA.docx"
$memoryName = if ([string]::IsNullOrWhiteSpace([string]$config.memory_filename)) {
    "Memoria descriptiva - $projectName.docx"
} else {
    [string]$config.memory_filename
}
$memoryTarget = Join-Path $memoryRoot $memoryName
if ((Test-Path -LiteralPath $templateMemory) -and -not (Test-Path -LiteralPath $memoryTarget)) {
    Copy-Item -LiteralPath $templateMemory -Destination $memoryTarget
}

$projectSpecific = Join-Path (Get-Location).Path "scripts\prefill_plaza_mayor_docs.ps1"
$usedProjectSpecific = Invoke-OptionalScript -Path $projectSpecific -Arguments @{}

if (-not $usedProjectSpecific) {
    Write-Warning "No se ha encontrado un bootstrap documental especifico del proyecto. Solo se ha asegurado la memoria base."
}

& (Join-Path (Get-Location).Path "tools\fill_docx_project_placeholders.ps1") `
    -ProjectConfig $configResolved `
    -Paths @(".\DOCS - ANEJOS", ".\DOCS - MEMORIA") | Out-Null

& (Join-Path (Get-Location).Path "tools\fix_docx_project_identity.ps1") `
    -Paths @(".\DOCS - ANEJOS", ".\DOCS - MEMORIA") | Out-Null

if (-not $SkipChecks) {
    & (Join-Path (Get-Location).Path "tools\check_template_completion.ps1") -Paths @(".\DOCS - ANEJOS", ".\DOCS - MEMORIA") -ProjectName $projectName
}

[pscustomobject]@{
    ProjectName = $projectName
    MemoryTarget = $memoryTarget
    UsedProjectSpecificBootstrap = $usedProjectSpecific
}
