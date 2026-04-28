param(
    [string]$MemoryPath,
    [string]$Bc3Path,
    [string]$ConfigPath = '.\CONFIG\project_budget_traceability.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

. (Join-Path $PSScriptRoot 'project_traceability_helpers.ps1')

$config = Get-ProjectTraceabilityConfig -ConfigPath $ConfigPath
$resolvedMemory = if (-not [string]::IsNullOrWhiteSpace($MemoryPath)) {
    Resolve-ExistingProjectPath -InputPath $MemoryPath
} else {
    Resolve-FirstExistingCandidate -Candidates @($config.memory_candidates)
}

if ($null -eq $resolvedMemory) {
    throw 'No se ha encontrado una memoria principal para validar el PEM.'
}

$resolvedBc3 = if (-not [string]::IsNullOrWhiteSpace($Bc3Path)) {
    Resolve-ExistingProjectPath -InputPath $Bc3Path
} else {
    Resolve-FirstExistingCandidate -Candidates @($config.budget_master_candidates)
}

if ($null -eq $resolvedBc3) {
    throw 'No se ha encontrado un BC3 maestro para validar la memoria.'
}

$preferredRootCode = if ($config.PSObject.Properties.Name -contains 'project_code') {
    '{0}##' -f $config.project_code
} else {
    ''
}
$pemInfo = Get-ProjectPemFromBc3 -Bc3Path $resolvedBc3 -PreferredRootCode $preferredRootCode
$memoryText = Normalize-SearchText -Text (Read-SearchableText -Path $resolvedMemory)

$contextTokens = @(
    'PRESUPUESTO',
    'EJECUCION MATERIAL',
    'PEM',
    'P.E.M'
)
$hasContext = $false
foreach ($token in $contextTokens) {
    if ($memoryText.IndexOf($token, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $hasContext = $true
        break
    }
}

if (-not $hasContext) {
    throw "La memoria no contiene una referencia visible a presupuesto o PEM: $resolvedMemory"
}

if ($memoryText.IndexOf($pemInfo.TextEs, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
    throw "La memoria no refleja el PEM vigente del BC3 ($($pemInfo.TextEs))."
}

Write-Output ("OK MEMORIA PEM: {0}" -f $resolvedMemory)
Write-Output ("BC3 maestro: {0}" -f $pemInfo.AbsolutePath)
Write-Output ("Concepto raiz: {0}" -f $pemInfo.RootCode)
Write-Output ("PEM validado: {0}" -f $pemInfo.TextEs)
