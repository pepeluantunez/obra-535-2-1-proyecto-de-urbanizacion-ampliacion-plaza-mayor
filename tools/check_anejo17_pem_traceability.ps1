param(
    [string]$DocxPath,
    [string]$Bc3Path,
    [string]$ConfigPath = '.\CONFIG\project_budget_traceability.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

. (Join-Path $PSScriptRoot 'project_traceability_helpers.ps1')

$config = Get-ProjectTraceabilityConfig -ConfigPath $ConfigPath
$resolvedDocx = if (-not [string]::IsNullOrWhiteSpace($DocxPath)) {
    Resolve-ExistingProjectPath -InputPath $DocxPath
} else {
    Resolve-FirstExistingCandidate -Candidates @($config.anejo17_docx_candidates)
}

if ($null -eq $resolvedDocx) {
    throw 'No se ha encontrado el Anejo 17 para validar el PEM.'
}

$resolvedBc3 = if (-not [string]::IsNullOrWhiteSpace($Bc3Path)) {
    Resolve-ExistingProjectPath -InputPath $Bc3Path
} else {
    Resolve-FirstExistingCandidate -Candidates @($config.budget_master_candidates)
}

if ($null -eq $resolvedBc3) {
    throw 'No se ha encontrado un BC3 maestro para validar el Anejo 17.'
}

$preferredRootCode = if ($config.PSObject.Properties.Name -contains 'project_code') {
    '{0}##' -f $config.project_code
} else {
    ''
}
$pemInfo = Get-ProjectPemFromBc3 -Bc3Path $resolvedBc3 -PreferredRootCode $preferredRootCode
$docText = Normalize-SearchText -Text (Read-SearchableText -Path $resolvedDocx)

$contextTokens = @(
    'SEGURIDAD Y SALUD',
    'PEM',
    'P.E.M',
    'PRESUPUESTO'
)
$hasContext = $false
foreach ($token in $contextTokens) {
    if ($docText.IndexOf($token, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $hasContext = $true
        break
    }
}

if (-not $hasContext) {
    throw "El Anejo 17 no contiene un bloque visible de PEM o presupuesto: $resolvedDocx"
}

if ($docText.IndexOf($pemInfo.TextEs, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
    throw "El Anejo 17 no refleja el PEM vigente del BC3 ($($pemInfo.TextEs))."
}

Write-Output ("OK ANEJO17 PEM: {0}" -f $resolvedDocx)
Write-Output ("BC3 maestro: {0}" -f $pemInfo.AbsolutePath)
Write-Output ("Concepto raiz: {0}" -f $pemInfo.RootCode)
Write-Output ("PEM validado: {0}" -f $pemInfo.TextEs)
