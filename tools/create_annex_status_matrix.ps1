param(
    [string]$AnnexRoot = ".\DOCS - ANEJOS",
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
    param([string]$ExplicitName)
    if (-not [string]::IsNullOrWhiteSpace($ExplicitName)) {
        return $ExplicitName.Trim()
    }
    $cwdLeaf = Split-Path -Path (Get-Location).Path -Leaf
    return ($cwdLeaf -replace '^\d+(?:\.\d+)*\s*-\s*', '').Trim()
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
        $text = $xml -replace '</w:p>', "`n"
        $text = $text -replace '<w:tab[^>]*/>', "`t"
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

function Get-MaturityLabel {
    param(
        [bool]$HasDocx,
        [bool]$HasProjectName,
        [bool]$HasObjeto,
        [bool]$HasAntecedentes,
        [bool]$HasNormativa,
        [int]$PendingMarkers
    )

    if (-not $HasDocx) { return "Sin documento" }
    if (-not $HasProjectName) { return "Plantilla cruda" }
    if ($HasObjeto -and ($HasAntecedentes -or $HasNormativa) -and $PendingMarkers -eq 0) { return "Arranque completado" }
    if ($HasObjeto -and ($HasAntecedentes -or $HasNormativa)) { return "Base util preparada" }
    if ($HasObjeto) { return "Minimo arrancado" }
    return "Personalizacion parcial"
}

$annexRootResolved = Resolve-AbsolutePath -Path $AnnexRoot
if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}
$outputResolved = Resolve-AbsolutePath -Path $OutputDirectory
$projectDisplayName = Get-ProjectDisplayName -ExplicitName $ProjectName

$rows = New-Object System.Collections.Generic.List[object]
Get-ChildItem -LiteralPath $annexRootResolved -Directory |
    Where-Object { $_.Name -match '^\d+\.-' } |
    Sort-Object { [int](($_.Name -split '\.-', 2)[0]) } |
    ForEach-Object {
        $dir = $_
        $docx = Get-ChildItem -LiteralPath $dir.FullName -File -Filter "*.docx" |
            Where-Object { $_.Name -notmatch '^~\$' } |
            Sort-Object FullName |
            Select-Object -First 1

        $parts = $dir.Name -split '\.-', 2
        $annexNumber = [int]$parts[0]
        $annexName = if ($parts.Count -gt 1) { $parts[1].Trim() } else { $dir.Name }
        $text = if ($docx) { Get-DocxVisibleText -Path $docx.FullName } else { "" }
        $hasProjectName = if ($text) { [bool]($text -match [regex]::Escape($projectDisplayName)) } else { $false }
        $hasObjeto = [bool]($text -match '(?i)\b1\.\s*objeto\b')
        $hasAntecedentes = [bool]($text -match '(?i)\b2\.\s*(antecedentes|informacion de partida)\b')
        $hasNormativa = [bool]($text -match '(?i)\bnormativa\b')
        $pendingPattern = '(?i)\bpendiente\b|\bxxx\b|_{3,}|\[completar[^\]]*\]|nombre del proyecto|titulo del proyecto|insertar'
        $pendingMatches = if ($text) { [regex]::Matches($text, $pendingPattern).Count } else { 0 }
        $maturity = Get-MaturityLabel -HasDocx ([bool]$docx) -HasProjectName $hasProjectName -HasObjeto $hasObjeto -HasAntecedentes $hasAntecedentes -HasNormativa $hasNormativa -PendingMarkers $pendingMatches

        $rows.Add([pscustomobject]@{
            numero = $annexNumber
            anejo = $annexName
            docx = if ($docx) { $docx.Name } else { "" }
            estado = $maturity
            contiene_nombre_proyecto = $hasProjectName
            tiene_objeto = $hasObjeto
            tiene_antecedentes = $hasAntecedentes
            tiene_normativa = $hasNormativa
            marcadores_pendientes = $pendingMatches
            ultima_modificacion = if ($docx) { $docx.LastWriteTime.ToString("yyyy-MM-dd HH:mm") } else { "" }
        }) | Out-Null
    }

$jsonPath = Join-Path $outputResolved "matriz_estado_anejos.json"
$csvPath = Join-Path $outputResolved "matriz_estado_anejos.csv"
$mdPath = Join-Path $outputResolved "matriz_estado_anejos.md"

$rows | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

$md = New-Object System.Collections.Generic.List[string]
[void]$md.Add("# Matriz de estado de anejos")
[void]$md.Add("")
[void]$md.Add("- Proyecto: $projectDisplayName")
[void]$md.Add("- Fecha: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))")
[void]$md.Add("")
[void]$md.Add("| N | Anejo | Estado | Objeto | Antecedentes | Normativa | Pendientes |")
[void]$md.Add("|---|---|---|---|---|---|---:|")
foreach ($row in $rows) {
    [void]$md.Add("| $($row.numero) | $($row.anejo) | $($row.estado) | $($row.tiene_objeto) | $($row.tiene_antecedentes) | $($row.tiene_normativa) | $($row.marcadores_pendientes) |")
}
$md | Set-Content -LiteralPath $mdPath -Encoding UTF8

[pscustomobject]@{
    JsonPath = $jsonPath
    CsvPath = $csvPath
    MarkdownPath = $mdPath
    AnnexCount = $rows.Count
}
