param(
    [string]$Root = "",
    [string[]]$Families,
    [switch]$ApplyDocxUpdates,
    [ValidateSet('text', 'json')]
    [string]$OutputFormat = 'text'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'civil3d_path_helpers.ps1')

$projectRoot = Resolve-Civil3DProjectRoot -Root $Root
$contractPath = Join-Path $projectRoot 'CONFIG\civil3d_input_families.json'
if (-not (Test-Path -LiteralPath $contractPath)) {
    throw "No existe el contrato Civil 3D: $contractPath"
}

$contract = Get-Content -LiteralPath $contractPath -Raw -Encoding UTF8 | ConvertFrom-Json
$catalogFamilies = @($contract.families)
if ($Families -and $Families.Count -gt 0) {
    $catalogFamilies = @($catalogFamilies | Where-Object { $_.id -in $Families })
}

$results = @()
foreach ($family in $catalogFamilies) {
    $folder = Resolve-Civil3DWorkFolder -Root $projectRoot -FolderNames @($family.folder_names)
    $foundSources = @()
    if ($folder) {
        foreach ($sourceFile in @($family.source_files)) {
            $sourcePath = Resolve-Civil3DSourcePath -FolderPath $folder -FileName $sourceFile
            if ($sourcePath) {
                $foundSources += (Split-Path $sourcePath -Leaf)
            }
        }
    }

    $isDetected = if ($family.require_all_sources) {
        ($foundSources.Count -eq @($family.source_files).Count)
    }
    else {
        ($foundSources.Count -gt 0)
    }

    $status = 'omitted'
    $notes = @()
    if (-not $folder) {
        $notes += 'carpeta no encontrada'
    }
    elseif (-not $isDetected) {
        $notes += 'fuentes insuficientes'
    }
    else {
        $scriptPath = Join-Path $PSScriptRoot $family.sync_script
        if (-not (Test-Path -LiteralPath $scriptPath)) {
            throw "No existe el script Civil 3D: $scriptPath"
        }

        & $scriptPath -Root $projectRoot | Out-Null
        $status = 'generated'
        $notes += 'derivados actualizados'

        if ($ApplyDocxUpdates -and -not [string]::IsNullOrWhiteSpace([string]$family.docx_update_script)) {
            $docxScriptPath = Join-Path $PSScriptRoot $family.docx_update_script
            if (-not (Test-Path -LiteralPath $docxScriptPath)) {
                throw "No existe el actualizador DOCX Civil 3D: $docxScriptPath"
            }
            & $docxScriptPath -Root $projectRoot | Out-Null
            $notes += 'docx auxiliar actualizado'
        }
    }

    $results += [pscustomobject]@{
        FamilyId       = $family.id
        Title          = $family.title
        FolderFound    = [bool]$folder
        SourcesFound   = @($foundSources)
        Status         = $status
        DerivedTargets = @($family.derived_files)
        Notes          = ($notes -join '; ')
    }
}

if ($OutputFormat -eq 'json') {
    $results | ConvertTo-Json -Depth 6
    return
}

Write-Output 'Sincronizacion Civil 3D:'
foreach ($result in $results) {
    Write-Output ("- {0}: {1}" -f $result.FamilyId, $result.Status)
    if ($result.SourcesFound.Count -gt 0) {
        Write-Output ("  Fuentes: {0}" -f ($result.SourcesFound -join ', '))
    }
    if (-not [string]::IsNullOrWhiteSpace($result.Notes)) {
        Write-Output ("  Nota: {0}" -f $result.Notes)
    }
}
