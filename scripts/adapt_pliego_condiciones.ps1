param(
    [string]$SourceDocPath = '.\DOCS - PLANTILLAS\PLIEGO DE CONDICIONES\PLANTILLA_PLIEGO_CONDICIONES_BASE.docx',
    [string]$DestinationDocPath = '',
    [string]$ConfigPath = '.\CONFIG\pliego_condiciones.template.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

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

function Write-ZipEntryText {
    param(
        [System.IO.Compression.ZipArchive]$Archive,
        [string]$EntryName,
        [string]$Content
    )

    $existing = $Archive.GetEntry($EntryName)
    if ($null -ne $existing) {
        $existing.Delete()
    }

    $entry = $Archive.CreateEntry($EntryName, [System.IO.Compression.CompressionLevel]::Optimal)
    $stream = $entry.Open()
    try {
        $writer = New-Object System.IO.StreamWriter($stream, [System.Text.UTF8Encoding]::new($false))
        try {
            $writer.Write($Content)
        } finally {
            $writer.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Get-ComparableText {
    param([string]$Text)

    $normalized = $Text.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $normalized.ToCharArray()) {
        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
        if ($category -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($ch)
        }
    }

    $plain = $sb.ToString().Normalize([Text.NormalizationForm]::FormC)
    $plain = $plain.Replace(([string][char]0x2026), '...')
    $plain = $plain.Replace(([string][char]0x2013), '-')
    $plain = $plain.Replace(([string][char]0x2014), '-')
    $plain = $plain.Replace(([string][char]0x00A0), ' ')
    return (($plain -replace '\s+', ' ').Trim()).ToUpperInvariant()
}

function Get-ParagraphText {
    param([System.Xml.XmlElement]$Paragraph)

    $texts = $Paragraph.GetElementsByTagName('w:t')
    if ($null -eq $texts -or $texts.Count -eq 0) {
        return ''
    }

    $parts = foreach ($node in $texts) { $node.InnerText }
    return ($parts -join '')
}

function Set-ParagraphText {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [string]$Text
    )

    $wordNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    $document = $Paragraph.OwnerDocument
    $runs = $Paragraph.GetElementsByTagName('w:r')
    $runProps = $null
    if ($runs.Count -gt 0) {
        $firstRun = $runs.Item(0)
        $props = $firstRun.GetElementsByTagName('w:rPr')
        if ($props.Count -gt 0) {
            $runProps = $props.Item(0).CloneNode($true)
        }
    }

    $toRemove = @()
    foreach ($child in $Paragraph.ChildNodes) {
        if ($child.LocalName -ne 'pPr') {
            $toRemove += $child
        }
    }
    foreach ($child in $toRemove) {
        [void]$Paragraph.RemoveChild($child)
    }

    $run = $document.CreateElement('w', 'r', $wordNs)
    if ($null -ne $runProps) {
        [void]$run.AppendChild($runProps)
    }

    $textNode = $document.CreateElement('w', 't', $wordNs)
    $textNode.InnerText = $Text
    [void]$run.AppendChild($textNode)
    [void]$Paragraph.AppendChild($run)
}

function Replace-MetadataValue {
    param(
        [string]$XmlText,
        [string]$TagName,
        [string]$NewValue
    )

    return [regex]::Replace(
        $XmlText,
        "(?s)(<$TagName>)(.*?)(</$TagName>)",
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($match)
            return $match.Groups[1].Value + [System.Security.SecurityElement]::Escape($NewValue) + $match.Groups[3].Value
        },
        1
    )
}

function Replace-WholeXmlText {
    param(
        [string]$XmlText,
        [string]$OldText,
        [string]$NewText
    )

    $escapedOld = [regex]::Escape($OldText)
    return [regex]::Replace(
        $XmlText,
        $escapedOld,
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($match)
            return $NewText
        }
    )
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$projectCode = [string]$config.project_code
$projectHeading = [string]$config.project_title_upper
$projectCover = [string]$config.project_name_cover_upper
$municipality = [string]$config.municipality_upper
$promoterCover = 'PROMOTOR:' + [string]$config.promoter_cover
$article1002 = 'El presente Pliego sera de aplicacion a la construccion, direccion e inspeccion de las obras del {0}, {1}.' -f $config.project_name_sentence.ToUpperInvariant(), $config.municipality_upper
$article102a = 'Todas las obras mencionadas se ajustaran a los planos, anejos y presupuesto del {0}, {1}, ateniendose a lo especificado en el presente Pliego de Condiciones y a las instrucciones que pueda dictar la Direccion Facultativa.' -f $config.project_name_sentence, $config.municipality
$article102b = [string]$config.scope_summary_paragraph
$utilityNormsClause = [string]$config.utility_norms_clause
$lightingHeading = [string]$config.conditional_headings.lighting
$irrigationNetworkHeading = [string]$config.conditional_headings.irrigation_network
$telecomHeading = [string]$config.conditional_headings.telecom
$powerHeading = [string]$config.conditional_headings.power
$irrigationSubspecHeading = [string]$config.conditional_headings.irrigation_subspec
$landscapingScopeClause = [string]$config.landscaping_scope_clause
$irrigationObjectClause = [string]$config.irrigation_object_clause
$coreTitle = [string]$config.docx_core_title
$coreSubject = [string]$config.docx_core_subject

if ([string]::IsNullOrWhiteSpace($DestinationDocPath)) {
    $DestinationDocPath = '.\{0}_POU_PLIEGO DE CONDICIONES.docx' -f $projectCode
}

$resolvedSource = (Resolve-Path -LiteralPath $SourceDocPath).Path
$destinationAbsolute = if ([System.IO.Path]::IsPathRooted($DestinationDocPath)) {
    $DestinationDocPath
} else {
    Join-Path (Get-Location) $DestinationDocPath
}

$destinationDir = Split-Path -Parent $destinationAbsolute
if (-not (Test-Path -LiteralPath $destinationDir)) {
    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
}

Copy-Item -LiteralPath $resolvedSource -Destination $destinationAbsolute -Force

$archive = [System.IO.Compression.ZipFile]::Open($destinationAbsolute, [System.IO.Compression.ZipArchiveMode]::Update)
try {
    $documentEntry = $archive.GetEntry('word/document.xml')
    if ($null -eq $documentEntry) {
        throw "No se ha encontrado word/document.xml en $destinationAbsolute"
    }

    [xml]$document = Read-ZipEntryText -Entry $documentEntry
    $changes = 0
    foreach ($paragraph in $document.GetElementsByTagName('w:p')) {
        $original = Get-ParagraphText -Paragraph $paragraph
        if ([string]::IsNullOrWhiteSpace($original)) {
            continue
        }

        $comparable = Get-ComparableText -Text $original
        $replacement = $null

        if ($comparable -eq (Get-ComparableText 'PROYECTO ORDINARIO DE URBANIZACION')) {
            $replacement = $projectHeading
        } elseif ($comparable -eq (Get-ComparableText 'MEJORA DE LA CARRETERA DE GUADALMAR')) {
            $replacement = $projectCover
        } elseif ($comparable -eq (Get-ComparableText 'Artículo 698.- INSTALACION DE ALUMBRADO')) {
            $replacement = $lightingHeading
        } elseif ($comparable -eq (Get-ComparableText 'Artículo 699.- RED DE RIEGO')) {
            $replacement = $irrigationNetworkHeading
        } elseif ($comparable -eq (Get-ComparableText 'Artículo 704.- LINEAS TELEFONICAS')) {
            $replacement = $telecomHeading
        } elseif ($comparable -eq (Get-ComparableText 'Artículo 705.- LINEAS ELECTRICAS')) {
            $replacement = $powerHeading
        } elseif ($comparable -eq (Get-ComparableText 'PROMOTOR:Ayuntamiento de Malaga / Gerencia Municipal de Urbanismo (GMU)')) {
            $replacement = $promoterCover
        } elseif ($comparable -eq (Get-ComparableText 'El presente Pliego sera de aplicacion a la construccion, direccion e inspeccion de las obras del PROYECTO ORDINARIO DE URBANIZACION DE MEJORA DE LA CARRETERA DE GUADALMAR, MALAGA.')) {
            $replacement = $article1002
        } elseif ($comparable -eq (Get-ComparableText 'Todas las obras mencionadas se ajustaran a los planos, anejos y presupuesto del Proyecto Ordinario de Urbanizacion de Mejora de la Carretera de Guadalmar, Malaga, ateniendose a lo especificado en el presente Pliego de Condiciones y a las instrucciones que pueda dictar la Direccion Facultativa.')) {
            $replacement = $article102a
        } elseif ($comparable -eq (Get-ComparableText 'Las obras comprendidas en el presente Proyecto incluyen, entre otras, las demoliciones y reposiciones necesarias, el movimiento de tierras, la formacion de explanada, firmes y pavimentos, el drenaje superficial y subterraneo, las redes de saneamiento pluvial y fecal, la red de abastecimiento de agua potable, la red de riego y agua regenerada, las canalizaciones electricas y de telecomunicaciones asociadas, la senalizacion, la jardineria y reforestacion, asi como las actuaciones de control de calidad, gestion de residuos y seguridad y salud vinculadas a la mejora de la Carretera de Guadalmar y su entorno urbano inmediato.')) {
            $replacement = $article102b
        } elseif ($comparable -eq (Get-ComparableText 'Normas tecnicas de EMASA y de la compania distribuidora electrica, asi como las prescripciones de los servicios municipales competentes del Ayuntamiento de Malaga.')) {
            $replacement = $utilityNormsClause
        } elseif ($comparable -eq (Get-ComparableText 'El presente documento se refiere a la forma de realizar los trabajos y a las condiciones que han de reunir las unidades de obras y materiales para la ejecucion del Proyecto de Ajardinamiento, cuya descripcion y detalles aparecen en la memoria del mismo. Las estipulaciones del presente pliego afectaran a la totalidad del proyecto, salvo en los casos que aparezcan especificaciones en contra en su Memoria, Planos o Presupuestos. En tal caso prevaleceran las del Proyecto.')) {
            $replacement = $landscapingScopeClause
        } elseif ($comparable -eq (Get-ComparableText '3.5.- PLIEGO DE CONDICIONES DE LA INSTALACION DE RIEGO')) {
            $replacement = $irrigationSubspecHeading
        } elseif ($comparable -eq (Get-ComparableText 'El presente Pliego de Condiciones facultativas tiene por objeto definir y fijar las condiciones tecnicas y economicas de los materiales y su ejecucion, asi como las condiciones generales que han de regir en la ejecucion de las instalaciones de riego de las zonas verdes objeto del presente proyecto.')) {
            $replacement = $irrigationObjectClause
        }

        if ($null -ne $replacement -and $replacement -ne $original) {
            Set-ParagraphText -Paragraph $paragraph -Text $replacement
            $changes++
        }
    }

    $documentXmlOut = $document.OuterXml
    $documentXmlOut = Replace-WholeXmlText -XmlText $documentXmlOut -OldText 'Artículo 698.- INSTALACION DE ALUMBRADO' -NewText $lightingHeading
    $documentXmlOut = Replace-WholeXmlText -XmlText $documentXmlOut -OldText 'Artículo 699.- RED DE RIEGO' -NewText $irrigationNetworkHeading
    $documentXmlOut = Replace-WholeXmlText -XmlText $documentXmlOut -OldText 'Artículo 704.- LINEAS TELEFONICAS' -NewText $telecomHeading
    $documentXmlOut = Replace-WholeXmlText -XmlText $documentXmlOut -OldText 'Artículo 704.- LINEAS TELEFÓNICAS' -NewText $telecomHeading
    $documentXmlOut = Replace-WholeXmlText -XmlText $documentXmlOut -OldText 'Artículo 705.- LINEAS ELECTRICAS' -NewText $powerHeading

    if ($changes -gt 0 -or $documentXmlOut -ne $document.OuterXml) {
        Write-ZipEntryText -Archive $archive -EntryName 'word/document.xml' -Content $documentXmlOut
    }

    $footerEntry = $archive.GetEntry('word/footer1.xml')
    if ($null -ne $footerEntry) {
        $footerXml = Read-ZipEntryText -Entry $footerEntry
        $footerXml = $footerXml.Replace('535.2.2', $projectCode)
        Write-ZipEntryText -Archive $archive -EntryName 'word/footer1.xml' -Content $footerXml
    }

    $coreEntry = $archive.GetEntry('docProps/core.xml')
    if ($null -ne $coreEntry) {
        $coreXml = Read-ZipEntryText -Entry $coreEntry
        $coreXml = Replace-MetadataValue -XmlText $coreXml -TagName 'dc:title' -NewValue $coreTitle
        $coreXml = Replace-MetadataValue -XmlText $coreXml -TagName 'dc:subject' -NewValue $coreSubject
        Write-ZipEntryText -Archive $archive -EntryName 'docProps/core.xml' -Content $coreXml
    }

    Write-Output "UPDATED DOCX: $destinationAbsolute ($changes parrafos + pie + metadatos)"
} finally {
    $archive.Dispose()
}
