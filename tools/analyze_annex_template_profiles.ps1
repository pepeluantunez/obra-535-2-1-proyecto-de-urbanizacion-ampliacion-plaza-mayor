param(
    [string]$ProfileConfig = ".\CONFIG\annex_template_profiles.json",
    [string]$OutputJson = ".\CONTROL\annex_template_profile_analysis.json",
    [string]$ReportPath = ".\CONTROL\annex_template_profile_analysis.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Resolve-FullPathSafe {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
}

function Read-ZipEntryText {
    param([System.IO.Compression.ZipArchiveEntry]$Entry)

    $stream = $Entry.Open()
    try {
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.UTF8Encoding]::new($false), $true)
        try {
            return $reader.ReadToEnd()
        } finally {
            $reader.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Get-DocxMetrics {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{
            Exists = $false
            HeadingCount = 0
            TableCount = 0
            SampleHeadings = @()
        }
    }

    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entry = $zip.GetEntry("word/document.xml")
        if ($null -eq $entry) {
            throw "No se ha encontrado word/document.xml en $Path"
        }

        [xml]$xml = Read-ZipEntryText -Entry $entry
        $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
        $ns.AddNamespace("w", "http://schemas.openxmlformats.org/wordprocessingml/2006/main")

        $headings = @($xml.SelectNodes("//w:p[w:pPr/w:pStyle[contains(@w:val,'Ttulo') or contains(@w:val,'Titulo') or contains(@w:val,'Heading')]]", $ns))
        $tables = @($xml.SelectNodes("//w:tbl", $ns))

        $sampleHeadings = New-Object System.Collections.Generic.List[string]
        foreach ($heading in $headings | Select-Object -First 8) {
            $texts = @($heading.SelectNodes(".//w:t", $ns) | ForEach-Object { $_.InnerText })
            $text = ($texts -join "").Trim()
            if (-not [string]::IsNullOrWhiteSpace($text)) {
                $sampleHeadings.Add($text) | Out-Null
            }
        }

        return [pscustomobject]@{
            Exists = $true
            HeadingCount = $headings.Count
            TableCount = $tables.Count
            SampleHeadings = $sampleHeadings.ToArray()
        }
    } finally {
        $zip.Dispose()
    }
}

function Get-WorkbookMetrics {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{
            Exists = $false
            SheetCount = 0
            Sheets = @()
        }
    }

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($extension -notin @(".xlsx", ".xlsm")) {
        return [pscustomobject]@{
            Exists = $true
            SheetCount = 0
            Sheets = @()
        }
    }

    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entry = $zip.GetEntry("xl/workbook.xml")
        if ($null -eq $entry) {
            return [pscustomobject]@{
                Exists = $true
                SheetCount = 0
                Sheets = @()
            }
        }

        [xml]$xml = Read-ZipEntryText -Entry $entry
        $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
        $ns.AddNamespace("x", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
        $sheets = @($xml.SelectNodes("//x:sheets/x:sheet", $ns) | ForEach-Object { $_.GetAttribute("name") })

        return [pscustomobject]@{
            Exists = $true
            SheetCount = $sheets.Count
            Sheets = $sheets
        }
    } finally {
        $zip.Dispose()
    }
}

$configPath = Resolve-FullPathSafe -Path $ProfileConfig
$outputJsonPath = Resolve-FullPathSafe -Path $OutputJson
$reportFullPath = Resolve-FullPathSafe -Path $ReportPath

if (-not (Test-Path -LiteralPath $configPath)) {
    throw "No se encuentra la configuracion de perfiles: $configPath"
}

$config = Get-Content -LiteralPath $configPath -Raw -Encoding utf8 | ConvertFrom-Json
$rows = New-Object System.Collections.Generic.List[object]

