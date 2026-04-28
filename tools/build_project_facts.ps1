param(
    [string]$RootPath = ".",
    [string]$OutputDirectory = ".\CONTROL",
    [string]$ProjectName = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Resolve-AbsolutePath {
    param([string]$Path)
    (Resolve-Path -LiteralPath $Path).Path
}

function Get-ProjectDisplayName {
    param(
        [string]$Root,
        [string]$ExplicitName
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitName)) {
        return $ExplicitName.Trim()
    }

    $leaf = Split-Path -Path $Root -Leaf
    $normalized = $leaf -replace '^\d+(?:\.\d+)*\s*-\s*', ''
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return $leaf
    }
    return $normalized.Trim()
}

function Convert-ToRelativePath {
    param(
        [string]$Root,
        [string]$Path
    )

    $rootUri = [System.Uri]((Resolve-AbsolutePath -Path $Root).TrimEnd('\') + '\')
    $pathUri = [System.Uri](Resolve-AbsolutePath -Path $Path)
    [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($pathUri).ToString()).Replace('/', '\')
}

function Get-DocxVisibleText {
    param([string]$Path)

    $zip = $null
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
        $entry = $zip.GetEntry("word/document.xml")
        if ($null -eq $entry) { return "" }
        $stream = $entry.Open()
        try {
            $reader = New-Object System.IO.StreamReader($stream)
            $xml = $reader.ReadToEnd()
        } finally {
            if ($reader) { $reader.Dispose() }
            if ($stream) { $stream.Dispose() }
        }
        $text = $xml -replace '<w:tab[^>]*/>', "`t"
        $text = $text -replace '</w:p>', "`n"
        $text = $text -replace '<[^>]+>', ' '
        $text = [System.Net.WebUtility]::HtmlDecode($text)
        $text = $text -replace '\s+', ' '
        return $text.Trim()
    } catch {
        return ""
    } finally {
        if ($zip) { $zip.Dispose() }
    }
}

function Get-AnnexDirectoryItems {
    param([string]$AnnexRoot)

    if (-not (Test-Path -LiteralPath $AnnexRoot)) {
        return @()
    }

    Get-ChildItem -LiteralPath $AnnexRoot -Directory |
        Where-Object { $_.Name -match '^\d+\.-' } |
        Sort-Object {
            [int](($_.Name -split '\.-', 2)[0])
        }
}

function Get-PrimaryDocxFile {
    param([System.IO.DirectoryInfo]$Directory)

    Get-ChildItem -LiteralPath $Directory.FullName -File -Filter "*.docx" |
        Where-Object { $_.Name -notmatch '^~\$' } |
        Sort-Object FullName |
        Select-Object -First 1
}

$rootResolved = Resolve-AbsolutePath -Path $RootPath
if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}
$outputResolved = Resolve-AbsolutePath -Path $OutputDirectory
$projectDisplayName = Get-ProjectDisplayName -Root $rootResolved -ExplicitName $ProjectName

$annexRoot = Join-Path $rootResolved "DOCS - ANEJOS"
$memoryRoot = Join-Path $rootResolved "DOCS - MEMORIA"

$annexes = New-Object System.Collections.Generic.List[object]
foreach ($dir in (Get-AnnexDirectoryItems -AnnexRoot $annexRoot)) {
    $parts = $dir.Name -split '\.-', 2
    $annexNumber = [int]$parts[0]
    $annexTitle = if ($parts.Count -gt 1) { $parts[1].Trim() } else { $dir.Name }
    $docx = Get-PrimaryDocxFile -Directory $dir
    $docText = if ($docx) { Get-DocxVisibleText -Path $docx.FullName } else { "" }
    $annexes.Add([pscustomobject]@{
        numero = $annexNumber
        anejo = $annexTitle
        carpeta = Convert-ToRelativePath -Root $rootResolved -Path $dir.FullName
        docx = if ($docx) { Convert-ToRelativePath -Root $rootResolved -Path $docx.FullName } else { "" }
        existe_docx = [bool]$docx
        tamano_kb = if ($docx) { [math]::Round($docx.Length / 1KB, 1) } else { 0 }
        contiene_nombre_proyecto = if ($docText) { [bool]($docText -match [regex]::Escape($projectDisplayName)) } else { $false }
    }) | Out-Null
}

$memoryDocs = if (Test-Path -LiteralPath $memoryRoot) {
    Get-ChildItem -LiteralPath $memoryRoot -File -Filter "*.docx" |
        Where-Object { $_.Name -notmatch '^~\$' } |
        Sort-Object FullName |
        ForEach-Object {
            [pscustomobject]@{
                archivo = Convert-ToRelativePath -Root $rootResolved -Path $_.FullName
                tamano_kb = [math]::Round($_.Length / 1KB, 1)
                ultima_modificacion = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
            }
        }
} else {
    @()
}

$budgetFiles = Get-ChildItem -LiteralPath $rootResolved -Recurse -File |
    Where-Object { $_.Extension.ToLowerInvariant() -in @(".bc3", ".pzh") } |
    Sort-Object FullName |
    ForEach-Object {
        [pscustomobject]@{
            archivo = Convert-ToRelativePath -Root $rootResolved -Path $_.FullName
            extension = $_.Extension.ToLowerInvariant()
            tamano_kb = [math]::Round($_.Length / 1KB, 1)
        }
    }

$spreadsheetFiles = Get-ChildItem -LiteralPath $rootResolved -Recurse -File |
    Where-Object {
        $_.Extension.ToLowerInvariant() -in @(".xlsx", ".xlsm", ".xls") -and
        $_.Name -notmatch '^~\$'
    } |
    Sort-Object FullName |
    ForEach-Object {
        [pscustomobject]@{
            archivo = Convert-ToRelativePath -Root $rootResolved -Path $_.FullName
            extension = $_.Extension.ToLowerInvariant()
            tamano_kb = [math]::Round($_.Length / 1KB, 1)
        }
    }

$topFolders = Get-ChildItem -LiteralPath $rootResolved -Directory |
    Where-Object { $_.Name -notmatch '^\.' } |
    Sort-Object Name |
    ForEach-Object {
        $fileCount = @(Get-ChildItem -LiteralPath $_.FullName -File -Recurse -ErrorAction SilentlyContinue).Count
        [pscustomobject]@{
            carpeta = $_.Name
            archivos = $fileCount
        }
    }

[object[]]$annexArray = @(foreach ($item in $annexes) { $item })
[object[]]$memoryArray = @(foreach ($item in @($memoryDocs)) { $item })
[object[]]$budgetArray = @(foreach ($item in @($budgetFiles)) { $item })
[object[]]$spreadsheetArray = @(foreach ($item in @($spreadsheetFiles)) { $item })
[object[]]$topFolderArray = @(foreach ($item in @($topFolders)) { $item })

$facts = [pscustomobject][ordered]@{
    generated_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    root = $rootResolved
    project_name = $projectDisplayName
    annex_count = $annexArray.Count
    memory_count = $memoryArray.Count
    budget_file_count = $budgetArray.Count
    spreadsheet_file_count = $spreadsheetArray.Count
    annexes = [object[]]$annexArray
    memory_docs = [object[]]$memoryArray
    budget_files = [object[]]$budgetArray
    spreadsheet_files = [object[]]$spreadsheetArray
    top_level_folders = [object[]]$topFolderArray
}

$jsonPath = Join-Path $outputResolved "project_facts.json"
$csvPath = Join-Path $outputResolved "project_annexes.csv"
$mdPath = Join-Path $outputResolved "project_facts.md"

$facts | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$annexes | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

$md = New-Object System.Collections.Generic.List[string]
[void]$md.Add("# Ficha automatica del proyecto")
[void]$md.Add("")
[void]$md.Add("- Proyecto: $projectDisplayName")
[void]$md.Add("- Fecha de generacion: $($facts.generated_at)")
[void]$md.Add("- Numero de anejos detectados: $($facts.annex_count)")
[void]$md.Add("- Documentos de memoria: $($facts.memory_count)")
[void]$md.Add("- Ficheros BC3/PZH: $($facts.budget_file_count)")
[void]$md.Add("- Hojas Excel detectadas: $($facts.spreadsheet_file_count)")
[void]$md.Add("")
[void]$md.Add("## Anejos")
[void]$md.Add("")
[void]$md.Add("| N | Anejo | DOCX | Nombre de proyecto visible |")
[void]$md.Add("|---|---|---|---|")
foreach ($annex in $annexArray) {
    $docxCell = if ($annex.docx) { $annex.docx } else { "Sin DOCX" }
    $visible = if ($annex.contiene_nombre_proyecto) { "si" } else { "no" }
    [void]$md.Add("| $($annex.numero) | $($annex.anejo) | $docxCell | $visible | |")
}
[void]$md.Add("")
[void]$md.Add("## Carpetas de primer nivel")
[void]$md.Add("")
[void]$md.Add("| Carpeta | Archivos detectados |")
[void]$md.Add("|---|---:|")
foreach ($folder in $topFolderArray) {
    [void]$md.Add("| $($folder.carpeta) | $($folder.archivos) |")
}
$md | Set-Content -LiteralPath $mdPath -Encoding UTF8

[pscustomobject]@{
    JsonPath = $jsonPath
    CsvPath = $csvPath
    MarkdownPath = $mdPath
    AnnexCount = $annexArray.Count
    ProjectName = $projectDisplayName
}
