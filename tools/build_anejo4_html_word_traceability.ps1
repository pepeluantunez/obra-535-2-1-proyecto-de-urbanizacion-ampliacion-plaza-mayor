param(
    [string]$Root = ""
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
. (Join-Path $PSScriptRoot 'civil3d_path_helpers.ps1')
. (Join-Path $PSScriptRoot 'xml_excel_helpers.ps1')

function Clean-HtmlText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $x = $Text -replace '<br\s*/?>', ' '
    $x = $x -replace '<.*?>', ''
    $x = [System.Net.WebUtility]::HtmlDecode($x)
    $x = $x -replace '&nbsp;', ' '
    $x = $x -replace '\s+', ' '
    return $x.Trim()
}

function Fix-Mojibake {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $x = $Text
    $x = $x -replace 'alineaci[^:<\s>]*n', 'alineacion'
    $x = $x -replace 'Alineaci[^:<\s>]*n', 'Alineacion'
    $x = $x -replace 'Descripci[^:<\s>]*n', 'Descripcion'
    $x = $x -replace 'Orientaci[^:<\s>]*n', 'Orientacion'
    $x = $x -replace 'Inclinaci[^:<\s>]*n', 'Inclinacion'
    return $x
}

function Remove-Diacritics {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $normalized = $Text.Normalize([Text.NormalizationForm]::FormD)
    $sb = [Text.StringBuilder]::new()
    foreach ($char in $normalized.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($char) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($char)
        }
    }
    return $sb.ToString().Normalize([Text.NormalizationForm]::FormC)
}

function Convert-ToCanonical {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $x = Remove-Diacritics (Fix-Mojibake $Text)
    $x = $x.ToUpperInvariant()
    $x = $x.Replace('AVENIDA', 'AV')
    $x = $x.Replace('AV.', 'AV')
    $x = $x.Replace('CARRETERA', 'CTRA')
    $x = $x.Replace('CTRA.', 'CTRA')
    $x = $x -replace '[^A-Z0-9]+', ' '
    $x = $x -replace '\s+', ' '
    return $x.Trim()
}

function Convert-PKToMeters {
    param([string]$PK)

    if ([string]::IsNullOrWhiteSpace($PK)) { return $null }
    if ($PK -match '^(?<k>\d+)\+(?<m>\d+(?:[.,]\d+)?)$') {
        $km = [double]$Matches['k'] * 1000.0
        $m = [double](($Matches['m']) -replace ',', '.')
        return [math]::Round(($km + $m), 3)
    }

    return $null
}

function Get-ExpectedHeadingFromVerticalName {
    param([string]$Name)

    $x = (Fix-Mojibake $Name).Trim()
    $x = $x -replace '^\s*RASANTE\s+', ''
    $x = $x -replace '\s+FINAL\s*$', ''
    if ($x -notmatch '^(EJE|ROTONDA)\b') {
        $x = 'EJE ' + $x
    }
    return $x.Trim()
}

function Parse-TableRows {
    param([string]$TableHtml)

    $rows = @()
    foreach ($row in [regex]::Matches($TableHtml, '<tr[^>]*>(?<row>.*?)</tr>', [Text.RegularExpressions.RegexOptions]::Singleline)) {
        $cells = @()
        foreach ($cell in [regex]::Matches($row.Groups['row'].Value, '<t[dh][^>]*>(?<cell>.*?)</t[dh]>', [Text.RegularExpressions.RegexOptions]::Singleline)) {
            $cells += (Clean-HtmlText $cell.Groups['cell'].Value)
        }
        if ($cells.Count -gt 0) {
            $rows += ,$cells
        }
    }
    return $rows
}

