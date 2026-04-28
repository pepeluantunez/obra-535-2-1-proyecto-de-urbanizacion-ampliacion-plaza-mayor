param(
    [switch]$CreateMemory = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$projectName = 'Proyecto de Urbanizacion - Ampliacion Plaza Mayor'
$projectCover = 'AMPLIACION PLAZA MAYOR, MALAGA'
$projectHeading = 'PROYECTO DE URBANIZACION'

$commonAntecedents = 'Como informacion de partida se dispone del dossier base de Plaza Mayor, de los antecedentes urbanisticos, ambientales, administrativos y sectoriales ya recopilados y de la estructura documental preparada para este proyecto. Cuando ha resultado util, se han conservado referencias metodologicas o soportes donor unicamente como guia documental o de maquetacion, sin trasladar automaticamente sus datos tecnicos al presente expediente.'
$commonNormativa = @(
    'Planeamiento urbanistico y documentacion administrativa vigente del ambito Plaza Mayor.'
    'Informes sectoriales, condicionantes de tramitacion y documentacion tecnica de partida ya recopilada.'
    'Normativa tecnica especifica del presente anejo, a concretar y citar expresamente en la redaccion definitiva.'
)

$annexes = @(
    [pscustomobject]@{ Number = 1; RelativePath = 'DOCS - ANEJOS\1.- Reportaje Fotografico\Anexo 1 - Reportaje Fotografico.docx'; Title = 'REPORTAJE FOTOGRAFICO'; ObjectText = 'El presente anejo tiene por objeto dejar identificado el alcance del reportaje fotografico del Proyecto de Urbanizacion - Ampliacion Plaza Mayor, ordenando la documentacion grafica de partida y fijando un marco profesional para su posterior desarrollo. En esta fase inicial se incorpora unicamente la informacion base disponible y la estructura documental del anejo, quedando pendiente la carga de material grafico especifico del ambito.'; AdditionalAntecedents = '' }
    [pscustomobject]@{ Number = 2; RelativePath = 'DOCS - ANEJOS\2.- Cartografia y Topografia\Anexo 2 - Cartografia y Topografia.docx'; Title = 'CARTOGRAFIA Y TOPOGRAFIA'; ObjectText = 'El presente anejo tiene por objeto iniciar la redaccion del bloque de cartografia y topografia del Proyecto de Urbanizacion - Ampliacion Plaza Mayor, identificando la informacion de partida disponible y la estructura documental necesaria para su desarrollo. El contenido tecnico definitivo se completara cuando se incorporen y contrasten los soportes topograficos y cartograficos propios del ambito.'; AdditionalAntecedents = '' }
    [pscustomobject]@{ Number = 3; RelativePath = 'DOCS - ANEJOS\3.- Estudio Geotecnico\Anexo 3 - Estudio Geotecnico.docx'; Title = 'ESTUDIO GEOTECNICO'; ObjectText = 'El presente anejo tiene por objeto dejar iniciado el estudio geotecnico asociado al Proyecto de Urbanizacion - Ampliacion Plaza Mayor, encajando la documentacion disponible dentro de una estructura tecnica homogenea con el resto del expediente. En esta fase se limita a ordenar la base documental y a senalar la necesidad de incorporar y verificar los datos geotecnicos especificos del ambito.'; AdditionalAntecedents = '' }
    [pscustomobject]@{ Number = 4; RelativePath = 'DOCS - ANEJOS\4.- Trazado, Replanteo y Mediciones Auxiliares\Anexo 4 - Trazado, Replanteo y Mediciones Auxiliares.docx'; Title = 'TRAZADO, REPLANTEO Y MEDICIONES AUXILIARES'; ObjectText = 'El presente anejo tiene por objeto iniciar la redaccion del trazado, replanteo y mediciones auxiliares del Proyecto de Urbanizacion - Ampliacion Plaza Mayor, ordenando la informacion base y fijando el criterio de trabajo para su posterior desarrollo tecnico. La definicion geometrica, las mediciones y la trazabilidad definitiva se completaran con la documentacion especifica del ambito y sus exportaciones contrastadas.'; AdditionalAntecedents = 'En los bloques vinculados a trazado y redes se preve reutilizar la misma familia documental de soporte empleada en Guadalmar, adaptandola integramente a las denominaciones, alineaciones y resultados propios de Plaza Mayor.' }
    [pscustomobject]@{ Number = 5; RelativePath = 'DOCS - ANEJOS\5.- Dimensionamiento del Firme\Anexo 5 - Dimensionamiento del Firme.docx'; Title = 'DIMENSIONAMIENTO DEL FIRME'; ObjectText = 'El presente anejo tiene por objeto iniciar la redaccion del dimensionamiento del firme del Proyecto de Urbanizacion - Ampliacion Plaza Mayor, dejando identificado el marco documental de partida y la estructura de trabajo del anejo. Las comprobaciones, hipotesis y calculos definitivos se incorporaran una vez se consoliden los datos especificos de trafico, plataforma y solucion constructiva del ambito.'; AdditionalAntecedents = '' }
    [pscustomobject]@{ Number = 6; RelativePath = 'DOCS - ANEJOS\6.- Red de Agua Potable\Anexo 6 - Red de Agua Potable.docx'; Title = 'RED DE AGUA POTABLE'; ObjectText = 'El presente anejo tiene por objeto iniciar la redaccion de la red de agua potable del Proyecto de Urbanizacion - Ampliacion Plaza Mayor, ordenando la documentacion actualmente disponible y fijando un arranque documental coherente con el resto del expediente. El diseno hidraulico y la definicion tecnica final de la red se completaran cuando se incorporen los datos de trazado, demanda, conexion y comprobacion propios del proyecto.'; AdditionalAntecedents = '' }
    [pscustomobject]@{ Number = 7; RelativePath = 'DOCS - ANEJOS\7.- Red de Saneamiento - Pluviales\Anexo 7 - Red de Saneamiento - Pluviales.docx'; Title = 'RED DE SANEAMIENTO. PLUVIALES'; ObjectText = 'El presente anejo tiene por objeto iniciar la redaccion de la red de saneamiento de pluviales del Proyecto de Urbanizacion - Ampliacion Plaza Mayor, identificando la informacion base disponible y la estructura documental necesaria para su desarrollo. La definicion hidraulica y la trazabilidad final de la red quedaran condicionadas a la incorporacion de reportes, tablas y exportaciones especificas del ambito.'; AdditionalAntecedents = 'En los bloques vinculados a trazado y redes se preve reutilizar la misma familia documental de soporte empleada en Guadalmar, adaptandola integramente a las denominaciones, alineaciones y resultados propios de Plaza Mayor.' }
    [pscustomobject]@{ Number = 8; RelativePath = 'DOCS - ANEJOS\8.- Red de Saneamiento - Fecales\Anexo 8 - Red de Saneamiento - Fecales.docx'; Title = 'RED DE SANEAMIENTO. FECALES'; ObjectText = 'El presente anejo tiene por objeto iniciar la redaccion de la red de saneamiento de fecales del Proyecto de Urbanizacion - Ampliacion Plaza Mayor, identificando la informacion base disponible y la estructura documental necesaria para su desarrollo. La definicion hidraulica y la trazabilidad final de la red quedaran condicionadas a la incorporacion de reportes, tablas y exportaciones especificas del ambito.'; AdditionalAntecedents = 'En los bloques vinculados a trazado y redes se preve reutilizar la misma familia documental de soporte empleada en Guadalmar, adaptandola integramente a las denominaciones, alineaciones y resultados propios de Plaza Mayor.' }
    [pscustomobject]@{ Number = 9; RelativePath = 'DOCS - ANEJOS\9.- Red de Media Tension\Anexo 9 - Red de Media Tension.docx'; Title = 'RED DE MEDIA TENSION'; ObjectText = 'El presente anejo tiene por objeto iniciar la redaccion de la red de media tension del Proyecto de Urbanizacion - Ampliacion Plaza Mayor, ordenando la documentacion base y fijando el marco inicial de trabajo del anejo. La definicion tecnica y la justificacion sectorial definitiva se incorporaran cuando se consoliden los datos propios del ambito y sus condicionantes de suministro.'; AdditionalAntecedents = '' }
    [pscustomobject]@{ Number = 10; RelativePath = 'DOCS - ANEJOS\10.- Red de Baja Tension\Anexo 10 - Red de Baja Tension.docx'; Title = 'RED DE BAJA TENSION'; ObjectText = 'El presente anejo tiene por objeto iniciar la redaccion de la red de baja tension del Proyecto de Urbanizacion - Ampliacion Plaza Mayor, ordenando la documentacion base disponible y fijando la estructura documental de este bloque. La solucion tecnica definitiva se completara cuando se incorporen las determinaciones de proyecto, el dimensionado y las condiciones de suministro aplicables al ambito.'; AdditionalAntecedents = '' }
    [pscustomobject]@{ Number = 11; RelativePath = 'DOCS - ANEJOS\11.- Red de Alumbrado\Anexo 11 - Red de Alumbrado.docx'; Title = 'RED DE ALUMBRADO'; ObjectText = 'El presente anejo tiene por objeto iniciar la redaccion de la red de alumbrado del Proyecto de Urbanizacion - Ampliacion Plaza Mayor, organizando la informacion base y adecuando el documento a la plantilla general del expediente. La definicion luminica, electrica y de implantacion final se completara cuando se disponga de los datos especificos y de la comprobacion tecnica correspondiente.'; AdditionalAntecedents = '' }
    [pscustomobject]@{ Number = 12; RelativePath = 'DOCS - ANEJOS\12.- Accesibilidad\Anexo 12 - Accesibilidad.docx'; Title = 'ACCESIBILIDAD'; ObjectText = 'El presente anejo tiene por objeto iniciar la redaccion del estudio de accesibilidad del Proyecto de Urbanizacion - Ampliacion Plaza Mayor, ordenando la base documental disponible y fijando el alcance inicial de este bloque. La comprobacion normativa detallada y la definicion final de soluciones accesibles se incorporaran cuando se consolide la informacion geometrica y de diseno del ambito.'; AdditionalAntecedents = '' }
    [pscustomobject]@{ Number = 13; RelativePath = 'DOCS - ANEJOS\13.- Estudio de Gestion de Residuos\Anexo 13 - Estudio de Gestion de Residuos.docx'; DonorDocPath = 'DOCS - ANEJOS\Plantillas\Por Anejo\13-13-estudio-de-gestion-de-residuos\10_donor_docx\Anexo 13 - Estudio de Gestión de Residuos.docx'; Title = 'ESTUDIO DE GESTION DE RESIDUOS'; ObjectText = 'El presente anejo tiene por objeto iniciar la redaccion del estudio de gestion de residuos del Proyecto de Urbanizacion - Ampliacion Plaza Mayor, ordenando la informacion base disponible y dejando preparada la estructura documental para su desarrollo posterior. La cuantificacion definitiva y la trazabilidad completa del anejo se incorporaran cuando se contrasten las mediciones reales y la planificacion de obra.'; AdditionalAntecedents = 'Ademas, se dispone de un libro de calculo de residuos incorporado como soporte inicial, pendiente de revision y recalibracion con las mediciones reales del proyecto.' }
    [pscustomobject]@{ Number = 14; RelativePath = 'DOCS - ANEJOS\14.- Control de Calidad\Anexo 14 - Control de Calidad.docx'; DonorDocPath = 'DOCS - ANEJOS\Plantillas\Por Anejo\14-14-control-de-calidad\10_donor_docx\Anexo 14 - Control de calidad.docx'; Title = 'CONTROL DE CALIDAD'; ObjectText = 'El presente anejo tiene por objeto iniciar la redaccion del plan de control de calidad del Proyecto de Urbanizacion - Ampliacion Plaza Mayor, ordenando la documentacion de partida y dejando preparado el documento para su desarrollo tecnico posterior. La programacion detallada de controles, ensayos y frecuencias se completara cuando se definan con precision las unidades y procesos de obra del proyecto.'; AdditionalAntecedents = 'Ademas, se dispone de un libro base de control de calidad incorporado como soporte inicial, pendiente de adaptacion completa a las unidades reales del proyecto.' }
    [pscustomobject]@{ Number = 15; RelativePath = 'DOCS - ANEJOS\15.- Plan de Obra\Anexo 15 - Plan de Obra.docx'; Title = 'PLAN DE OBRA'; ObjectText = 'El presente anejo tiene por objeto iniciar la redaccion del plan de obra del Proyecto de Urbanizacion - Ampliacion Plaza Mayor, dejando estructurado el documento y ordenando la informacion de partida actualmente disponible. La programacion temporal detallada, sus rendimientos y la coordinacion definitiva con las fases de ejecucion se completaran cuando se consoliden las mediciones y la solucion tecnica del proyecto.'; AdditionalAntecedents = '' }
    [pscustomobject]@{ Number = 16; RelativePath = 'DOCS - ANEJOS\16.- Comunicaciones con Companias Suministradoras\Anexo 16 - Comunicaciones con Companias Suministradoras.docx'; Title = 'COMUNICACIONES CON COMPANIAS SUMINISTRADORAS'; ObjectText = 'El presente anejo tiene por objeto iniciar la redaccion del bloque de comunicaciones con companias suministradoras del Proyecto de Urbanizacion - Ampliacion Plaza Mayor, ordenando la documentacion base disponible y fijando el marco de trabajo del anejo. La incorporacion de respuestas, condicionantes y gestiones especificas de cada servicio afectado se completara conforme avance la tramitacion del expediente.'; AdditionalAntecedents = '' }
    [pscustomobject]@{ Number = 17; RelativePath = 'DOCS - ANEJOS\17.- Seguridad y Salud\Anexo 17 - Estudio de Seguridad y Salud.docx'; Title = 'ESTUDIO DE SEGURIDAD Y SALUD'; ObjectText = 'El presente anejo tiene por objeto iniciar la redaccion del estudio de seguridad y salud del Proyecto de Urbanizacion - Ampliacion Plaza Mayor, ordenando la informacion base disponible y dejando preparado el soporte documental para su posterior desarrollo tecnico. La identificacion completa de riesgos, medidas preventivas, mediciones y presupuesto especificos del ambito se incorporara cuando se consolide la solucion de proyecto y se contrasten los soportes auxiliares.'; AdditionalAntecedents = 'Ademas, se dispone de soportes iniciales de dimensionado y de un presupuesto donor de seguridad y salud, pendientes de revision integral y adaptacion completa a Plaza Mayor.' }
    [pscustomobject]@{ Number = 18; RelativePath = 'DOCS - ANEJOS\18.- Telecomunicaciones\Anexo 18 - Telecomunicaciones.docx'; Title = 'TELECOMUNICACIONES'; ObjectText = 'El presente anejo tiene por objeto iniciar la redaccion del bloque de telecomunicaciones del Proyecto de Urbanizacion - Ampliacion Plaza Mayor, ordenando la documentacion base y adecuando el documento a la estructura general del expediente. La definicion tecnica definitiva y sus condicionantes sectoriales se completaran cuando se incorporen las necesidades, trazados y comprobaciones propias del ambito.'; AdditionalAntecedents = '' }
)

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

function Update-DocxDocumentXml {
    param(
        [string]$DocPath,
        [scriptblock]$Transformer
    )

    $archive = [System.IO.Compression.ZipFile]::Open($DocPath, [System.IO.Compression.ZipArchiveMode]::Update)
    try {
        $entry = $archive.GetEntry('word/document.xml')
        if ($null -eq $entry) {
            throw "No se ha encontrado word/document.xml en $DocPath"
        }

        $original = Read-ZipEntryText -Entry $entry
        $updated = & $Transformer $original

        if ($updated -ne $original) {
            Write-ZipEntryText -Archive $archive -EntryName 'word/document.xml' -Content $updated
            Write-Output "UPDATED: $DocPath"
        } else {
            Write-Output "UNCHANGED: $DocPath"
        }
    } finally {
        $archive.Dispose()
    }
}

function Get-DocxTableCount {
    param([string]$DocPath)

    if (-not (Test-Path -LiteralPath $DocPath)) {
        return 0
    }

    $archive = [System.IO.Compression.ZipFile]::OpenRead($DocPath)
    try {
        $entry = $archive.GetEntry('word/document.xml')
        if ($null -eq $entry) {
            return 0
        }

        $xml = Read-ZipEntryText -Entry $entry
        return ([regex]::Matches($xml, '<w:tbl\b')).Count
    } finally {
        $archive.Dispose()
    }
}

function Ensure-AnnexBaseDocument {
    param([pscustomobject]$Annex)

    $donorProperty = $Annex.PSObject.Properties['DonorDocPath']
    if ($null -eq $donorProperty) {
        return
    }

    $docPath = Join-Path (Get-Location) $Annex.RelativePath
    $donorRelativePath = [string]$donorProperty.Value
    if ([string]::IsNullOrWhiteSpace($donorRelativePath)) {
        return
    }

    $donorPath = Join-Path (Get-Location) $donorRelativePath
    if (-not (Test-Path -LiteralPath $donorPath)) {
        return
    }

    $currentTables = Get-DocxTableCount -DocPath $docPath
    $donorTables = Get-DocxTableCount -DocPath $donorPath
    if ((-not (Test-Path -LiteralPath $docPath)) -or ($currentTables -eq 0 -and $donorTables -gt 0)) {
        Copy-Item -LiteralPath $donorPath -Destination $docPath -Force
        Write-Output "BASE-DONOR: $docPath"
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

function New-WordNamespaceManager {
    param([xml]$Document)

    $ns = New-Object System.Xml.XmlNamespaceManager($Document.NameTable)
    $ns.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
    return $ns
}

function Get-ParagraphText {
    param([System.Xml.XmlElement]$Paragraph)

    $texts = $Paragraph.GetElementsByTagName('w:t')
    if ($null -eq $texts -or $texts.Count -eq 0) {
        return ''
    }

    $chunks = foreach ($node in $texts) { $node.InnerText }
    return ($chunks -join '')
}

function Set-ParagraphText {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [string]$Text
    )

    $wordNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    $document = $Paragraph.OwnerDocument
    $runs = $Paragraph.GetElementsByTagName('w:r')
    $firstRun = if ($runs.Count -gt 0) { $runs.Item(0) } else { $null }
    $runProps = $null
    if ($null -ne $firstRun) {
        $runPropsNodes = $firstRun.GetElementsByTagName('w:rPr')
        $firstRunProps = if ($runPropsNodes.Count -gt 0) { $runPropsNodes.Item(0) } else { $null }
        if ($null -ne $firstRunProps) {
            $runProps = $firstRunProps.CloneNode($true)
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

function Replace-ParagraphText {
    param(
        [xml]$Document,
        [hashtable]$ReplacementMap
    )

    foreach ($paragraph in $Document.GetElementsByTagName('w:p')) {
        $original = Get-ParagraphText -Paragraph $paragraph
        if ([string]::IsNullOrWhiteSpace($original)) {
            continue
        }

        $key = Get-ComparableText -Text $original
        if ($ReplacementMap.ContainsKey($key)) {
            Set-ParagraphText -Paragraph $paragraph -Text $ReplacementMap[$key]
        }
    }
}

function Apply-ParagraphRules {
    param(
        [xml]$Document,
        [scriptblock]$Resolver
    )

    foreach ($paragraph in $Document.GetElementsByTagName('w:p')) {
        $original = Get-ParagraphText -Paragraph $paragraph
        if ([string]::IsNullOrWhiteSpace($original)) {
            continue
        }

        $comparable = Get-ComparableText -Text $original
        $replacement = & $Resolver $comparable
        if (-not [string]::IsNullOrWhiteSpace($replacement)) {
            Set-ParagraphText -Paragraph $paragraph -Text $replacement
        }
    }
}

function Normalize-ProjectCoverParagraphs {
    param(
        [xml]$Document,
        [string]$ProjectCoverText
    )

    foreach ($paragraph in $Document.GetElementsByTagName('w:p')) {
        $original = Get-ParagraphText -Paragraph $paragraph
        if ([string]::IsNullOrWhiteSpace($original)) {
            continue
        }

        $comparable = Get-ComparableText -Text $original
        if ($comparable.Contains('MEJORA DE LA CARRETERA DE GUADALMAR')) {
            Set-ParagraphText -Paragraph $paragraph -Text $ProjectCoverText
        }
    }
}

function Update-AnnexDocument {
    param([pscustomobject]$Annex)

    $docPath = Join-Path (Get-Location) $Annex.RelativePath
    if (-not (Test-Path -LiteralPath $docPath)) {
        Write-Output "SKIPPED-MISSING: $docPath"
        return
    }

    $annexLabel = 'ANEJO {0}. {1}' -f $Annex.Number, $Annex.Title
    $antecedentsText = $commonAntecedents
    if (-not [string]::IsNullOrWhiteSpace($Annex.AdditionalAntecedents)) {
        $antecedentsText = '{0} {1}' -f $antecedentsText, $Annex.AdditionalAntecedents
    }

    Update-DocxDocumentXml -DocPath $docPath -Transformer {
        param($xml)

        [xml]$document = $xml
        $map = @{
            (Get-ComparableText 'PROYECTO ORDINARIO DE URBANIZACION') = $projectHeading
            (Get-ComparableText 'MEJORA DE LA CARRETERA DE GUADALMAR, MALAGA') = $projectCover
            (Get-ComparableText 'AMPLIACION PLAZA MAYOR, MALAGA') = $projectCover
            (Get-ComparableText 'ANEJO N.º XX.– [TITULO DEL ANEJO]') = $annexLabel
            (Get-ComparableText '[El presente anejo tiene por objeto ... Se enmarca dentro del Proyecto Ordinario de Urbanizacion de Mejora de la Carretera de Guadalmar, Malaga.]') = $Annex.ObjectText
            (Get-ComparableText '[Describir la documentacion de partida: cartografia, estudios previos, normativa de aplicacion, datos de campo, ensayos u otros documentos de referencia.]') = $antecedentsText
            (Get-ComparableText '[Referencia normativa 1. Descripcion breve.]') = $commonNormativa[0]
            (Get-ComparableText '[Referencia normativa 2. Descripcion breve.]') = $commonNormativa[1]
            (Get-ComparableText '[Referencia normativa 3. Descripcion breve.]') = $commonNormativa[2]
        }
        Replace-ParagraphText -Document $document -ReplacementMap $map
        Apply-ParagraphRules -Document $document -Resolver {
            param($comparable)

            if ($comparable -eq (Get-ComparableText 'PROYECTO ORDINARIO DE URBANIZACION')) {
                return $projectHeading
            }
            if ($comparable.Contains('MEJORA DE LA CARRETERA DE GUADALMAR')) {
                return $projectCover
            }
            if ($comparable.StartsWith('ANEJO N') -or $comparable.StartsWith('ANEJO ')) {
                return $annexLabel
            }
            if ($comparable.StartsWith('[EL PRESENTE ANEJO TIENE POR OBJETO') -or $comparable.StartsWith('EL PRESENTE ANEJO TIENE POR OBJETO')) {
                return $Annex.ObjectText
            }
            if ($comparable.StartsWith('[DESCRIBIR LA DOCUMENTACION DE PARTIDA')) {
                return $antecedentsText
            }
            if ($comparable.Contains('GUADALMAR')) {
                if ($comparable.Contains('TRAZABILIDAD') -or $comparable.Contains('ALINEACIONES') -or $comparable.Contains('FAMILIA DOCUMENTAL')) {
                    return 'La trazabilidad y los soportes auxiliares se adaptaran integramente a las denominaciones, alineaciones y resultados propios de Plaza Mayor.'
                }
                return 'Se parte unicamente de criterios internos de estructura documental y de soportes auxiliares pendientes de validacion especifica para Plaza Mayor.'
            }
            return $null
        }
        Normalize-ProjectCoverParagraphs -Document $document -ProjectCoverText $projectCover
        $updated = $document.OuterXml
        $updated = $updated.Replace('PROYECTO ORDINARIO DE URBANIZACIÓN', $projectHeading)
        $updated = $updated.Replace('PROYECTO ORDINARIO DE URBANIZACION', $projectHeading)
        $updated = $updated.Replace('MEJORA DE LA CARRETERA DE GUADALMAR, MÁLAGA', $projectCover)
        $updated = $updated.Replace('MEJORA DE LA CARRETERA DE GUADALMAR, MALAGA', $projectCover)
        $updated = $updated.Replace('ANEJO N.º XX.– [TÍTULO DEL ANEJO]', $annexLabel)
        $updated = $updated.Replace('ANEJO N.º XX.– [TITULO DEL ANEJO]', $annexLabel)
        return $updated
    }
}

function Ensure-MemoryDocument {
    $memoryDir = Join-Path (Get-Location) 'DOCS - MEMORIA'
    $memoryPath = Join-Path $memoryDir 'Memoria descriptiva - Proyecto de Urbanizacion - Ampliacion Plaza Mayor.docx'
    $templatePath = Join-Path (Get-Location) 'DOCS - ANEJOS\Plantillas\PLANTILLA_MAESTRA_MEMORIA.docx'

    if (-not (Test-Path -LiteralPath $memoryDir)) {
        New-Item -ItemType Directory -Path $memoryDir | Out-Null
    }

    if (-not (Test-Path -LiteralPath $memoryPath)) {
        Copy-Item -LiteralPath $templatePath -Destination $memoryPath
        Write-Output "CREATED: $memoryPath"
    }

    $memoryObject = 'La presente memoria tiene por objeto iniciar la redaccion del Proyecto de Urbanizacion - Ampliacion Plaza Mayor, ordenando la informacion actualmente recopilada y fijando una base documental coherente para el desarrollo posterior del expediente. En esta fase se incorporan unicamente los antecedentes confirmados, la identificacion del proyecto y el marco general de partida, quedando pendientes los desarrollos tecnicos especificos que requieren contraste adicional.'
    $memoryAntecedents = 'La informacion de partida disponible procede del dossier base del expediente Plaza Mayor, de antecedentes urbanisticos y administrativos ya recopilados y de documentacion sectorial relativa a accesos, movilidad, evaluacion ambiental y ordenacion del ambito. Entre los hitos ya identificados figuran la modificacion del PGOU vinculada al ambito SUNC.BM-4, la documentacion sobre accesos a la MA-20, la vigencia del informe ambiental estrategico emitido en 2022 y diversos informes y estudios complementarios incorporados al expediente.'
    $memorySection3 = 'La presente memoria se formula a partir de la documentacion actualmente disponible del expediente Plaza Mayor y se encuentra en fase inicial de consolidacion tecnica. En consecuencia, se deja estructurada la redaccion base y se incorporan unicamente aquellos extremos que ya cuentan con soporte documental identificable.'
    $memoryScope = 'El expediente se vincula al ambito urbanistico de ampliacion de Plaza Mayor, referido en la documentacion previa al SUNC.BM-4(a) y, en determinados antecedentes, al SUNC.BM-4(A+B). En la informacion ya recopilada constan referencias a la ampliacion del ambito, a la incorporacion de nuevas fincas, a modificaciones de edificabilidad y a la necesidad de coordinar el desarrollo con los accesos y condicionantes viarios del entorno.'
    $memorySources = 'Como documentacion base se dispone del dossier interno del proyecto, de antecedentes urbanisticos y administrativos previos, de informes y escritos sectoriales, de estudios de movilidad y de referencias tecnicas y documentales ya inventariadas en el expediente. Esta informacion constituye la base para la redaccion posterior de la memoria definitiva, de los anejos y de la trazabilidad transversal del proyecto.'
    $memoryStatus = 'En la fecha de esta version se encuentra completado el arranque documental del expediente, con estructura de anejos creada y normalizada, pero quedan pendientes el volcado tecnico detallado, la incorporacion de planos y exportaciones especificas del ambito y la comprobacion cruzada final con mediciones, presupuesto y documentos sectoriales.'

    Update-DocxDocumentXml -DocPath $memoryPath -Transformer {
        param($xml)

        [xml]$document = $xml
        $map = @{
            (Get-ComparableText 'PROYECTO ORDINARIO DE URBANIZACION') = $projectHeading
            (Get-ComparableText 'MEJORA DE LA CARRETERA DE GUADALMAR, MALAGA') = $projectCover
            (Get-ComparableText 'ANEJO N.º XX.– [TITULO DEL ANEJO]') = 'MEMORIA DESCRIPTIVA'
            (Get-ComparableText '[El presente anejo tiene por objeto ... Se enmarca dentro del Proyecto Ordinario de Urbanizacion de Mejora de la Carretera de Guadalmar, Malaga.]') = $memoryObject
            (Get-ComparableText '[Describir la documentacion de partida: cartografia, estudios previos, normativa de aplicacion, datos de campo, ensayos u otros documentos de referencia.]') = $memoryAntecedents
            (Get-ComparableText '[Referencia normativa 1. Descripcion breve.]') = $commonNormativa[0]
            (Get-ComparableText '[Referencia normativa 2. Descripcion breve.]') = $commonNormativa[1]
            (Get-ComparableText '[Referencia normativa 3. Descripcion breve.]') = $commonNormativa[2]
            (Get-ComparableText '[Describir los criterios de diseno, hipotesis, condicionantes y la solucion adoptada.]') = $memorySection3
            (Get-ComparableText '3.1. [Primer subapartado]') = '3.1. Ambito y antecedentes urbanisticos'
            (Get-ComparableText '3.2. [Segundo subapartado]') = '3.2. Documentacion de partida'
            (Get-ComparableText '3.2.1. [Sub-subapartado]') = '3.2.1. Estado actual del expediente'
            (Get-ComparableText '[Contenido del subapartado 3.1. Referenciar planos cuando proceda: vease Plano n.º XX.]') = $memoryScope
            (Get-ComparableText '[Contenido del subapartado 3.2.]') = $memorySources
            (Get-ComparableText '[Contenido del sub-subapartado.]') = $memoryStatus
        }
        Replace-ParagraphText -Document $document -ReplacementMap $map
        Apply-ParagraphRules -Document $document -Resolver {
            param($comparable)

            if ($comparable -eq (Get-ComparableText 'PROYECTO ORDINARIO DE URBANIZACION')) {
                return $projectHeading
            }
            if ($comparable.Contains('MEJORA DE LA CARRETERA DE GUADALMAR')) {
                return $projectCover
            }
            if ($comparable.StartsWith('ANEJO N') -or $comparable.StartsWith('ANEJO ')) {
                return 'MEMORIA DESCRIPTIVA'
            }
            if ($comparable.StartsWith('[EL PRESENTE ANEJO TIENE POR OBJETO')) {
                return $memoryObject
            }
            if ($comparable.StartsWith('[DESCRIBIR LA DOCUMENTACION DE PARTIDA')) {
                return $memoryAntecedents
            }
            if ($comparable -eq (Get-ComparableText '3.2.1. [Sub-subapartado]')) {
                return '3.2.1. Estado actual del expediente'
            }
            return $null
        }
        Normalize-ProjectCoverParagraphs -Document $document -ProjectCoverText $projectCover
        $updated = $document.OuterXml
        $updated = $updated.Replace('PROYECTO ORDINARIO DE URBANIZACIÓN', $projectHeading)
        $updated = $updated.Replace('PROYECTO ORDINARIO DE URBANIZACION', $projectHeading)
        $updated = $updated.Replace('MEJORA DE LA CARRETERA DE GUADALMAR, MÁLAGA', $projectCover)
        $updated = $updated.Replace('MEJORA DE LA CARRETERA DE GUADALMAR, MALAGA', $projectCover)
        $updated = $updated.Replace('ANEJO N.º XX.– [TÍTULO DEL ANEJO]', 'MEMORIA DESCRIPTIVA')
        $updated = $updated.Replace('ANEJO N.º XX.– [TITULO DEL ANEJO]', 'MEMORIA DESCRIPTIVA')
        return $updated
    }
}

foreach ($annex in $annexes) {
    Ensure-AnnexBaseDocument -Annex $annex
    Update-AnnexDocument -Annex $annex
}

if ($CreateMemory) {
    Ensure-MemoryDocument
}
