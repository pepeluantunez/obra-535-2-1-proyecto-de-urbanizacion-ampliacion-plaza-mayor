param(
    [string]$Bc3Path,
    [string[]]$TargetPaths,
    [string]$ConfigPath = '.\CONFIG\project_budget_traceability.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

. (Join-Path $PSScriptRoot 'project_traceability_helpers.ps1')

$config = Get-ProjectTraceabilityConfig -ConfigPath $ConfigPath
$resolvedBc3 = if (-not [string]::IsNullOrWhiteSpace($Bc3Path)) {
    Resolve-ExistingProjectPath -InputPath $Bc3Path
} else {
    Resolve-FirstExistingCandidate -Candidates @($config.budget_master_candidates)
}

if ($null -eq $resolvedBc3) {
    throw 'No se ha encontrado un BC3 maestro para validar la alineacion del PEM.'
}

$preferredRootCode = if ($config.PSObject.Properties.Name -contains 'project_code') {
    '{0}##' -f $config.project_code
} else {
    ''
}
$pemInfo = Get-ProjectPemFromBc3 -Bc3Path $resolvedBc3 -PreferredRootCode $preferredRootCode

$targetCandidates = if ($TargetPaths -and $TargetPaths.Count -gt 0) {
    @($TargetPaths)
} else {
    @($config.pem_expected_targets)
}
$resolvedTargets = Resolve-ExistingCandidatePaths -Candidates $targetCandidates
if ($resolvedTargets.Count -eq 0) {
    throw 'No hay documentos de destino configurados para revisar la alineacion del PEM.'
}

$issues = New-Object System.Collections.Generic.List[object]
foreach ($target in $resolvedTargets) {
    $text = Normalize-SearchText -Text (Read-SearchableText -Path $target)
    if ($text.IndexOf($pemInfo.TextEs, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        continue
    }

    $issues.Add([pscustomobject]@{
        Path = $target
        ExpectedPem = $pemInfo.TextEs
    }) | Out-Null
}

if ($issues.Count -gt 0) {
    Write-Output ("PEM vigente BC3: {0}" -f $pemInfo.TextEs)
    foreach ($issue in $issues) {
        Write-Output (" - Documento sin PEM actualizado: {0}" -f $issue.Path)
    }
    throw 'Fallo de alineacion del PEM entre BC3 y documentos dependientes.'
}

Write-Output ("OK PEM ALINEADO: {0}" -f $pemInfo.TextEs)
Write-Output ("BC3 maestro: {0}" -f $pemInfo.AbsolutePath)
Write-Output ("Documentos validados: {0}" -f $resolvedTargets.Count)