function Parse-AlignmentHtml {
    param(
        [string]$Path,
        [string]$Section,
        [ValidateSet('PI', 'INC')]
        [string]$Mode
    )

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $txt = Fix-Mojibake $raw
    $blocks = [regex]::Split($txt, '<hr[^>]*>')
    $summary = @()
    $details = @()

    foreach ($block in $blocks) {
        $nameMatch = [regex]::Match($block, 'Nombre de .*?:\s*(?<name>[^<\r\n]+)', [Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $nameMatch.Success) { continue }
        $intervalMatch = [regex]::Match($block, 'Intervalo de P\.K\.\:\s*inicio\:\s*(?<start>[^,]+),\s*fin\:\s*(?<end>[^<\r\n]+)', [Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $intervalMatch.Success) { continue }
        $tableMatch = [regex]::Match($block, '<table[^>]*>(?<table>.*?)</table>', [Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $tableMatch.Success) { continue }

        $name = Clean-HtmlText $nameMatch.Groups['name'].Value
        $pkStart = Clean-HtmlText $intervalMatch.Groups['start'].Value
        $pkEnd = Clean-HtmlText $intervalMatch.Groups['end'].Value
        $incrementMatch = [regex]::Match($block, 'Incremento de P\.K\.?\:?\s*(?<inc>[0-9\.,]+)', [Text.RegularExpressions.RegexOptions]::Singleline)
        $increment = if ($incrementMatch.Success) { Clean-HtmlText $incrementMatch.Groups['inc'].Value } else { '' }
        $tableRows = Parse-TableRows -TableHtml $tableMatch.Groups['table'].Value
        $dataRows = @($tableRows | Select-Object -Skip 1)

        $summary += [pscustomobject]@{
            Seccion         = $Section
            FuenteTipo      = if ($Mode -eq 'PI') { 'Planta_PI' } else { 'Planta_Incremental' }
            ArchivoFuente   = [IO.Path]::GetFileName($Path)
            NombreHtml      = $name
            HeadingEsperado = $name
            NombreClave     = Convert-ToCanonical $name
            HeadingClave    = Convert-ToCanonical $name
            PK_Inicio       = $pkStart
            PK_Fin          = $pkEnd
            PK_Inicio_m     = Convert-PKToMeters $pkStart
            PK_Fin_m        = Convert-PKToMeters $pkEnd
            Incremento_PK   = $increment
            FilasFuente     = $dataRows.Count
        }

        $rowIndex = 0
        foreach ($row in $dataRows) {
            $rowIndex++
            $details += [pscustomobject]@{
                Seccion       = $Section
                FuenteTipo    = if ($Mode -eq 'PI') { 'Planta_PI' } else { 'Planta_Incremental' }
                ArchivoFuente = [IO.Path]::GetFileName($Path)
                NombreHtml    = $name
                Fila          = $rowIndex
                Col1          = if ($row.Count -gt 0) { $row[0] } else { '' }
                Col2          = if ($row.Count -gt 1) { $row[1] } else { '' }
                Col3          = if ($row.Count -gt 2) { $row[2] } else { '' }
                Col4          = if ($row.Count -gt 3) { $row[3] } else { '' }
                Col5          = if ($row.Count -gt 4) { $row[4] } else { '' }
            }
        }
    }

    return [pscustomobject]@{
        Summary = @($summary)
        Details = @($details)
    }
}

function Parse-VavCurveHtml {
    param([string]$Path)

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $txt = Fix-Mojibake $raw
    $blocks = [regex]::Split($txt, '<hr[^>]*>')
    $summary = @()
    $details = @()

    foreach ($block in $blocks) {
        $nameMatch = [regex]::Match($block, 'Alineaci[^:]*vertical:\s*(?<name>[^<\r\n]+)', [Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $nameMatch.Success) { continue }
        $intervalMatch = [regex]::Match($block, 'Intervalo de P\.K\.\:\s*inicio\:\s*(?<start>[^,]+),\s*fin\:\s*(?<end>[^<\r\n]+)', [Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $intervalMatch.Success) { continue }
        $tableMatch = [regex]::Match($block, '<table[^>]*>(?<table>.*?)</table>', [Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $tableMatch.Success) { continue }

        $name = Clean-HtmlText $nameMatch.Groups['name'].Value
        $heading = Get-ExpectedHeadingFromVerticalName -Name $name
        $pkStart = Clean-HtmlText $intervalMatch.Groups['start'].Value
        $pkEnd = Clean-HtmlText $intervalMatch.Groups['end'].Value
        $eventRows = @()
        foreach ($row in (Parse-TableRows -TableHtml $tableMatch.Groups['table'].Value)) {
            if ($row.Count -lt 2) { continue }
            if ($row[0] -match '^P\.K\. de ' -or $row[0] -match '^Inclinacion de rasante') {
                $eventRows += ,$row
            }
        }

        $summary += [pscustomobject]@{
            Seccion         = '2.2.1'
            FuenteTipo      = 'Alzado_Singular'
            ArchivoFuente   = [IO.Path]::GetFileName($Path)
            NombreHtml      = $name
            HeadingEsperado = $heading
            NombreClave     = Convert-ToCanonical $name
            HeadingClave    = Convert-ToCanonical $heading
            PK_Inicio       = $pkStart
            PK_Fin          = $pkEnd
            PK_Inicio_m     = Convert-PKToMeters $pkStart
            PK_Fin_m        = Convert-PKToMeters $pkEnd
            Incremento_PK   = ''
            FilasFuente     = $eventRows.Count
        }

        $rowIndex = 0
        foreach ($row in $eventRows) {
            $rowIndex++
            $details += [pscustomobject]@{
                Seccion       = '2.2.1'
                FuenteTipo    = 'Alzado_Singular'
                ArchivoFuente = [IO.Path]::GetFileName($Path)
                NombreHtml    = $name
                Fila          = $rowIndex
                Etiqueta      = if ($row.Count -gt 0) { $row[0] } else { '' }
                Valor1        = if ($row.Count -gt 1) { $row[1] } else { '' }
                Valor2        = if ($row.Count -gt 2) { $row[2] } else { '' }
                Valor3        = if ($row.Count -gt 3) { $row[3] } else { '' }
            }
        }
    }

    return [pscustomobject]@{
        Summary = @($summary)
        Details = @($details)
    }
}

function Parse-VavIncrementalHtml {
    param([string]$Path)

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $txt = Fix-Mojibake $raw
    $blocks = [regex]::Split($txt, '<hr[^>]*>')
    $summary = @()
    $details = @()

    foreach ($block in $blocks) {
        $nameMatch = [regex]::Match($block, 'Alineaci[^:]*vertical:\s*(?<name>[^<\r\n]+)', [Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $nameMatch.Success) { continue }
        $intervalMatch = [regex]::Match($block, 'Intervalo de P\.K\.\:\s*inicio\:\s*(?<start>[^,]+),\s*fin\:\s*(?<end>[^<\r\n]+)', [Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $intervalMatch.Success) { continue }
        $tableMatch = [regex]::Match($block, '<table[^>]*>(?<table>.*?)</table>', [Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $tableMatch.Success) { continue }

        $name = Clean-HtmlText $nameMatch.Groups['name'].Value
        $heading = Get-ExpectedHeadingFromVerticalName -Name $name
        $pkStart = Clean-HtmlText $intervalMatch.Groups['start'].Value
        $pkEnd = Clean-HtmlText $intervalMatch.Groups['end'].Value
        $incrementMatch = [regex]::Match($block, 'Incremento de P\.K\:?\s*(?<inc>[0-9\.,]+)', [Text.RegularExpressions.RegexOptions]::Singleline)
        $increment = if ($incrementMatch.Success) { Clean-HtmlText $incrementMatch.Groups['inc'].Value } else { '' }
        $dataRows = @((Parse-TableRows -TableHtml $tableMatch.Groups['table'].Value) | Select-Object -Skip 1)

        $summary += [pscustomobject]@{
            Seccion         = '2.2.2'
            FuenteTipo      = 'Alzado_Incremental'
            ArchivoFuente   = [IO.Path]::GetFileName($Path)
            NombreHtml      = $name
            HeadingEsperado = $heading
            NombreClave     = Convert-ToCanonical $name
            HeadingClave    = Convert-ToCanonical $heading
            PK_Inicio       = $pkStart
            PK_Fin          = $pkEnd
            PK_Inicio_m     = Convert-PKToMeters $pkStart
            PK_Fin_m        = Convert-PKToMeters $pkEnd
            Incremento_PK   = $increment
            FilasFuente     = $dataRows.Count
        }

        $rowIndex = 0
        foreach ($row in $dataRows) {
            $rowIndex++
            $details += [pscustomobject]@{
                Seccion       = '2.2.2'
                FuenteTipo    = 'Alzado_Incremental'
                ArchivoFuente = [IO.Path]::GetFileName($Path)
                NombreHtml    = $name
                Fila          = $rowIndex
                PK            = if ($row.Count -gt 0) { $row[0] } else { '' }
                CotaRasante   = if ($row.Count -gt 1) { $row[1] } else { '' }
                PendientePct  = if ($row.Count -gt 2) { $row[2] } else { '' }
            }
        }
    }

    return [pscustomobject]@{
        Summary = @($summary)
        Details = @($details)
    }
}

function Get-ZipEntryText {
    param([System.IO.Compression.ZipArchiveEntry]$Entry)

    $stream = $Entry.Open()
    try {
        $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8, $true)
        try {
            return $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Get-WordParagraphs {
    param([string]$DocxPath)

    $archive = [System.IO.Compression.ZipFile]::OpenRead($DocxPath)
    try {
        $entry = $archive.GetEntry('word/document.xml')
        if (-not $entry) {
            throw "No se encuentra word/document.xml en $DocxPath"
        }

        [xml]$xml = Get-ZipEntryText -Entry $entry
        $ns = [Xml.XmlNamespaceManager]::new($xml.NameTable)
        $ns.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
        $paragraphs = $xml.SelectNodes('//w:body/w:p', $ns)
        $section = ''
        $rows = @()
        $index = 0
        foreach ($paragraph in $paragraphs) {
            $index++
            $styleNode = $paragraph.SelectSingleNode('w:pPr/w:pStyle', $ns)
            $styleId = if ($styleNode -and $styleNode.Attributes['w:val']) { $styleNode.Attributes['w:val'].Value } else { '' }
            $text = (($paragraph.SelectNodes('.//w:t', $ns) | ForEach-Object { $_.InnerText }) -join '')
            $text = Fix-Mojibake $text
            $text = ($text -replace '\s+', ' ').Trim()
            if ([string]::IsNullOrWhiteSpace($text)) { continue }

            switch -Regex ($text) {
                '^2\.1\.1\.' { $section = '2.1.1'; break }
                '^2\.1\.2\.' { $section = '2.1.2'; break }
                '^2\.2\.1\.' { $section = '2.2.1'; break }
                '^2\.2\.2\.' { $section = '2.2.2'; break }
            }

            $rows += [pscustomobject]@{
                Indice     = $index
                Seccion    = $section
                StyleId    = $styleId
                Texto      = $text
                TextoClave = Convert-ToCanonical $text
            }
        }
        return @($rows)
    }
    finally {
        $archive.Dispose()
    }
}

$projectRoot = Resolve-Civil3DProjectRoot -Root $Root
$baseDir = Resolve-Civil3DAnejo4Folder -Root $projectRoot
if ([string]::IsNullOrWhiteSpace($baseDir)) {
    throw 'No se localiza la carpeta del Anejo 4 para Civil 3D.'
}

$docxPath = Resolve-Civil3DAnejoDocx -FolderPath $baseDir -PreferredNames @(
    'Anexo 4 - Trazado, Replanteo y Mediciones Auxiliares.docx',
    'Anexo 4 - Replanteo y Mediciones Auxiliares.docx'
) -Pattern '^Anexo\s+4.*\.docx$'
if (-not $docxPath) {
    throw 'No se localiza el DOCX principal del Anejo 4.'
}

$sources = New-Object System.Collections.Generic.List[string]
$summaryRows = @()
$detailSheets = @()

$piPath = Resolve-Civil3DSourcePath -FolderPath $baseDir -FileName 'Informe de P.K. de PI de alineaciones.html'
if ($piPath) {
    $piData = Parse-AlignmentHtml -Path $piPath -Section '2.1.1' -Mode 'PI'
    $summaryRows += $piData.Summary
    $detailSheets += [pscustomobject]@{ Name = '01_Planta_PI'; Rows = $piData.Details }
    [void]$sources.Add('Informe de P.K. de PI de alineaciones.html')
}

$incPath = Resolve-Civil3DSourcePath -FolderPath $baseDir -FileName 'Informe de P.K. incremental de alineaciones.html'
if ($incPath) {
    $incData = Parse-AlignmentHtml -Path $incPath -Section '2.1.2' -Mode 'INC'
    $summaryRows += $incData.Summary
    $detailSheets += [pscustomobject]@{ Name = '02_Planta_INC'; Rows = $incData.Details }
    [void]$sources.Add('Informe de P.K. incremental de alineaciones.html')
}

$curvePath = Resolve-Civil3DSourcePath -FolderPath $baseDir -FileName 'Informe de curva y P.K. de VAV.html'
if ($curvePath) {
    $curveData = Parse-VavCurveHtml -Path $curvePath
    $summaryRows += $curveData.Summary
    $detailSheets += [pscustomobject]@{ Name = '03_Alzado_Sing'; Rows = $curveData.Details }
    [void]$sources.Add('Informe de curva y P.K. de VAV.html')
}

$vavIncPath = Resolve-Civil3DSourcePath -FolderPath $baseDir -FileName 'Informe de P.K. incremental de VAV.html'
if ($vavIncPath) {
    $vavIncData = Parse-VavIncrementalHtml -Path $vavIncPath
    $summaryRows += $vavIncData.Summary
    $detailSheets += [pscustomobject]@{ Name = '04_Alzado_INC'; Rows = $vavIncData.Details }
    [void]$sources.Add('Informe de P.K. incremental de VAV.html')
}

if ($summaryRows.Count -eq 0) {
    throw 'No se detectan HTML reutilizables de Civil 3D en el Anejo 4.'
}

$wordParagraphs = Get-WordParagraphs -DocxPath $docxPath
$matrix = @()
foreach ($row in $summaryRows) {
    $sectionParagraphs = @($wordParagraphs | Where-Object { $_.Seccion -eq $row.Seccion })
    $visibleHits = @($sectionParagraphs | Where-Object { $_.TextoClave -like ('*' + $row.NombreClave + '*') })
    $headingLooseHits = @($sectionParagraphs | Where-Object { $_.TextoClave -eq $row.HeadingClave -or $_.TextoClave -like ('*' + $row.HeadingClave + '*') })
    $headingStyleHits = @($sectionParagraphs | Where-Object { $_.StyleId -eq 'Ttulo5' -and ($_.TextoClave -eq $row.HeadingClave -or $_.TextoClave -like ('*' + $row.HeadingClave + '*')) })

    $estado = if ($headingStyleHits.Count -gt 0 -and $visibleHits.Count -gt 0) {
        'OK'
    }
    elseif ($visibleHits.Count -gt 0 -and $headingLooseHits.Count -gt 0) {
        'Visible sin Titulo5'
    }
    elseif ($visibleHits.Count -gt 0) {
        'Visible sin heading'
    }
    else {
        'Falta en Word'
    }

    $accion = switch ($estado) {
        'OK' { 'Sin accion' }
        'Visible sin Titulo5' { 'Aplicar estilo Titulo 5 al nombre del eje' }
        'Visible sin heading' { 'Crear heading previo y revisar maquetacion de tabla' }
        default {
            if ($row.Seccion -like '2.1.*') {
                'Insertar bloque nuevo desde HTML y revisar tabla asociada'
            }
            else {
                'Incorporar bloque de alzado o justificar ausencia'
            }
        }
    }

    $matrix += [pscustomobject]@{
        Seccion               = $row.Seccion
        FuenteTipo            = $row.FuenteTipo
        ArchivoFuente         = $row.ArchivoFuente
        NombreHtml            = $row.NombreHtml
        HeadingEsperado       = $row.HeadingEsperado
        PK_Inicio             = $row.PK_Inicio
        PK_Fin                = $row.PK_Fin
        Incremento_PK         = $row.Incremento_PK
        FilasFuente           = $row.FilasFuente
        Word_Huellas_Visibles = $visibleHits.Count
        Word_Headings_Sueltos = $headingLooseHits.Count
        Word_Headings_Titulo5 = $headingStyleHits.Count
        EstadoWord            = $estado
        AccionRecomendada     = $accion
    }
}

$control = @(
    [pscustomobject]@{ Regla = 'HTML de planta'; Accion = 'Regenerar paquete de PK y matriz HTML-Word'; Salida = 'Anejo4_PK_* + Anejo4_HTML_WORD_Trazabilidad.*' }
    [pscustomobject]@{ Regla = 'HTML de alzado'; Accion = 'Regenerar matriz HTML-Word y revisar headings del 2.2'; Salida = 'Anejo4_HTML_WORD_Trazabilidad.*' }
    [pscustomobject]@{ Regla = 'Word principal'; Accion = 'Aplicar solo cambios puntuales'; Salida = 'DOCX principal consistente' }
    [pscustomobject]@{ Regla = 'Cierre'; Accion = 'Pasar checks de mojibake, tablas y trazabilidad'; Salida = 'Cierre verificable' }
)

$workbookPath = Join-Path $baseDir 'Anejo4_HTML_WORD_Trazabilidad.xls'
$markdownPath = Join-Path $baseDir 'Anejo4_HTML_WORD_Trazabilidad.md'
$sheetObjects = @((New-ExcelObjectSheet '00_Matriz' $matrix))
foreach ($sheet in $detailSheets) {
    $sheetObjects += (New-ExcelObjectSheet $sheet.Name $sheet.Rows)
}
$sheetObjects += (New-ExcelObjectSheet '05_Word' ($wordParagraphs | Where-Object { $_.Seccion -like '2.*' }))
$sheetObjects += (New-ExcelObjectSheet '06_Control' $control)
Write-ExcelXmlWorkbook -Path $workbookPath -Sheets $sheetObjects

$missing = @($matrix | Where-Object { $_.EstadoWord -eq 'Falta en Word' })
$styleOnly = @($matrix | Where-Object { $_.EstadoWord -eq 'Visible sin Titulo5' })
$okCount = @($matrix | Where-Object { $_.EstadoWord -eq 'OK' }).Count
$missingNames = if ($missing.Count -gt 0) { ($missing | ForEach-Object { $_.NombreHtml } | Sort-Object -Unique) -join ', ' } else { 'Ninguno' }
$styleNames = if ($styleOnly.Count -gt 0) { ($styleOnly | ForEach-Object { $_.HeadingEsperado } | Sort-Object -Unique) -join ', ' } else { 'Ninguno' }

$markdown = @"
# Anejo 4 - trazabilidad HTML Word

- Fuentes integradas:
$((@($sources) | ForEach-Object { "  - $_" }) -join "`r`n")
- Bloques HTML analizados: $($summaryRows.Count)
- Bloques con huella correcta en Word: $okCount
- Bloques visibles en Word pero sin heading Titulo 5: $($styleOnly.Count)
- Bloques ausentes en Word: $($missing.Count)
- Ausencias detectadas: $missingNames
- Ajustes de heading pendientes: $styleNames

## Entregables

- Anejo4_HTML_WORD_Trazabilidad.xls
- Anejo4_HTML_WORD_Trazabilidad.md
"@

[IO.File]::WriteAllText($markdownPath, $markdown, [Text.Encoding]::UTF8)
Write-Output "OK - Trazabilidad HTML-Word generada en: $baseDir"
