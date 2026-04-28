param(
    [string]$Bc3Path,
    [string[]]$Needles,
    [string]$ConfigPath = '.\CONFIG\budget_traceability_automation.json',
    [switch]$PlanOnly,
    [switch]$StrictProfiles
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$toolsRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools'
. (Join-Path $toolsRoot 'project_traceability_helpers.ps1')

function Invoke-ConfiguredScript {
    param(
        [pscustomobject]$ScriptConfig,
        [hashtable]$Variables,
        [switch]$PlanOnly
    )

    $scriptPath = Resolve-ExistingProjectPath -InputPath $ScriptConfig.path
    $args = Expand-TemplateArguments -Arguments @($ScriptConfig.args) -Variables $Variables

    if ($PlanOnly) {
        Write-Output ("PLAN script: {0} {1}" -f $scriptPath, ($args -join ' '))
        return
    }

    Write-Output ("RUN script: {0}" -f $scriptPath)
    Invoke-PowerShellScriptFile -ScriptPath $scriptPath -Arguments $args
}

function Invoke-ProfileCheck {
    param(
        [string]$Profile,
        [string[]]$Needles,
        [switch]$PlanOnly,
        [switch]$StrictProfiles
    )

    $profileRunner = Resolve-ExistingProjectPath -InputPath '.\tools\run_traceability_profile.ps1'
    if ($PlanOnly) {
        if ($Needles.Count -gt 0) {
            Write-Output ("PLAN profile: {0} needles={1}" -f $Profile, ($Needles -join ', '))
        } else {
            Write-Output ("PLAN profile: {0}" -f $Profile)
        }
        return
    }

    Write-Output ("RUN profile: {0}" -f $Profile)
    if ($Needles.Count -gt 0) {
        & $profileRunner -Profile $Profile -Needles $Needles -StrictProfile:$StrictProfiles
    } else {
        & $profileRunner -Profile $Profile -StrictProfile:$StrictProfiles
    }
}

function Test-AreaMatch {
    param(
        [pscustomobject]$Area,
        [string[]]$Needles
    )

    if ($Needles.Count -eq 0) {
        return $false
    }

    foreach ($needle in $Needles) {
        foreach ($pattern in @($Area.match_any)) {
            if ($needle -like ('*' + $pattern + '*')) {
                return $true
            }
        }
    }

    return $false
}

$resolvedConfig = Resolve-ExistingProjectPath -InputPath $ConfigPath
$config = Get-Content -LiteralPath $resolvedConfig -Raw -Encoding UTF8 | ConvertFrom-Json
$projectConfig = Get-ProjectTraceabilityConfig -ConfigPath $config.project_config
$resolvedBc3 = if (-not [string]::IsNullOrWhiteSpace($Bc3Path)) {
    Resolve-ExistingProjectPath -InputPath $Bc3Path
} else {
    Resolve-FirstExistingCandidate -Candidates @($projectConfig.budget_master_candidates)
}

if ($null -eq $resolvedBc3) {
    throw 'No se ha encontrado un BC3 maestro para lanzar la sincronizacion automatica de trazabilidad.'
}

$effectiveNeedles = @(
    $Needles |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Trim() } |
        Sort-Object -Unique
)

$selectedAreas = @()
foreach ($area in @($config.areas)) {
    if (Test-AreaMatch -Area $area -Needles $effectiveNeedles) {
        $selectedAreas += $area
    }
}

$profilesToRun = New-Object System.Collections.Generic.List[string]
foreach ($profile in @($config.always.profiles)) {
    if (-not [string]::IsNullOrWhiteSpace($profile) -and -not $profilesToRun.Contains($profile)) {
        $profilesToRun.Add($profile) | Out-Null
    }
}
foreach ($area in $selectedAreas) {
    foreach ($profile in @($area.profiles)) {
        if (-not [string]::IsNullOrWhiteSpace($profile) -and -not $profilesToRun.Contains($profile)) {
            $profilesToRun.Add($profile) | Out-Null
        }
    }
}

$variables = @{
    Root = (Get-Location).Path
    Bc3Path = $resolvedBc3
}

Write-Output '== AUTOMATIZACION TRAZABILIDAD POR CAMBIO DE PRESUPUESTO =='
Write-Output ("BC3: {0}" -f $resolvedBc3)
Write-Output ("Modo: {0}" -f $(if ($PlanOnly) { 'plan-only' } else { 'ejecucion' }))
if ($effectiveNeedles.Count -gt 0) {
    Write-Output ("Needles: {0}" -f ($effectiveNeedles -join ', '))
} else {
    Write-Output 'Needles: <ninguno>'
}
if ($selectedAreas.Count -gt 0) {
    Write-Output ("Areas activadas: {0}" -f (($selectedAreas | ForEach-Object { $_.id }) -join ', '))
} else {
    Write-Output 'Areas activadas: base_pem'
}

foreach ($scriptConfig in @($config.always.scripts)) {
    Invoke-ConfiguredScript -ScriptConfig $scriptConfig -Variables $variables -PlanOnly:$PlanOnly
}

foreach ($area in $selectedAreas) {
    foreach ($scriptConfig in @($area.scripts)) {
        Invoke-ConfiguredScript -ScriptConfig $scriptConfig -Variables $variables -PlanOnly:$PlanOnly
    }
}

foreach ($profile in $profilesToRun) {
    Invoke-ProfileCheck -Profile $profile -Needles $effectiveNeedles -PlanOnly:$PlanOnly -StrictProfiles:$StrictProfiles
}

Write-Output 'OK AUTOMATIZACION TRAZABILIDAD PRESUPUESTO'
