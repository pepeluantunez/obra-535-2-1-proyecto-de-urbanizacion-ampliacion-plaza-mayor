param(
    [string]$Bc3Path,
    [string]$ConfigPath = '.\CONFIG\project_budget_traceability.json',
    [ValidateSet('none', 'warn', 'strict')]
    [string]$ValidationMode = 'warn',
    [switch]$PlanOnly,
    [switch]$RequireBc3
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

. (Join-Path $PSScriptRoot 'project_traceability_helpers.ps1')

$config = Get-ProjectTraceabilityConfig -ConfigPath $ConfigPath
$resolvedBc3 = if (-not [string]::IsNullOrWhiteSpace($Bc3Path)) {
    Resolve-ProjectAbsolutePath -InputPath $Bc3Path
} else {
    Resolve-FirstExistingCandidate -Candidates @($config.budget_master_candidates)
}

if ([string]::IsNullOrWhiteSpace($resolvedBc3) -or -not (Test-Path -LiteralPath $resolvedBc3)) {
    if ($RequireBc3) {
        throw 'No se ha encontrado un BC3 maestro para sincronizar la trazabilidad del PEM.'
    }

    Write-Output 'SKIP PEM TRACEABILITY: no existe BC3 maestro todavia.'
    return
}

$preferredRootCode = if ($config.PSObject.Properties.Name -contains 'project_code') {
    '{0}##' -f $config.project_code
} else {
    ''
}
$pemInfo = Get-ProjectPemFromBc3 -Bc3Path $resolvedBc3 -PreferredRootCode $preferredRootCode
$memoryPath = Resolve-FirstExistingCandidate -Candidates @($config.memory_candidates)
$anejo17Path = Resolve-FirstExistingCandidate -Candidates @($config.anejo17_docx_candidates)

Write-Output '== SINCRONIZACION PEM / TRAZABILIDAD =='
Write-Output ("Proyecto: {0}" -f $config.project_name)
Write-Output ("BC3 maestro: {0}" -f $pemInfo.AbsolutePath)
Write-Output ("Concepto raiz: {0}" -f $pemInfo.RootCode)
Write-Output ("PEM vigente: {0}" -f $pemInfo.TextEs)
Write-Output ("Modo validacion: {0}" -f $ValidationMode)

if ($PlanOnly) {
    Write-Output ("PLAN memoria: {0}" -f $(if ($memoryPath) { $memoryPath } else { '<no configurada>' }))
    Write-Output ("PLAN anejo17: {0}" -f $(if ($anejo17Path) { $anejo17Path } else { '<no configurado>' }))
    foreach ($syncScript in @($config.sync_scripts)) {
        Write-Output ("PLAN sync-script: {0}" -f $syncScript.path)
    }
    return
}

$variables = @{
    Root = (Get-Location).Path
    Bc3Path = $pemInfo.AbsolutePath
}

foreach ($syncScript in @($config.sync_scripts)) {
    $scriptPath = Resolve-ExistingProjectPath -InputPath $syncScript.path
    $args = Expand-TemplateArguments -Arguments @($syncScript.args) -Variables $variables
    Invoke-PowerShellScriptFile -ScriptPath $scriptPath -Arguments $args
}

if (@($config.sync_scripts).Count -eq 0) {
    Write-Output 'WARN - No hay scripts de escritura PEM configurados; se ejecutan solo comprobaciones.'
}

if ($ValidationMode -eq 'none') {
    Write-Output 'OK PEM TRACEABILITY: sincronizacion sin validaciones adicionales.'
    return
}

$checks = @()
if ($memoryPath) {
    $checks += [pscustomobject]@{
        Label = 'memoria'
        Path = (Join-Path $PSScriptRoot 'check_memoria_budget_table.ps1')
        Args = @('-MemoryPath', $memoryPath, '-Bc3Path', $pemInfo.AbsolutePath, '-ConfigPath', (Resolve-ProjectAbsolutePath -InputPath $ConfigPath))
    }
}
if ($anejo17Path) {
    $checks += [pscustomobject]@{
        Label = 'anejo17'
        Path = (Join-Path $PSScriptRoot 'check_anejo17_pem_traceability.ps1')
        Args = @('-DocxPath', $anejo17Path, '-Bc3Path', $pemInfo.AbsolutePath, '-ConfigPath', (Resolve-ProjectAbsolutePath -InputPath $ConfigPath))
    }
}
$checks += [pscustomobject]@{
    Label = 'alineacion'
    Path = (Join-Path $PSScriptRoot 'check_project_pem_alignment.ps1')
    Args = @('-Bc3Path', $pemInfo.AbsolutePath, '-ConfigPath', (Resolve-ProjectAbsolutePath -InputPath $ConfigPath))
}

$warnings = New-Object System.Collections.Generic.List[string]
foreach ($check in $checks) {
    try {
        Invoke-PowerShellScriptFile -ScriptPath $check.Path -Arguments $check.Args
    } catch {
        if ($ValidationMode -eq 'strict') {
            throw
        }

        $warnings.Add(("{0}: {1}" -f $check.Label, $_.Exception.Message)) | Out-Null
    }
}

$officeTargets = @()
if ($memoryPath) { $officeTargets += $memoryPath }
if ($anejo17Path) { $officeTargets += $anejo17Path }
if ($officeTargets.Count -gt 0) {
    try {
        & (Join-Path $PSScriptRoot 'check_office_mojibake.ps1') -Paths $officeTargets
    } catch {
        if ($ValidationMode -eq 'strict') {
            throw
        }

        $warnings.Add(("office_mojibake: {0}" -f $_.Exception.Message)) | Out-Null
    }
}

if ($warnings.Count -gt 0) {
    Write-Output 'WARNINGS PEM TRACEABILITY:'
    foreach ($warning in $warnings) {
        Write-Output (" - {0}" -f $warning)
    }
}

Write-Output 'OK PEM TRACEABILITY'
