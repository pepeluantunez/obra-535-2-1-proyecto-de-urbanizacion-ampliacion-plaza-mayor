param(
    [string]$RootPath = ".",
    [string]$OutputRoot = ".\\_excel_revision_openxml",
    [string]$Suffix = "_PRO"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-OpenXmlAssemblyPath {
    $candidates = @(
        "C:\Program Files\Microsoft Office\root\vfs\ProgramFilesCommonX64\Microsoft Shared\Filters\Documentformat.OpenXml.dll",
        "C:\Program Files\Microsoft Office\root\Office16\ADDINS\Microsoft Power Query for Excel Integrated\bin\DocumentFormat.OpenXml.dll",
        "C:\Program Files\Autodesk\AutoCAD 2026\DocumentFormat.OpenXml.dll",
        "C:\Program Files\Autodesk\AutoCAD 2025\DocumentFormat.OpenXml.dll"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    throw "No se ha encontrado DocumentFormat.OpenXml.dll en el equipo."
}

function Ensure-FormatterLoaded {
    if ("OpenXmlExcelFormatter" -as [type]) { return }
    $dll = Get-OpenXmlAssemblyPath
    Add-Type -Path $dll
    Add-Type -Path (Join-Path $PSScriptRoot 'OpenXmlExcelFormatter.cs') -ReferencedAssemblies @($dll, 'WindowsBase')
}

function Get-ExcelFiles {
    param([string]$Root)
    Get-ChildItem -LiteralPath $Root -Recurse -File |
        Where-Object {
            $_.Extension.ToLowerInvariant() -in @('.xlsx', '.xlsm', '.xls', '.xlsb', '.xltx', '.xltm') -and
            $_.Name -notmatch '^~\$' -and
            $_.BaseName -notmatch '(_PRO|_PRESENTABLE|_FORMATEADO)$'
        } |
        Sort-Object FullName
}

function Read-XmlEntry {
    param([System.IO.Compression.ZipArchive]$Zip, [string]$EntryName)
    $entry = $Zip.GetEntry($EntryName)
    if ($null -eq $entry) { return $null }
    $stream = $null
    $reader = $null
    try {
        $stream = $entry.Open()
        $reader = New-Object System.IO.StreamReader($stream)
        [xml]$xml = $reader.ReadToEnd()
        return $xml
    } finally {
        if ($reader) { $reader.Dispose() }
        if ($stream) { $stream.Dispose() }
    }
}

function Get-WorksheetPathMap {
    param([System.IO.Compression.ZipArchive]$Zip)
    $workbookXml = Read-XmlEntry -Zip $Zip -EntryName 'xl/workbook.xml'
    $relsXml = Read-XmlEntry -Zip $Zip -EntryName 'xl/_rels/workbook.xml.rels'
    $map = @{}
    if ($null -eq $workbookXml -or $null -eq $relsXml) { return $map }
    $rels = @{}
    foreach ($rel in $relsXml.Relationships.Relationship) { $rels[$rel.Id] = $rel.Target }
    foreach ($sheet in $workbookXml.workbook.sheets.sheet) {
        $rid = $sheet.GetAttribute('id', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
        if (-not $rid -or -not $rels[$rid]) { continue }
        $target = [string]$rels[$rid]
        if ($target -notmatch '^/') { $target = 'xl/' + $target.TrimStart('/') } else { $target = $target.TrimStart('/') }
        $state = ''
        try { $state = [string]$sheet.state } catch { $state = '' }
        $map[[string]$sheet.name] = [pscustomobject]@{ Path = $target; State = $state }
    }
    return $map
}

function Get-ModernWorkbookMetadata {
    param([System.IO.FileInfo]$File)

    $zip = $null
    $riskFlags = New-Object System.Collections.Generic.List[string]
    $sheetCount = 0
    $formulaCount = 0
    $hasMacros = $false
    $linkCount = 0
    $protected = $false
    $protectedSheets = 0
    $tables = 0
    $pivots = 0
    $drawings = 0
    $readable = $false
    $readError = ''

    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($File.FullName)
        $workbookXml = Read-XmlEntry -Zip $zip -EntryName 'xl/workbook.xml'
        $sheetMap = Get-WorksheetPathMap -Zip $zip
        if ($workbookXml -and $workbookXml.workbook.sheets.sheet) {
            $sheetCount = @($workbookXml.workbook.sheets.sheet).Count
            if (@($workbookXml.SelectNodes("//*[local-name()='workbookProtection']")).Count -gt 0) {
                $protected = $true
                [void]$riskFlags.Add('Estructura protegida')
            }
        }
        if ($zip.Entries | Where-Object { $_.FullName -eq 'xl/vbaProject.bin' }) {
            $hasMacros = $true
            [void]$riskFlags.Add('Macros/VBA')
        }
        $linkCount = @($zip.Entries | Where-Object { $_.FullName -like 'xl/externalLinks/*.xml' }).Count
        $tables = @($zip.Entries | Where-Object { $_.FullName -like 'xl/tables/*.xml' }).Count
        $pivots = @($zip.Entries | Where-Object { $_.FullName -like 'xl/pivotTables/*.xml' }).Count
        $drawings = @($zip.Entries | Where-Object { $_.FullName -like 'xl/drawings/*.xml' }).Count
        if ($linkCount -gt 0) { [void]$riskFlags.Add('Vínculos externos') }
        if ($tables -gt 0) { [void]$riskFlags.Add('Tablas estructuradas') }
        if ($pivots -gt 0) { [void]$riskFlags.Add('Tablas dinámicas') }
        if ($drawings -gt 0) { [void]$riskFlags.Add('Dibujos/gráficos') }

        foreach ($sheetName in $sheetMap.Keys) {
            $sheetXml = Read-XmlEntry -Zip $zip -EntryName $sheetMap[$sheetName].Path
            if ($null -eq $sheetXml) { continue }
            $formulaCount += @($sheetXml.SelectNodes("//*[local-name()='f']")).Count
            if (@($sheetXml.SelectNodes("//*[local-name()='sheetProtection']")).Count -gt 0) { $protectedSheets += 1 }
        }
        if ($protectedSheets -gt 0) {
            $protected = $true
            [void]$riskFlags.Add('Hojas protegidas')
        }

        try {
            $docType = [Reflection.Assembly]::LoadFrom((Get-OpenXmlAssemblyPath)).GetType('DocumentFormat.OpenXml.Packaging.SpreadsheetDocument')
            $doc = $docType::Open($File.FullName, $false)
            $doc.Close()
            $readable = $true
        } catch {
            $readable = $false
            $readError = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message }
            [void]$riskFlags.Add('No reescribible con OpenXML')
        }
    } catch {
        $readable = $false
        $readError = $_.Exception.Message
        [void]$riskFlags.Add('Archivo bloqueado o no accesible')
    } finally {
        if ($zip) { $zip.Dispose() }
    }

    [pscustomobject]@{
        OpenXmlReadable = $readable
        OpenXmlError = $readError
        SheetCount = $sheetCount
        MultipleSheets = $(if ($sheetCount -gt 1) { 'sí' } elseif ($sheetCount -eq 1) { 'no' } else { 'no verificado' })
        HasFormulas = $(if ($formulaCount -gt 0) { 'sí' } else { 'no' })
        FormulaCount = $formulaCount
        HasMacros = $(if ($hasMacros) { 'sí' } else { 'no' })
        LinkCount = $linkCount
        EditableSafely = $(if ($readable -and -not $protected) { 'sí' } else { 'no' })
        DeservesImprovement = $(if ($sheetCount -gt 0) { 'sí' } else { 'no' })
        RiskFlags = @($riskFlags)
    }
}

function Get-LegacyWorkbookMetadata {
    [pscustomobject]@{
        OpenXmlReadable = $false
        OpenXmlError = ''
        SheetCount = 0
        MultipleSheets = 'no verificado'
        HasFormulas = 'no verificado'
        FormulaCount = 0
        HasMacros = 'no verificado'
        LinkCount = 0
        EditableSafely = 'no'
        DeservesImprovement = 'sí'
        RiskFlags = @('Formato legado no tratado automáticamente')
    }
}

function New-OutputPath {
    param([string]$Root, [System.IO.FileInfo]$File, [string]$OutputRoot, [string]$Suffix)
    $rootResolved = (Resolve-Path -LiteralPath $Root).Path
    $outputResolved = if ([System.IO.Path]::IsPathRooted($OutputRoot)) { $OutputRoot } else { (Join-Path $rootResolved $OutputRoot) }
    $dirResolved = (Resolve-Path -LiteralPath $File.DirectoryName).Path
    $relative = $dirResolved.Substring($rootResolved.Length).TrimStart('\')
    $targetDir = Join-Path $outputResolved $relative
    if (-not (Test-Path -LiteralPath $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
    $candidate = Join-Path $targetDir ($File.BaseName + $Suffix + $File.Extension)
    if ($candidate.Length -gt 240) {
        $shortBase = if ($File.BaseName.Length -gt 80) { $File.BaseName.Substring(0, 80) } else { $File.BaseName }
        $shortBase = ($shortBase -replace '[\\/:*?"<>|]', '_')
        return (Join-Path $outputResolved ($shortBase + $Suffix + $File.Extension))
    }
    $candidate
}

function Write-ReportFiles {
    param([System.Collections.Generic.List[object]]$Rows, [string]$OutputRoot)
    if (-not (Test-Path -LiteralPath $OutputRoot)) { New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null }
    $jsonPath = Join-Path $OutputRoot 'excel_inventory_and_report.json'
    $csvPath = Join-Path $OutputRoot 'excel_resumen.csv'
    $mdPath = Join-Path $OutputRoot 'excel_resumen.md'
    $Rows | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
    $Rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
    $md = New-Object System.Collections.Generic.List[string]
    [void]$md.Add('# Informe resumen de revisión Excel')
    [void]$md.Add('')
    [void]$md.Add('| Archivo original | Archivo generado | Mejorado | Intervención | Fórmulas | Macros | Riesgos detectados | Cambios realizados | Incidencias |')
    [void]$md.Add('|---|---|---|---|---|---|---|---|---|')
    foreach ($row in $Rows) {
        [void]$md.Add("| $($row.archivo_original) | $($row.nombre_generado) | $($row.se_ha_mejorado) | $($row.nivel_intervencion) | $($row.contiene_formulas) | $($row.contiene_macros) | $(($row.riesgos_detectados -join '<br>')) | $(($row.cambios_realizados -join '<br>')) | $(($row.incidencias_o_limitaciones -join '<br>')) |")
    }
    $md | Set-Content -LiteralPath $mdPath -Encoding UTF8
    [pscustomobject]@{ JsonPath = $jsonPath; CsvPath = $csvPath; MarkdownPath = $mdPath }
}

Ensure-FormatterLoaded
if (-not (Test-Path -LiteralPath $OutputRoot)) { New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null }

$rootResolved = (Resolve-Path -LiteralPath $RootPath).Path
$files = @(Get-ExcelFiles -Root $rootResolved)
$results = New-Object 'System.Collections.Generic.List[object]'

foreach ($file in $files) {
    Write-Host ("Analizando: " + $file.FullName)
    $ext = $file.Extension.ToLowerInvariant()
    $isModern = $ext -in @('.xlsx', '.xlsm', '.xltx', '.xltm')
    $meta = if ($isModern) { Get-ModernWorkbookMetadata -File $file } else { Get-LegacyWorkbookMetadata }

    $row = [ordered]@{
        archivo_original = $file.Name
        ruta_original = $file.FullName
        tipo = $ext
        editable_seguro = $meta.EditableSafely
        contiene_formulas = $meta.HasFormulas
        contiene_macros = $meta.HasMacros
        varias_hojas = $meta.MultipleSheets
        merece_mejora = $meta.DeservesImprovement
        riesgos_detectados = @($meta.RiskFlags)
        nombre_generado = ''
        ruta_generada = ''
        se_ha_mejorado = 'no'
        nivel_intervencion = 'sin aplicar'
        cambios_realizados = @()
        incidencias_o_limitaciones = @()
    }

    if (-not $isModern) {
        $row.incidencias_o_limitaciones = @('No reformateado por seguridad: formato legado sin vía de edición fiable en esta sesión')
        $results.Add([pscustomobject]$row)
        continue
    }

    if (-not $meta.OpenXmlReadable) {
        $reason = if ($meta.OpenXmlError) { $meta.OpenXmlError } else { 'No reescribible con OpenXML' }
        $row.incidencias_o_limitaciones = @("No reformateado por seguridad: $reason")
        $results.Add([pscustomobject]$row)
        continue
    }

    if ($meta.EditableSafely -ne 'sí') {
        $row.incidencias_o_limitaciones = @('No reformateado por seguridad: se detectó protección estructural o de hojas')
        $results.Add([pscustomobject]$row)
        continue
    }

    $outputPath = New-OutputPath -Root $rootResolved -File $file -OutputRoot $OutputRoot -Suffix $Suffix
    try {
        $format = [OpenXmlExcelFormatter]::FormatCopy($file.FullName, $outputPath)
    } catch {
        $format = [FormatterOutcome]::new()
        $format.Success = $false
        $format.Error = $_.Exception.Message
    }

    $row.nombre_generado = Split-Path -Leaf $outputPath
    $row.ruta_generada = $outputPath

    if (-not $format.Success) {
        $row.incidencias_o_limitaciones = @("Error al formatear: $($format.Error)")
        $results.Add([pscustomobject]$row)
        continue
    }

    $after = Get-ModernWorkbookMetadata -File ([System.IO.FileInfo]$outputPath)
    $issues = New-Object System.Collections.Generic.List[string]
    if ($meta.SheetCount -ne $after.SheetCount) { [void]$issues.Add('Número de hojas distinto') }
    if ($meta.FormulaCount -ne $after.FormulaCount) { [void]$issues.Add('Conteo de fórmulas distinto') }
    if ($meta.HasMacros -ne $after.HasMacros) { [void]$issues.Add('Estado de macros distinto') }
    if ($meta.LinkCount -ne $after.LinkCount) { [void]$issues.Add('Conteo de vínculos distinto') }

    if ($issues.Count -eq 0) {
        $row.se_ha_mejorado = 'sí'
        $row.nivel_intervencion = $format.Intervention
        $row.cambios_realizados = @($format.Changes)
        $row.incidencias_o_limitaciones = @($format.Notes)
    } else {
        $row.incidencias_o_limitaciones = @('Copia generada pero no validada: ' + ($issues -join '; '))
    }

    $results.Add([pscustomobject]$row)
}

$report = Write-ReportFiles -Rows $results -OutputRoot $OutputRoot
Write-Host ''
Write-Host ('Resumen JSON: ' + $report.JsonPath)
Write-Host ('Resumen CSV: ' + $report.CsvPath)
Write-Host ('Resumen MD: ' + $report.MarkdownPath)
