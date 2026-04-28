[CmdletBinding()]
param(
    [string]$ManifestPath,
    [string]$ContractPath = ".\\CONFIG\\production_engine_seed\\common_trace_contract.json",
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

function Test-RequiredFields {
    param(
        [object]$Object,
        [string[]]$Fields,
        [string]$ScopeLabel,
        [System.Collections.Generic.List[object]]$Results
    )

    foreach ($field in $Fields) {
        $property = $Object.PSObject.Properties[$field]
        if ($null -eq $property) {
            Add-Result -Bucket $Results -Level "ERROR" -Message "$ScopeLabel is missing field: $field"
            continue
        }

        $value = $property.Value
        if ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) {
            Add-Result -Bucket $Results -Level "ERROR" -Message "$ScopeLabel has empty field: $field"
        }
        elseif ($null -eq $value) {
            Add-Result -Bucket $Results -Level "ERROR" -Message "$ScopeLabel has null field: $field"
        }
    }
}

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    throw "ManifestPath is required."
}

$rootResolved = (Resolve-Path -LiteralPath $RootPath).Path
if (-not (Test-Path -LiteralPath $ContractPath -PathType Leaf)) {
    throw "Contract file not found: $ContractPath"
}

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Manifest file not found: $ManifestPath"
}

$contract = Get-Content -LiteralPath $ContractPath -Raw | ConvertFrom-Json
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$results = New-Object 'System.Collections.Generic.List[object]'

Test-RequiredFields -Object $manifest -Fields @($contract.required_manifest_fields) -ScopeLabel "Manifest" -Results $results

$allowedOutputStatuses = @($contract.allowed_output_statuses)
$allowedEvidenceKinds = @($contract.allowed_evidence_kinds)
$allowedValidationStates = @($contract.allowed_validation_states)

if ($manifest.PSObject.Properties["output_status"] -and $allowedOutputStatuses -notcontains [string]$manifest.output_status) {
    Add-Result -Bucket $results -Level "ERROR" -Message "Manifest uses non-canonical output_status: $($manifest.output_status)"
}

if ($manifest.PSObject.Properties["output_path"] -and -not [string]::IsNullOrWhiteSpace([string]$manifest.output_path)) {
    $resolvedOutputPath = Join-Path $rootResolved ([string]$manifest.output_path)
    if (-not (Test-Path -LiteralPath $resolvedOutputPath)) {
        Add-Result -Bucket $results -Level "WARN" -Message "Output path does not exist yet: $($manifest.output_path)"
    }
}

if ($manifest.PSObject.Properties["generator"]) {
    Test-RequiredFields -Object $manifest.generator -Fields @($contract.required_generator_fields) -ScopeLabel "generator" -Results $results
}

if ($null -eq $manifest.input_sources) {
    Add-Result -Bucket $results -Level "ERROR" -Message "Manifest does not contain input_sources"
}
elseif (@($manifest.input_sources).Count -eq 0) {
    Add-Result -Bucket $results -Level "ERROR" -Message "Manifest input_sources array is empty"
}
else {
    foreach ($source in @($manifest.input_sources)) {
        $sourceLabel = "input_source"
        if ($source.PSObject.Properties["id"] -and -not [string]::IsNullOrWhiteSpace([string]$source.id)) {
            $sourceLabel = "input_source $($source.id)"
        }

        Test-RequiredFields -Object $source -Fields @($contract.required_input_source_fields) -ScopeLabel $sourceLabel -Results $results

        if ($source.PSObject.Properties["evidence_kind"] -and $allowedEvidenceKinds -notcontains [string]$source.evidence_kind) {
            Add-Result -Bucket $results -Level "ERROR" -Message "$sourceLabel uses non-canonical evidence_kind: $($source.evidence_kind)"
        }

        if ($source.PSObject.Properties["validation_state"] -and $allowedValidationStates -notcontains [string]$source.validation_state) {
            Add-Result -Bucket $results -Level "ERROR" -Message "$sourceLabel uses non-canonical validation_state: $($source.validation_state)"
        }

        if ($source.PSObject.Properties["path"] -and -not [string]::IsNullOrWhiteSpace([string]$source.path)) {
            $resolvedSourcePath = Join-Path $rootResolved ([string]$source.path)
            if (-not (Test-Path -LiteralPath $resolvedSourcePath)) {
                Add-Result -Bucket $results -Level "WARN" -Message "$sourceLabel points to a missing path: $($source.path)"
            }
        }
    }
}

if ($manifest.PSObject.Properties["assumptions"]) {
    foreach ($assumption in @($manifest.assumptions)) {
        $assumptionLabel = "assumption"
        if ($assumption.PSObject.Properties["id"] -and -not [string]::IsNullOrWhiteSpace([string]$assumption.id)) {
            $assumptionLabel = "assumption $($assumption.id)"
        }

        Test-RequiredFields -Object $assumption -Fields @($contract.required_assumption_fields) -ScopeLabel $assumptionLabel -Results $results

        if ($assumption.PSObject.Properties["validation_state"] -and $allowedValidationStates -notcontains [string]$assumption.validation_state) {
            Add-Result -Bucket $results -Level "ERROR" -Message "$assumptionLabel uses non-canonical validation_state: $($assumption.validation_state)"
        }
    }
}

if ($manifest.PSObject.Properties["pending_items"]) {
    foreach ($pendingItem in @($manifest.pending_items)) {
        $pendingLabel = "pending_item"
        if ($pendingItem.PSObject.Properties["id"] -and -not [string]::IsNullOrWhiteSpace([string]$pendingItem.id)) {
            $pendingLabel = "pending_item $($pendingItem.id)"
        }

        Test-RequiredFields -Object $pendingItem -Fields @($contract.required_pending_fields) -ScopeLabel $pendingLabel -Results $results
    }
}

if ($manifest.PSObject.Properties["validation"]) {
    Test-RequiredFields -Object $manifest.validation -Fields @($contract.required_validation_fields) -ScopeLabel "validation" -Results $results
}

$allEvidenceKinds = @()
foreach ($source in @($manifest.input_sources)) {
    if ($source.PSObject.Properties["evidence_kind"]) {
        $allEvidenceKinds += [string]$source.evidence_kind
    }
}

if ($allEvidenceKinds -contains "hipotesis_tecnica" -and -not $manifest.PSObject.Properties["assumptions"]) {
    Add-Result -Bucket $results -Level "WARN" -Message "Manifest declares hypothesis-based inputs but has no assumptions block"
}

if ($allEvidenceKinds -contains "pendiente_validar" -and -not $manifest.PSObject.Properties["pending_items"]) {
    Add-Result -Bucket $results -Level "WARN" -Message "Manifest declares pending inputs but has no pending_items block"
}

$errors = @($results | Where-Object { $_.Level -eq "ERROR" })
$warnings = @($results | Where-Object { $_.Level -eq "WARN" })

Write-Host "Output trace manifest summary"
Write-Host "  Root: $rootResolved"
Write-Host "  Manifest: $ManifestPath"
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
