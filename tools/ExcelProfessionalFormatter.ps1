param(
    [string]$RootPath = ".",
    [string]$OutputRoot = ".\\_excel_revision",
    [string]$Suffix = "_PRO"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$excelExtensions = @(".xlsx", ".xlsm", ".xls", ".xlsb", ".xltx", ".xltm")
$skipNamePattern = '(^~\$)|(_PRO|_PRESENTABLE|_FORMATEADO)$'

$xlCellTypeFormulas = -4123
$xlCellTypeConstants = 2
$xlLandscape = 2
$xlPortrait = 1
$xlSheetVisible = -1
$msoAutomationSecurityForceDisable = 3

function Release-ComObject {
    param([Parameter(ValueFromPipeline = $true)]$ComObject)
    process {
        if ($null -ne $ComObject) {
            try {
                [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($ComObject)
            } catch {
            }
        }
    }
}

function New-ExcelApplication {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    $excel.ScreenUpdating = $false
    $excel.EnableEvents = $false
    $excel.AskToUpdateLinks = $false
    $excel.AutomationSecurity = $msoAutomationSecurityForceDisable
    $excel.UserControl = $false
    return $excel
}

function Get-ExcelFiles {
    param([string]$Root)

    Get-ChildItem -LiteralPath $Root -Recurse -File |
        Where-Object {
            $_.Extension.ToLowerInvariant() -in $excelExtensions -and
            $_.Name -notmatch '^~\$' -and
            $_.BaseName -notmatch $skipNamePattern
        } |
        Sort-Object FullName
}

function Get-LinkCount {
    param($Workbook)

    try {
        $links = $Workbook.LinkSources(1)
        if ($null -eq $links) { return 0 }
        if ($links -is [System.Array]) { return $links.Count }
        return 1
    } catch {
        return 0
    }
}

function Test-HasVBProject {
    param($Workbook)

    try {
        return [bool]$Workbook.HasVBProject
    } catch {
        return $false
    }
}

function Get-RowNonEmptyCount {
    param(
        $Sheet,
        [int]$RowNumber,
        [int]$FirstColumn,
        [int]$LastColumn
    )

    if ($LastColumn -lt $FirstColumn) { return 0 }
    $range = $null
    try {
        $range = $Sheet.Range($Sheet.Cells.Item($RowNumber, $FirstColumn), $Sheet.Cells.Item($RowNumber, $LastColumn))
        return [int]$Sheet.Application.WorksheetFunction.CountA($range)
    } catch {
        return 0
    } finally {
        Release-ComObject $range
    }
}

function Get-HeaderProfile {
    param($Sheet)

    $usedRange = $null
    try {
        $usedRange = $Sheet.UsedRange
        $rowCount = [int]$usedRange.Rows.Count
        $columnCount = [int]$usedRange.Columns.Count
        $firstRow = [int]$usedRange.Row
        $firstColumn = [int]$usedRange.Column
        if ($rowCount -le 0 -or $columnCount -le 0) {
            return [pscustomobject]@{
                TitleRow = 0
                HeaderRow = 0
                FirstDataRow = 0
            }
        }

        $scanRows = [Math]::Min(8, $rowCount)
        $rowStats = @()
        for ($offset = 0; $offset -lt $scanRows; $offset++) {
            $rowNumber = $firstRow + $offset
            $nonEmpty = Get-RowNonEmptyCount -Sheet $Sheet -RowNumber $rowNumber -FirstColumn $firstColumn -LastColumn ($firstColumn + $columnCount - 1)
            $rowStats += [pscustomobject]@{
                RowNumber = $rowNumber
                NonEmpty = $nonEmpty
            }
        }

        $firstFilled = $rowStats | Where-Object { $_.NonEmpty -gt 0 } | Select-Object -First 1
        $headerCandidate = $rowStats |
            Sort-Object -Property @{ Expression = "NonEmpty"; Descending = $true }, @{ Expression = "RowNumber"; Descending = $false } |
            Select-Object -First 1

        $titleRow = 0
        $headerRow = 0

        if ($null -ne $headerCandidate -and $headerCandidate.NonEmpty -gt 0) {
            $headerRow = [int]$headerCandidate.RowNumber
        }

        if ($null -ne $firstFilled -and $null -ne $headerCandidate -and $firstFilled.RowNumber -lt $headerCandidate.RowNumber -and $firstFilled.NonEmpty -le [Math]::Max(3, [Math]::Floor($columnCount / 4))) {
            $titleRow = [int]$firstFilled.RowNumber
        }

        $firstDataRow = 0
        if ($headerRow -gt 0) {
            $firstDataRow = $headerRow + 1
        }

        return [pscustomobject]@{
            TitleRow = $titleRow
            HeaderRow = $headerRow
            FirstDataRow = $firstDataRow
        }
    } finally {
        Release-ComObject $usedRange
    }
}

function Get-WorksheetMetadata {
    param($Sheet)

    $usedRange = $null
    $formulaCells = $null
    $constantCells = $null
    try {
        $usedRange = $Sheet.UsedRange
        $formulaCount = 0
        $constantCount = 0
        try {
            $formulaCells = $usedRange.SpecialCells($xlCellTypeFormulas)
            $formulaCount = [int64]$formulaCells.CountLarge
        } catch {
            $formulaCount = 0
        }
        try {
            $constantCells = $usedRange.SpecialCells($xlCellTypeConstants)
            $constantCount = [int64]$constantCells.CountLarge
        } catch {
            $constantCount = 0
        }

        $chartObjects = 0
        $shapes = 0
        $listObjects = 0
        $pivotTables = 0
        try { $chartObjects = [int]$Sheet.ChartObjects().Count } catch { $chartObjects = 0 }
        try { $shapes = [int]$Sheet.Shapes.Count } catch { $shapes = 0 }
        try { $listObjects = [int]$Sheet.ListObjects.Count } catch { $listObjects = 0 }
        try { $pivotTables = [int]$Sheet.PivotTables().Count } catch { $pivotTables = 0 }

        return [pscustomobject]@{
            Name = [string]$Sheet.Name
            Visible = ([int]$Sheet.Visible -eq $xlSheetVisible)
            Rows = [int]$usedRange.Rows.Count
            Columns = [int]$usedRange.Columns.Count
            UsedCells = [int64]($usedRange.Rows.Count * $usedRange.Columns.Count)
            FormulaCells = $formulaCount
            ConstantCells = $constantCount
            Protected = [bool]$Sheet.ProtectContents
            HasMergedCells = [bool]$usedRange.MergeCells
            ChartObjects = $chartObjects
            Shapes = $shapes
            Tables = $listObjects
            PivotTables = $pivotTables
        }
    } finally {
        Release-ComObject $constantCells
        Release-ComObject $formulaCells
        Release-ComObject $usedRange
    }
}

function Get-WorkbookMetadata {
    param(
        $Excel,
        [string]$Path
    )

    $workbook = $null
    $sheetObjects = @()
    try {
        $workbook = $Excel.Workbooks.Open($Path, 0, $true)
        $worksheets = @($workbook.Worksheets)
        foreach ($sheet in $worksheets) {
            $sheetObjects += Get-WorksheetMetadata -Sheet $sheet
        }

        $hasVBProject = Test-HasVBProject -Workbook $workbook
        $formulaCount = [int64](($sheetObjects | Measure-Object FormulaCells -Sum).Sum)
        $visibleSheets = @($sheetObjects | Where-Object { $_.Visible })
        $protectedSheets = @($sheetObjects | Where-Object { $_.Protected })
        $pivotTables = [int](($sheetObjects | Measure-Object PivotTables -Sum).Sum)
        $chartObjects = [int](($sheetObjects | Measure-Object ChartObjects -Sum).Sum)
        $shapes = [int](($sheetObjects | Measure-Object Shapes -Sum).Sum)
        $usedCells = [int64](($sheetObjects | Measure-Object UsedCells -Sum).Sum)
        $linkCount = Get-LinkCount -Workbook $workbook
        $hasMultipleSheets = $workbook.Worksheets.Count -gt 1
        $riskFlags = New-Object System.Collections.Generic.List[string]

        if ($hasVBProject) { [void]$riskFlags.Add("Macros/VBA") }
        if ($workbook.ProtectStructure) { [void]$riskFlags.Add("Estructura protegida") }
        if ($protectedSheets.Count -gt 0) { [void]$riskFlags.Add("Hojas protegidas") }
        if ($linkCount -gt 0) { [void]$riskFlags.Add("Vínculos externos") }
        if ($pivotTables -gt 0) { [void]$riskFlags.Add("Tablas dinámicas") }
        if ($chartObjects -gt 0 -or $shapes -gt 25) { [void]$riskFlags.Add("Objetos/gráficos") }
        if ($usedCells -gt 200000) { [void]$riskFlags.Add("Volumen alto de celdas") }
        if ($Path.ToLowerInvariant().EndsWith(".xls")) { [void]$riskFlags.Add("Formato legado .xls") }
        if ($workbook.Worksheets.Count -gt 10) { [void]$riskFlags.Add("Libro grande") }

        $riskLevel = "bajo"
        if ($riskFlags.Count -ge 4 -or $workbook.ProtectStructure -or $protectedSheets.Count -gt 0) {
            $riskLevel = "alto"
        } elseif ($riskFlags.Count -ge 1) {
            $riskLevel = "medio"
        }

        $editableSafely = $true
        if ($workbook.ProtectStructure -or $protectedSheets.Count -gt 0) {
            $editableSafely = $false
        }

        $deservesImprovement = ($visibleSheets.Count -gt 0)
        if ($usedCells -lt 20) { $deservesImprovement = $false }

        return [pscustomobject]@{
            Opened = $true
            OpenError = ""
            Worksheets = $sheetObjects
            SheetCount = [int]$workbook.Worksheets.Count
            VisibleSheetCount = [int]$visibleSheets.Count
            MultipleSheets = $hasMultipleSheets
            FormulaCells = $formulaCount
            HasFormulas = ($formulaCount -gt 0)
            HasMacros = $hasVBProject
            LinkCount = [int]$linkCount
            ProtectStructure = [bool]$workbook.ProtectStructure
            ProtectedSheetCount = [int]$protectedSheets.Count
            PivotTableCount = $pivotTables
            ChartObjectCount = $chartObjects
            ShapeCount = $shapes
            UsedCells = $usedCells
            NameCount = [int]$workbook.Names.Count
            RiskFlags = @($riskFlags)
            RiskLevel = $riskLevel
            EditableSafely = $editableSafely
            DeservesImprovement = $deservesImprovement
            FileFormat = [int]$workbook.FileFormat
        }
    } catch {
        return [pscustomobject]@{
            Opened = $false
            OpenError = $_.Exception.Message
            Worksheets = @()
            SheetCount = 0
            VisibleSheetCount = 0
            MultipleSheets = $false
            FormulaCells = 0
            HasFormulas = $false
            HasMacros = $false
            LinkCount = 0
            ProtectStructure = $false
            ProtectedSheetCount = 0
            PivotTableCount = 0
            ChartObjectCount = 0
            ShapeCount = 0
            UsedCells = 0
            NameCount = 0
            RiskFlags = @("No abre correctamente")
            RiskLevel = "alto"
            EditableSafely = $false
            DeservesImprovement = $false
            FileFormat = 0
        }
    } finally {
        if ($null -ne $workbook) {
            try { $workbook.Close($false) } catch {}
            Release-ComObject $workbook
        }
    }
}

function Get-InterventionLevel {
    param(
        [bool]$SkipAutoFit,
        [bool]$HasTitle,
        [bool]$HasHeader
    )

    if ($SkipAutoFit -and -not $HasTitle -and -not $HasHeader) { return "baja" }
    if ($SkipAutoFit) { return "media" }
    return "media"
}

function Set-HeaderStyle {
    param(
        $Sheet,
        [int]$RowNumber,
        [int]$FirstColumn,
        [int]$LastColumn
    )

    if ($RowNumber -le 0 -or $LastColumn -lt $FirstColumn) { return }

    $range = $null
    try {
        $range = $Sheet.Range($Sheet.Cells.Item($RowNumber, $FirstColumn), $Sheet.Cells.Item($RowNumber, $LastColumn))
        $range.Font.Name = "Aptos"
        $range.Font.Size = 10
        $range.Font.Bold = $true
        $range.Font.Color = 16777215
        $range.Interior.Color = 4467237
        $range.HorizontalAlignment = -4108
        $range.VerticalAlignment = -4108
        $range.WrapText = $true
        $range.RowHeight = 24
        $range.Borders.LineStyle = 1
        $range.Borders.Weight = 2
        $range.Borders.Color = 13421772
    } finally {
        Release-ComObject $range
    }
}

function Set-TitleStyle {
    param(
        $Sheet,
        [int]$RowNumber,
        [int]$FirstColumn,
        [int]$LastColumn
    )

    if ($RowNumber -le 0 -or $LastColumn -lt $FirstColumn) { return }

    $range = $null
    try {
        $range = $Sheet.Range($Sheet.Cells.Item($RowNumber, $FirstColumn), $Sheet.Cells.Item($RowNumber, $LastColumn))
        $range.Font.Name = "Aptos Display"
        $range.Font.Size = 13
        $range.Font.Bold = $true
        $range.Font.Color = 3355443
        $range.Interior.Color = 15921906
        $range.WrapText = $true
        $range.RowHeight = 26
        $range.Borders.LineStyle = 1
        $range.Borders.Weight = 2
        $range.Borders.Color = 12632256
    } finally {
        Release-ComObject $range
    }
}

function Highlight-TotalRows {
    param(
        $Sheet,
        [int]$FirstRow,
        [int]$LastRow,
        [int]$FirstColumn,
        [int]$LastColumn
    )

    for ($row = $FirstRow; $row -le $LastRow; $row++) {
        $cell = $null
        $range = $null
        try {
            $cell = $Sheet.Cells.Item($row, $FirstColumn)
            $text = [string]$cell.Text
            if ($text -match '(?i)(^|\s)(total|resumen|resultado|importe total)(\s|$)') {
                $range = $Sheet.Range($Sheet.Cells.Item($row, $FirstColumn), $Sheet.Cells.Item($row, $LastColumn))
                $range.Font.Bold = $true
                $range.Interior.Color = 15132390
                $range.Borders.LineStyle = 1
                $range.Borders.Weight = 2
                $range.Borders.Color = 12632256
            }
        } catch {
        } finally {
            Release-ComObject $range
            Release-ComObject $cell
        }
    }
}

function Set-PrintSetup {
    param(
        $Excel,
        $Sheet,
        [int]$HeaderRow
    )

    $usedRange = $null
    try {
        $usedRange = $Sheet.UsedRange
        $cols = [int]$usedRange.Columns.Count
        $rows = [int]$usedRange.Rows.Count
        if ($cols -le 0 -or $rows -le 0) { return }

        $Sheet.PageSetup.LeftMargin = $Excel.InchesToPoints(0.45)
        $Sheet.PageSetup.RightMargin = $Excel.InchesToPoints(0.35)
        $Sheet.PageSetup.TopMargin = $Excel.InchesToPoints(0.55)
        $Sheet.PageSetup.BottomMargin = $Excel.InchesToPoints(0.55)
        $Sheet.PageSetup.HeaderMargin = $Excel.InchesToPoints(0.2)
        $Sheet.PageSetup.FooterMargin = $Excel.InchesToPoints(0.2)
        $Sheet.PageSetup.Orientation = $(if ($cols -gt 8) { $xlLandscape } else { $xlPortrait })
        $Sheet.PageSetup.Zoom = $false
        $Sheet.PageSetup.FitToPagesWide = $(if ($cols -gt 14) { 2 } else { 1 })
        $Sheet.PageSetup.FitToPagesTall = $false
        if ([string]::IsNullOrWhiteSpace([string]$Sheet.PageSetup.PrintArea)) {
            $Sheet.PageSetup.PrintArea = $usedRange.Address()
        }
        if ($HeaderRow -gt 0 -and $HeaderRow -le ($usedRange.Row + [int]$usedRange.Rows.Count - 1)) {
            $Sheet.PageSetup.PrintTitleRows = ('$' + $HeaderRow + ':$' + $HeaderRow)
        }
    } finally {
        Release-ComObject $usedRange
    }
}

function Set-FreezePanes {
    param(
        $Excel,
        $Sheet,
        [int]$HeaderRow,
        [int]$ColumnCount
    )

    if ($HeaderRow -le 0) { return }

    try {
        $Sheet.Activate() | Out-Null
        $window = $Excel.ActiveWindow
        $window.FreezePanes = $false
        $window.SplitRow = $HeaderRow
        $window.SplitColumn = $(if ($ColumnCount -gt 8) { 1 } else { 0 })
        $window.FreezePanes = $true
        $window.Zoom = 90
        Release-ComObject $window
    } catch {
    }
}

function Apply-SafeAutoFit {
    param(
        $Sheet,
        [int]$FirstColumn,
        [int]$LastColumn,
        [int]$FirstRow,
        [int]$LastRow
    )

    $columnRange = $null
    $rowRange = $null
    try {
        if ($LastColumn -ge $FirstColumn) {
            $columnRange = $Sheet.Range($Sheet.Cells.Item($FirstRow, $FirstColumn), $Sheet.Cells.Item($LastRow, $LastColumn)).EntireColumn
            $columnRange.AutoFit()

            for ($col = $FirstColumn; $col -le $LastColumn; $col++) {
                $singleColumn = $null
                try {
                    $singleColumn = $Sheet.Columns.Item($col)
                    if ([double]$singleColumn.ColumnWidth -gt 45) {
                        $singleColumn.ColumnWidth = 45
                        $singleColumn.WrapText = $true
                    } elseif ([double]$singleColumn.ColumnWidth -lt 8) {
                        $singleColumn.ColumnWidth = 8
                    }
                } finally {
                    Release-ComObject $singleColumn
                }
            }
        }

        if ($LastRow -ge $FirstRow) {
            $rowRange = $Sheet.Range($Sheet.Cells.Item($FirstRow, $FirstColumn), $Sheet.Cells.Item($LastRow, $LastColumn)).EntireRow
            $rowRange.AutoFit()
        }
    } finally {
        Release-ComObject $rowRange
        Release-ComObject $columnRange
    }
}

function Apply-ProfessionalFormat {
    param(
        $Excel,
        $Workbook
    )

    $changes = New-Object System.Collections.Generic.List[string]
    $sheetNotes = New-Object System.Collections.Generic.List[string]
    $intervention = "baja"

    foreach ($sheet in @($Workbook.Worksheets)) {
        $usedRange = $null
        try {
            if ([int]$sheet.Visible -ne $xlSheetVisible) {
                [void]$sheetNotes.Add("$($sheet.Name): sin cambios por estar oculta")
                continue
            }
            if ($sheet.ProtectContents) {
                [void]$sheetNotes.Add("$($sheet.Name): sin cambios por protección")
                continue
            }

            $usedRange = $sheet.UsedRange
            $firstRow = [int]$usedRange.Row
            $firstColumn = [int]$usedRange.Column
            $lastRow = $firstRow + [int]$usedRange.Rows.Count - 1
            $lastColumn = $firstColumn + [int]$usedRange.Columns.Count - 1
            if ($lastRow -lt $firstRow -or $lastColumn -lt $firstColumn) {
                [void]$sheetNotes.Add("$($sheet.Name): sin cambios por estar vacía")
                continue
            }

            $profile = Get-HeaderProfile -Sheet $sheet
            $hasShapes = $false
            $hasMerged = $false
            try { $hasShapes = ([int]$sheet.Shapes.Count -gt 0) } catch { $hasShapes = $false }
            try { $hasMerged = [bool]$usedRange.MergeCells } catch { $hasMerged = $false }
            $skipAutoFit = ($hasShapes -or $hasMerged)

            $usedRange.Font.Name = "Aptos"
            $usedRange.Font.Size = 10
            $usedRange.VerticalAlignment = -4108
            $usedRange.Borders.Color = 14013909

            if ($profile.TitleRow -gt 0) {
                Set-TitleStyle -Sheet $sheet -RowNumber $profile.TitleRow -FirstColumn $firstColumn -LastColumn $lastColumn
                [void]$changes.Add("Título principal reforzado en '$($sheet.Name)'")
            }

            if ($profile.HeaderRow -gt 0) {
                Set-HeaderStyle -Sheet $sheet -RowNumber $profile.HeaderRow -FirstColumn $firstColumn -LastColumn $lastColumn
                [void]$changes.Add("Encabezados normalizados en '$($sheet.Name)'")
            }

            Highlight-TotalRows -Sheet $sheet -FirstRow $firstRow -LastRow $lastRow -FirstColumn $firstColumn -LastColumn $lastColumn

            if (-not $skipAutoFit) {
                Apply-SafeAutoFit -Sheet $sheet -FirstColumn $firstColumn -LastColumn $lastColumn -FirstRow $firstRow -LastRow $lastRow
                [void]$changes.Add("Ajuste automático de columnas y filas en '$($sheet.Name)'")
            } else {
                [void]$sheetNotes.Add("$($sheet.Name): ajuste de anchos omitido por celdas combinadas/objetos")
            }

            Set-PrintSetup -Excel $Excel -Sheet $sheet -HeaderRow $profile.HeaderRow
            Set-FreezePanes -Excel $Excel -Sheet $sheet -HeaderRow $profile.HeaderRow -ColumnCount ([int]$usedRange.Columns.Count)

            $currentIntervention = Get-InterventionLevel -SkipAutoFit:$skipAutoFit -HasTitle:($profile.TitleRow -gt 0) -HasHeader:($profile.HeaderRow -gt 0)
            if ($currentIntervention -eq "media") { $intervention = "media" }
        } finally {
            Release-ComObject $usedRange
            Release-ComObject $sheet
        }
    }

    return [pscustomobject]@{
        Changes = @($changes | Select-Object -Unique)
        Notes = @($sheetNotes)
        Intervention = $intervention
    }
}

function New-OutputPath {
    param(
        [string]$Root,
        [System.IO.FileInfo]$File,
        [string]$Suffix
    )

    $relativeDir = Resolve-Path -LiteralPath $File.DirectoryName | ForEach-Object { $_.Path.Substring((Resolve-Path -LiteralPath $Root).Path.Length).TrimStart('\') }
    $targetDir = Join-Path $OutputRoot $relativeDir
    if (-not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    return (Join-Path $targetDir ($File.BaseName + $Suffix + $File.Extension))
}

function Format-WorkbookCopy {
    param(
        $Excel,
        [System.IO.FileInfo]$File,
        [string]$Root,
        [string]$Suffix
    )

    $destination = New-OutputPath -Root $Root -File $File -Suffix $Suffix
    Copy-Item -LiteralPath $File.FullName -Destination $destination -Force

    $workbook = $null
    try {
        $workbook = $Excel.Workbooks.Open($destination, 0, $false)
        $result = Apply-ProfessionalFormat -Excel $Excel -Workbook $workbook
        $workbook.Save()
        return [pscustomobject]@{
            Formatted = $true
            OutputPath = $destination
            Intervention = $result.Intervention
            Changes = $result.Changes
            Notes = $result.Notes
            Error = ""
        }
    } catch {
        return [pscustomobject]@{
            Formatted = $false
            OutputPath = $destination
            Intervention = "sin aplicar"
            Changes = @()
            Notes = @()
            Error = $_.Exception.Message
        }
    } finally {
        if ($null -ne $workbook) {
            try { $workbook.Close($true) } catch {}
            Release-ComObject $workbook
        }
    }
}

function Compare-Metadata {
    param(
        $Before,
        $After
    )

    $issues = New-Object System.Collections.Generic.List[string]
    if (-not $After.Opened) {
        [void]$issues.Add("La copia no abre correctamente")
        return [pscustomobject]@{
            IsValid = $false
            Issues = @($issues)
        }
    }

    if ($Before.SheetCount -ne $After.SheetCount) {
        [void]$issues.Add("Número de hojas distinto")
    }
    if ($Before.FormulaCells -ne $After.FormulaCells) {
        [void]$issues.Add("Conteo de fórmulas distinto")
    }
    if ($Before.NameCount -ne $After.NameCount) {
        [void]$issues.Add("Nombres definidos distintos")
    }
    if ($Before.HasMacros -ne $After.HasMacros) {
        [void]$issues.Add("Estado de macros distinto")
    }
    if ($Before.LinkCount -ne $After.LinkCount) {
        [void]$issues.Add("Conteo de vínculos distinto")
    }

    return [pscustomobject]@{
        IsValid = ($issues.Count -eq 0)
        Issues = @($issues)
    }
}

function Convert-ToCsvCell {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    return '"' + ([string]$Value).Replace('"', '""') + '"'
}

function Write-SummaryFiles {
    param(
        [System.Collections.Generic.List[object]]$Rows,
        [string]$OutputRoot
    )

    if (-not (Test-Path -LiteralPath $OutputRoot)) {
        New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
    }

    $jsonPath = Join-Path $OutputRoot "excel_inventory_and_report.json"
    $csvPath = Join-Path $OutputRoot "excel_resumen.csv"
    $mdPath = Join-Path $OutputRoot "excel_resumen.md"

    $Rows | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    $csvLines = New-Object System.Collections.Generic.List[string]
    [void]$csvLines.Add("archivo_original,ruta_original,tipo,editable_seguro,contiene_formulas,contiene_macros,varias_hojas,merece_mejora,riesgos,nombre_generado,se_ha_mejorado,nivel_intervencion,cambios_realizados,incidencias")
    foreach ($row in $Rows) {
        $csvValues = @(
            Convert-ToCsvCell $row.archivo_original
            Convert-ToCsvCell $row.ruta_original
            Convert-ToCsvCell $row.tipo
            Convert-ToCsvCell $row.editable_seguro
            Convert-ToCsvCell $row.contiene_formulas
            Convert-ToCsvCell $row.contiene_macros
            Convert-ToCsvCell $row.varias_hojas
            Convert-ToCsvCell $row.merece_mejora
            Convert-ToCsvCell (($row.riesgos_detectados -join "; "))
            Convert-ToCsvCell $row.nombre_generado
            Convert-ToCsvCell $row.se_ha_mejorado
            Convert-ToCsvCell $row.nivel_intervencion
            Convert-ToCsvCell (($row.cambios_realizados -join "; "))
            Convert-ToCsvCell (($row.incidencias_o_limitaciones -join "; "))
        )
        [void]$csvLines.Add(($csvValues -join ","))
    }
    $csvLines | Set-Content -LiteralPath $csvPath -Encoding UTF8

    $md = New-Object System.Collections.Generic.List[string]
    [void]$md.Add("# Informe resumen de revisión Excel")
    [void]$md.Add("")
    [void]$md.Add("| Archivo original | Archivo generado | Mejorado | Intervención | Fórmulas | Macros | Riesgos detectados | Cambios realizados | Incidencias |")
    [void]$md.Add("|---|---|---|---|---|---|---|---|---|")
    foreach ($row in $Rows) {
        [void]$md.Add("| $($row.archivo_original) | $($row.nombre_generado) | $($row.se_ha_mejorado) | $($row.nivel_intervencion) | $($row.contiene_formulas) | $($row.contiene_macros) | $(($row.riesgos_detectados -join '<br>')) | $(($row.cambios_realizados -join '<br>')) | $(($row.incidencias_o_limitaciones -join '<br>')) |")
    }
    $md | Set-Content -LiteralPath $mdPath -Encoding UTF8

    return [pscustomobject]@{
        JsonPath = $jsonPath
        CsvPath = $csvPath
        MarkdownPath = $mdPath
    }
}

if (-not (Test-Path -LiteralPath $OutputRoot)) {
    New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
}

$rootResolved = (Resolve-Path -LiteralPath $RootPath).Path
$files = @(Get-ExcelFiles -Root $rootResolved)
$excel = $null
$results = New-Object 'System.Collections.Generic.List[object]'

try {
    $excel = New-ExcelApplication

    foreach ($file in $files) {
        Write-Host ("Analizando: " + $file.FullName)
        $before = Get-WorkbookMetadata -Excel $excel -Path $file.FullName

        $row = [ordered]@{
            archivo_original = $file.Name
            ruta_original = $file.FullName
            tipo = $file.Extension.ToLowerInvariant()
            editable_seguro = $(if ($before.EditableSafely) { "sí" } else { "no" })
            contiene_formulas = $(if ($before.HasFormulas) { "sí" } else { "no" })
            contiene_macros = $(if ($before.HasMacros) { "sí" } else { "no" })
            varias_hojas = $(if ($before.MultipleSheets) { "sí" } else { "no" })
            merece_mejora = $(if ($before.DeservesImprovement) { "sí" } else { "no" })
            riesgos_detectados = @($before.RiskFlags)
            nombre_generado = ""
            ruta_generada = ""
            se_ha_mejorado = "no"
            nivel_intervencion = "sin aplicar"
            cambios_realizados = @()
            incidencias_o_limitaciones = @()
        }

        if (-not $before.Opened) {
            $row.incidencias_o_limitaciones = @("No se pudo abrir el archivo: $($before.OpenError)")
            $results.Add([pscustomobject]$row)
            continue
        }

        if (-not $before.DeservesImprovement) {
            $row.incidencias_o_limitaciones = @("No requiere intervención útil por su contenido o tamaño")
            $results.Add([pscustomobject]$row)
            continue
        }

        if (-not $before.EditableSafely) {
            $row.incidencias_o_limitaciones = @("No reformateado por seguridad")
            $results.Add([pscustomobject]$row)
            continue
        }

        $formatted = Format-WorkbookCopy -Excel $excel -File $file -Root $rootResolved -Suffix $Suffix
        $row.nombre_generado = $(if ($formatted.OutputPath) { Split-Path -Leaf $formatted.OutputPath } else { "" })
        $row.ruta_generada = $formatted.OutputPath

        if (-not $formatted.Formatted) {
            $row.incidencias_o_limitaciones = @("Error al formatear: $($formatted.Error)")
            $results.Add([pscustomobject]$row)
            continue
        }

        $after = Get-WorkbookMetadata -Excel $excel -Path $formatted.OutputPath
        $comparison = Compare-Metadata -Before $before -After $after

        if ($comparison.IsValid) {
            $row.se_ha_mejorado = "sí"
            $row.nivel_intervencion = $formatted.Intervention
            $row.cambios_realizados = @($formatted.Changes)
            $row.incidencias_o_limitaciones = @($formatted.Notes)
        } else {
            $row.incidencias_o_limitaciones = @("Copia generada pero no validada: " + ($comparison.Issues -join "; "))
        }

        $results.Add([pscustomobject]$row)
    }

    $summary = Write-SummaryFiles -Rows $results -OutputRoot $OutputRoot
    Write-Host ""
    Write-Host ("Resumen JSON: " + $summary.JsonPath)
    Write-Host ("Resumen CSV: " + $summary.CsvPath)
    Write-Host ("Resumen MD: " + $summary.MarkdownPath)
} finally {
    if ($null -ne $excel) {
        try { $excel.Quit() } catch {}
        Release-ComObject $excel
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