foreach ($profile in $config.profiles) {
    $docxPath = Resolve-FullPathSafe -Path ([string]$profile.donor_docx)
    $docxMetrics = Get-DocxMetrics -Path $docxPath

    $excelRows = New-Object System.Collections.Generic.List[object]
    foreach ($excel in @($profile.donor_excels)) {
        $excelPath = Resolve-FullPathSafe -Path ([string]$excel)
        $excelMetrics = Get-WorkbookMetrics -Path $excelPath
        $excelRows.Add([pscustomobject]@{
                Path = $excelPath
                Exists = $excelMetrics.Exists
                SheetCount = $excelMetrics.SheetCount
                Sheets = $excelMetrics.Sheets
            }) | Out-Null
    }

    $supportResolved = @($profile.support_files | ForEach-Object { Resolve-FullPathSafe -Path ([string]$_) })
    $supportMissing = @($supportResolved | Where-Object { [string]::IsNullOrWhiteSpace($_) -or -not (Test-Path -LiteralPath $_) })

    $status = "READY"
    if (-not $docxMetrics.Exists) {
        $status = "MISSING_DOCX"
    } elseif ($supportMissing.Count -gt 0) {
        $status = "PARTIAL_SUPPORT"
    }

    $rows.Add([pscustomobject]@{
            Number = [int]$profile.number
            Slug = [string]$profile.slug
            Title = [string]$profile.title
            Family = [string]$profile.family
            Reusability = [string]$profile.reusability
            Status = $status
            DonorDocx = $docxPath
            HeadingCount = $docxMetrics.HeadingCount
            TableCount = $docxMetrics.TableCount
            SampleHeadings = $docxMetrics.SampleHeadings
            DonorExcels = $excelRows.ToArray()
            SupportFileCount = @($supportResolved | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
            MissingSupportCount = $supportMissing.Count
            VariableInputCount = @($profile.variable_inputs).Count
            VariableInputs = @($profile.variable_inputs)
            Notes = [string]$profile.notes
        }) | Out-Null
}

$rows | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $outputJsonPath -Encoding utf8

$md = New-Object System.Collections.Generic.List[string]
$null = $md.Add("# Analisis de perfiles reutilizables de anejos")
$null = $md.Add("")
$null = $md.Add("- Fecha: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))")
$null = $md.Add("- Configuracion: $ProfileConfig")
$null = $md.Add("- Total de perfiles auditados: $($rows.Count)")
$null = $md.Add("")
$null = $md.Add("| Anejo | Familia | Reutilizacion | Estado | Apartados | Tablas | Excels | Soportes | Inputs |")
$null = $md.Add("|---|---|---|---|---:|---:|---:|---:|---:|")
foreach ($row in $rows | Sort-Object Number) {
    $null = $md.Add("| $($row.Number) | $($row.Family) | $($row.Reusability) | $($row.Status) | $($row.HeadingCount) | $($row.TableCount) | $(@($row.DonorExcels).Count) | $($row.SupportFileCount) | $($row.VariableInputCount) |")
}

$null = $md.Add("")
foreach ($row in $rows | Sort-Object Number) {
    $null = $md.Add("## Anejo $($row.Number) - $($row.Title)")
    $null = $md.Add("")
    $null = $md.Add("- Familia: $($row.Family)")
    $null = $md.Add("- Reutilizacion recomendada: $($row.Reusability)")
    $null = $md.Add("- Estado donor: $($row.Status)")
    $null = $md.Add("- DOCX donor: $($row.DonorDocx)")
    $null = $md.Add("- Apartados detectados: $($row.HeadingCount)")
    $null = $md.Add("- Tablas detectadas: $($row.TableCount)")
    if (@($row.SampleHeadings).Count -gt 0) {
        $null = $md.Add("- Muestra de apartados: $((@($row.SampleHeadings) -join ' | '))")
    }
    if (@($row.DonorExcels).Count -gt 0) {
        foreach ($excel in @($row.DonorExcels)) {
            $sheetText = if (@($excel.Sheets).Count -gt 0) { (@($excel.Sheets) -join ', ') } else { "sin lectura de hojas" }
            $null = $md.Add("- Excel donor: $($excel.Path) ($($excel.SheetCount) hojas: $sheetText)")
        }
    } else {
        $null = $md.Add("- Excel donor: no asociado en este perfil")
    }
    $null = $md.Add("- Inputs variables: $((@($row.VariableInputs) -join ', '))")
    $null = $md.Add("- Nota: $($row.Notes)")
    $null = $md.Add("")
}

$reportDir = Split-Path -Parent $reportFullPath
if (-not (Test-Path -LiteralPath $reportDir)) {
    [void](New-Item -ItemType Directory -Path $reportDir -Force)
}
$md -join [Environment]::NewLine | Set-Content -LiteralPath $reportFullPath -Encoding utf8
Write-Output "Analisis escrito en: $reportFullPath"
