<#
.SYNOPSIS
    Sincroniza las herramientas del proyecto con la version mas reciente del toolkit.

.DESCRIPTION
    Copia las herramientas compartidas de urbanizacion-toolkit al proyecto,
    incluyendo checks, trazabilidad y automatismos Civil 3D reutilizables.

.PARAMETER ToolkitPath
    Ruta al repositorio urbanizacion-toolkit. Si se omite, se busca automaticamente.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ToolkitPath = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path $PSScriptRoot -Parent

if ($ToolkitPath -eq "") {
    $ProjectsRoot = Split-Path $ProjectRoot -Parent
    # Ubicacion canonica desde 2026-04-27
    $CandidatoCanónico = Join-Path $env:USERPROFILE "Documents\Claude\Projects\urbanizacion-toolkit"
    $CandidatoHermano  = Join-Path $ProjectsRoot "urbanizacion-toolkit"
    $CandidatoGit      = Join-Path $env:USERPROFILE "Documents\GitHub\urbanizacion-toolkit"
    # Legacy — mantener hasta borrar de Guadalmar
    $CandidatoLegacy   = Join-Path $env:USERPROFILE `
        "Documents\Claude\Projects\MEJORA CARRETERA GUADALMAR\PROYECTO 535\535.2\535.2.2 Mejora Carretera Guadalmar\urbanizacion-toolkit"

    foreach ($Candidato in @($CandidatoCanónico, $CandidatoHermano, $CandidatoGit, $CandidatoLegacy)) {
        if (Test-Path -LiteralPath $Candidato) {
            $ToolkitPath = $Candidato
            Write-Host "[sync_from_toolkit] Toolkit encontrado en: $ToolkitPath" -ForegroundColor DarkGray
            break
        }
    }
}

if ($ToolkitPath -eq "" -or -not (Test-Path -LiteralPath $ToolkitPath)) {
    throw "No se encuentra el toolkit. Especifica la ruta con -ToolkitPath '<ruta>'."
}

$Mapeo = @(
    @{ Origen = "tools\python\bc3_tools.py";                             Destino = "tools\bc3_tools.py" }
    @{ Origen = "tools\python\excel_tools.py";                           Destino = "tools\excel_tools.py" }
    @{ Origen = "tools\python\mediciones_validator.py";                  Destino = "tools\mediciones_validator.py" }
    @{ Origen = "tools\bc3\check_bc3_integrity.ps1";                     Destino = "tools\check_bc3_integrity.ps1" }
    @{ Origen = "tools\bc3\check_bc3_import_parity.ps1";                 Destino = "tools\check_bc3_import_parity.ps1" }
    @{ Origen = "tools\office\check_docx_tables_consistency.ps1";        Destino = "tools\check_docx_tables_consistency.ps1" }
    @{ Origen = "tools\office\check_excel_formula_guard.ps1";            Destino = "tools\check_excel_formula_guard.ps1" }
    @{ Origen = "tools\office\check_office_mojibake.ps1";                Destino = "tools\check_office_mojibake.ps1" }
    @{ Origen = "tools\traceability\check_traceability_consistency.ps1"; Destino = "tools\check_traceability_consistency.ps1" }
    @{ Origen = "tools\traceability\run_traceability_profile.ps1";       Destino = "tools\run_traceability_profile.ps1" }
    @{ Origen = "tools\learning\skill_error_logger.ps1";                 Destino = "tools\skill_error_logger.ps1" }
    @{ Origen = "tools\learning\skill_self_improve.ps1";                 Destino = "tools\skill_self_improve.ps1" }
    @{ Origen = "tools\civil3d\xml_excel_helpers.ps1";                   Destino = "tools\xml_excel_helpers.ps1" }
    @{ Origen = "tools\civil3d\civil3d_path_helpers.ps1";                Destino = "tools\civil3d_path_helpers.ps1" }
    @{ Origen = "tools\civil3d\build_anejo4_alignment_pk_package.ps1";   Destino = "tools\build_anejo4_alignment_pk_package.ps1" }
    @{ Origen = "tools\civil3d\build_anejo4_html_word_traceability.ps1"; Destino = "tools\build_anejo4_html_word_traceability.ps1" }
    @{ Origen = "tools\civil3d\update_anejo4_docx_pk.ps1";               Destino = "tools\update_anejo4_docx_pk.ps1" }
    @{ Origen = "tools\civil3d\build_network_measurements.ps1";          Destino = "tools\build_network_measurements.ps1" }
    @{ Origen = "tools\civil3d\sync_civil3d_inputs.ps1";                 Destino = "tools\sync_civil3d_inputs.ps1" }
    @{ Origen = "catalog\civil3d_input_families.json";                   Destino = "CONFIG\civil3d_input_families.json" }
    @{ Origen = "tools\bc3\check_bc3_encoding.ps1";                      Destino = "tools\check_bc3_encoding.ps1" }
    @{ Origen = "tools\automation\check_tools_sync.ps1";                 Destino = "tools\check_tools_sync.ps1" }
    @{ Origen = "tools\automation\install_git_hooks.ps1";                Destino = "tools\install_git_hooks.ps1" }
    @{ Origen = "tools\python\expediente_status.py";                     Destino = "tools\expediente_status.py" }
    @{ Origen = "tools\python\apply_project_style.py";                   Destino = "tools\apply_project_style.py" }
    @{ Origen = "tools\python\organize_anejo_folders.py";                Destino = "tools\organize_anejo_folders.py" }
    @{ Origen = "tools\python\session_briefing.py";                      Destino = "tools\session_briefing.py" }
    @{ Origen = "scripts\check_repo_contract.ps1";                       Destino = "tools\check_repo_contract.ps1" }
)

$Actualizados = 0
$SinCambios = 0

foreach ($Entry in $Mapeo) {
    $Src = Join-Path $ToolkitPath $Entry.Origen
    $Dst = Join-Path $ProjectRoot $Entry.Destino

    if (-not (Test-Path -LiteralPath $Src)) {
        Write-Warning "  No encontrado en toolkit: $($Entry.Origen)"
        continue
    }

    $DstDir = Split-Path -Parent $Dst
    if (-not (Test-Path -LiteralPath $DstDir)) {
        New-Item -ItemType Directory -Path $DstDir -Force | Out-Null
    }

    $HashSrc = (Get-FileHash -LiteralPath $Src -Algorithm MD5).Hash
    $HashDst = if (Test-Path -LiteralPath $Dst) {
        (Get-FileHash -LiteralPath $Dst -Algorithm MD5).Hash
    }
    else {
        ""
    }

    if ($HashSrc -eq $HashDst) {
        Write-Host "  Sin cambios: $($Entry.Destino)" -ForegroundColor DarkGray
        $SinCambios++
    }
    else {
        Copy-Item -LiteralPath $Src -Destination $Dst -Force
        Write-Host "  Actualizado: $($Entry.Destino)" -ForegroundColor Green
        $Actualizados++
    }
}

# --- Sincronizar skills del toolkit ---
$SkillsToolkitPath = Join-Path $ToolkitPath "skills"
if (Test-Path -LiteralPath $SkillsToolkitPath) {
    $SkillsDestPath = Join-Path $ProjectRoot ".claude\skills"
    $SkillDirs = Get-ChildItem -LiteralPath $SkillsToolkitPath -Directory

    foreach ($SkillDir in $SkillDirs) {
        $DstSkill = Join-Path $SkillsDestPath $SkillDir.Name
        if (-not (Test-Path -LiteralPath $DstSkill)) {
            New-Item -ItemType Directory -Path $DstSkill -Force | Out-Null
        }

        $SkillFiles = Get-ChildItem -LiteralPath $SkillDir.FullName -Recurse -File
        foreach ($sf in $SkillFiles) {
            $relative = $sf.FullName.Substring($SkillDir.FullName.Length).TrimStart("\")
            $dstFile  = Join-Path $DstSkill $relative
            $dstDir   = Split-Path -Parent $dstFile
            if (-not (Test-Path -LiteralPath $dstDir)) {
                New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
            }
            $hashSrc = (Get-FileHash -LiteralPath $sf.FullName -Algorithm MD5).Hash
            $hashDst = if (Test-Path -LiteralPath $dstFile) {
                (Get-FileHash -LiteralPath $dstFile -Algorithm MD5).Hash
            } else { "" }

            if ($hashSrc -eq $hashDst) {
                $SinCambios++
            } else {
                Copy-Item -LiteralPath $sf.FullName -Destination $dstFile -Force
                Write-Host "  Skill actualizada: $($SkillDir.Name)\$relative" -ForegroundColor Green
                $Actualizados++
            }
        }
    }
}

Write-Host ""
Write-Host "[sync_from_toolkit] Completado: $Actualizados actualizado(s), $SinCambios sin cambios." -ForegroundColor Cyan
