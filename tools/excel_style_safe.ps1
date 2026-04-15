param(
    [Parameter(Mandatory = $true)]
    [string[]]$Paths,
    [string]$FontName = 'Montserrat',
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$excelExtensions = @('.xlsx', '.xlsm')
$xlCellTypeFormulas = -4123
$msoAutomationSecurityForceDisable = 3

function Resolve-ExcelFiles {
    param([string[]]$InputPaths)

    $resolved = @()
    foreach ($inputPath in $InputPaths) {
        $absolute = if ([System.IO.Path]::IsPathRooted($inputPath)) { $inputPath } else { Join-Path (Get-Location) $inputPath }
        if (-not (Test-Path -LiteralPath $absolute)) { throw "No existe la ruta: $inputPath" }

        $item = Get-Item -LiteralPath $absolute
        if ($item.PSIsContainer) {
            Get-ChildItem -LiteralPath $item.FullName -Recurse -File |
                Where-Object { $_.Extension.ToLowerInvariant() -in $excelExtensions -and $_.Name -notmatch '^~\$' } |
                ForEach-Object { $resolved += $_.FullName }
        } else {
            if ($item.Extension.ToLowerInvariant() -notin $excelExtensions) {
                throw "Extension no soportada para estilo Excel: $($item.FullName)"
            }
            $resolved += $item.FullName
        }
    }
    return @($resolved | Sort-Object -Unique)
}

function Get-FormulaCount {
    param([object]$Range)
    if ($null -eq $Range) { return 0 }

    try {
        $formulaCells = $Range.SpecialCells($xlCellTypeFormulas)
        if ($null -eq $formulaCells) { return 0 }
        $count = [int]$formulaCells.Count
        [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($formulaCells)
        return $count
    } catch {
        return 0
    }
}

$files = @(Resolve-ExcelFiles -InputPaths $Paths)
if ($files.Count -eq 0) { throw 'No se han encontrado XLSX/XLSM para estandarizar.' }

$excel = $null
$hasFailures = $false
try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    $excel.ScreenUpdating = $false
    $excel.EnableEvents = $false
    $excel.AskToUpdateLinks = $false
    $excel.AutomationSecurity = $msoAutomationSecurityForceDisable
    try { $excel.Calculation = -4105 } catch {}

    foreach ($file in $files) {
        $wb = $null
        try {
            $wb = $excel.Workbooks.Open($file, $false, $false)
            $sheetSummaries = @()
            $beforeTotal = 0
            $afterTotal = 0

            foreach ($ws in @($wb.Worksheets)) {
                $used = $null
                try {
                    $used = $ws.UsedRange
                    if ($null -eq $used) { continue }

                    $before = Get-FormulaCount -Range $used
                    $beforeTotal += $before

                    if (-not $DryRun) {
                        $used.Font.Name = $FontName
                    }

                    $after = Get-FormulaCount -Range $used
                    $afterTotal += $after

                    $sheetSummaries += [pscustomobject]@{
                        Sheet = [string]$ws.Name
                        FormulasBefore = [int]$before
                        FormulasAfter = [int]$after
                    }
                } finally {
                    if ($null -ne $used -and [System.Runtime.InteropServices.Marshal]::IsComObject($used)) {
                        [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($used)
                    }
                    if ($null -ne $ws -and [System.Runtime.InteropServices.Marshal]::IsComObject($ws)) {
                        [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($ws)
                    }
                }
            }

            if ($afterTotal -lt $beforeTotal) {
                $hasFailures = $true
                Write-Output ("FALLO EXCEL: {0} formulas antes={1} despues={2}" -f $file, $beforeTotal, $afterTotal)
            } else {
                if ($DryRun) {
                    Write-Output ("OK EXCEL DRYRUN: {0} formulas antes={1} despues={2}" -f $file, $beforeTotal, $afterTotal)
                } else {
                    Write-Output ("OK EXCEL: {0} formulas antes={1} despues={2}" -f $file, $beforeTotal, $afterTotal)
                }
            }

            foreach ($s in $sheetSummaries) {
                Write-Output ("  - {0} formulas antes={1} despues={2}" -f $s.Sheet, $s.FormulasBefore, $s.FormulasAfter)
            }

            if (-not $DryRun) {
                $wb.Save()
            }

            $wb.Close($false)
        } catch {
            $hasFailures = $true
            if ($null -ne $wb) {
                try { $wb.Close($false) } catch {}
            }
            Write-Output ("FALLO EXCEL: {0}" -f $file)
            Write-Output $_.Exception.Message
        } finally {
            if ($null -ne $wb -and [System.Runtime.InteropServices.Marshal]::IsComObject($wb)) {
                [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($wb)
            }
        }
    }
} finally {
    if ($null -ne $excel) {
        try { $excel.Quit() } catch {}
        if ([System.Runtime.InteropServices.Marshal]::IsComObject($excel)) {
            [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($excel)
        }
    }
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

if ($hasFailures) {
    throw 'Estandarizacion Excel segura fallida.'
}
