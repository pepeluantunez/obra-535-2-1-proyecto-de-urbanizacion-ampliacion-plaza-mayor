param(
    [Parameter(Mandatory = $true)]
    [string[]]$Paths,
    [double]$FontPt = 9.5,
    [string]$FontName = 'Montserrat',
    [switch]$IncludeTemplates
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$docExtensions = @('.docx', '.docm')
$WordNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'

function Resolve-FullPathSafe {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
}

function Resolve-DocFiles {
    param([string[]]$InputPaths)
    $resolved = @()
    foreach ($inputPath in $InputPaths) {
        $absolute = Resolve-FullPathSafe -Path $inputPath
        if (-not (Test-Path -LiteralPath $absolute)) { throw "No existe la ruta: $inputPath" }
        $item = Get-Item -LiteralPath $absolute
        if ($item.PSIsContainer) {
            $resolved += Get-ChildItem -LiteralPath $item.FullName -Recurse -File |
                Where-Object {
                    $_.Extension.ToLowerInvariant() -in $docExtensions -and
                    $_.Name -notmatch '^~\$' -and
                    $_.Name -notmatch '_ORIG|_bak_' -and
                    ($IncludeTemplates -or $_.FullName -notmatch '\\Plantillas\\') -and
                    ($IncludeTemplates -or $_.FullName -notmatch '\\10_donor_docx\\')
                } |
                Select-Object -ExpandProperty FullName
        } elseif ($item.Extension.ToLowerInvariant() -in $docExtensions) {
            if (-not $IncludeTemplates -and $item.FullName -match '\\Plantillas\\') { continue }
            if (-not $IncludeTemplates -and $item.FullName -match '\\10_donor_docx\\') { continue }
            $resolved += $item.FullName
        }
    }
    return @($resolved | Sort-Object -Unique)
}

function Read-ZipEntryText {
    param([System.IO.Compression.ZipArchiveEntry]$Entry)
    $stream = $Entry.Open()
    try {
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.UTF8Encoding]::new($false), $true)
        try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
    } finally { $stream.Dispose() }
}

function Write-ZipEntryText {
    param(
        [System.IO.Compression.ZipArchive]$Archive,
        [string]$EntryName,
        [string]$Content
    )
    $existing = $Archive.GetEntry($EntryName)
    if ($null -ne $existing) { $existing.Delete() }
    $entry = $Archive.CreateEntry($EntryName, [System.IO.Compression.CompressionLevel]::Optimal)
    $stream = $entry.Open()
    try {
        $writer = New-Object System.IO.StreamWriter($stream, [System.Text.UTF8Encoding]::new($false))
        try { $writer.Write($Content) } finally { $writer.Dispose() }
    } finally { $stream.Dispose() }
}

function Ensure-Child {
    param(
        [System.Xml.XmlElement]$Parent,
        [string]$LocalName,
        [xml]$XmlDoc
    )
    foreach ($child in $Parent.ChildNodes) {
        if ($child.LocalName -eq $LocalName) { return [System.Xml.XmlElement]$child }
    }
    $newNode = $XmlDoc.CreateElement('w', $LocalName, $WordNs)
    [void]$Parent.AppendChild($newNode)
    return $newNode
}

function Ensure-RPrDefaults {
    param(
        [xml]$Styles,
        [System.Xml.XmlNamespaceManager]$Ns
    )
    $stylesNode = $Styles.SelectSingleNode('/w:styles', $Ns)
    if ($null -eq $stylesNode) { return $null }

    $docDefaults = $Styles.SelectSingleNode('/w:styles/w:docDefaults', $Ns)
    if ($null -eq $docDefaults) {
        $docDefaults = $Styles.CreateElement('w', 'docDefaults', $WordNs)
        [void]$stylesNode.AppendChild($docDefaults)
    }

    $rPrDefault = $Styles.SelectSingleNode('/w:styles/w:docDefaults/w:rPrDefault', $Ns)
    if ($null -eq $rPrDefault) {
        $rPrDefault = $Styles.CreateElement('w', 'rPrDefault', $WordNs)
        [void]$docDefaults.AppendChild($rPrDefault)
    }

    $rPr = $Styles.SelectSingleNode('/w:styles/w:docDefaults/w:rPrDefault/w:rPr', $Ns)
    if ($null -eq $rPr) {
        $rPr = $Styles.CreateElement('w', 'rPr', $WordNs)
        [void]$rPrDefault.AppendChild($rPr)
    }
    return [System.Xml.XmlElement]$rPr
}

function Set-RPrFontAndSize {
    param(
        [System.Xml.XmlElement]$RPr,
        [xml]$XmlDoc,
        [string]$Font,
        [string]$HalfPt
    )
    $changed = $false
    $rFonts = Ensure-Child -Parent $RPr -LocalName 'rFonts' -XmlDoc $XmlDoc
    foreach ($attr in @('ascii','hAnsi','eastAsia','cs')) {
        $cur = $rFonts.GetAttribute($attr, $WordNs)
        if ($cur -ne $Font) {
            [void]$rFonts.SetAttribute($attr, $WordNs, $Font)
            $changed = $true
        }
    }

    $sz = Ensure-Child -Parent $RPr -LocalName 'sz' -XmlDoc $XmlDoc
    if ($sz.GetAttribute('val', $WordNs) -ne $HalfPt) {
        [void]$sz.SetAttribute('val', $WordNs, $HalfPt)
        $changed = $true
    }

    $szCs = Ensure-Child -Parent $RPr -LocalName 'szCs' -XmlDoc $XmlDoc
    if ($szCs.GetAttribute('val', $WordNs) -ne $HalfPt) {
        [void]$szCs.SetAttribute('val', $WordNs, $HalfPt)
        $changed = $true
    }

    return $changed
}

$halfPoints = [int][Math]::Round($FontPt * 2)
$halfPointsStr = [string]$halfPoints
$files = @(Resolve-DocFiles -InputPaths $Paths)

foreach ($file in $files) {
    $zip = $null
    try {
        $zip = [System.IO.Compression.ZipFile]::Open($file, [System.IO.Compression.ZipArchiveMode]::Update)
        $stylesEntry = $zip.GetEntry('word/styles.xml')
        if ($null -eq $stylesEntry) {
            Write-Output "SKIP NORMAL95: $file (sin styles.xml)"
            continue
        }

        [xml]$styles = Read-ZipEntryText -Entry $stylesEntry
        $ns = New-Object System.Xml.XmlNamespaceManager($styles.NameTable)
        $ns.AddNamespace('w', $WordNs)

        $changed = $false

        $normalStyle = $styles.SelectSingleNode("/w:styles/w:style[@w:type='paragraph' and @w:styleId='Normal']", $ns)
        if ($null -ne $normalStyle) {
            $rPr = $normalStyle.SelectSingleNode('w:rPr', $ns)
            if ($null -eq $rPr) {
                $rPr = $styles.CreateElement('w', 'rPr', $WordNs)
                [void]$normalStyle.AppendChild($rPr)
                $changed = $true
            }
            if (Set-RPrFontAndSize -RPr ([System.Xml.XmlElement]$rPr) -XmlDoc $styles -Font $FontName -HalfPt $halfPointsStr) { $changed = $true }
        }

        $defaultsRPr = Ensure-RPrDefaults -Styles $styles -Ns $ns
        if ($null -ne $defaultsRPr) {
            if (Set-RPrFontAndSize -RPr $defaultsRPr -XmlDoc $styles -Font $FontName -HalfPt $halfPointsStr) { $changed = $true }
        }

        if ($changed) {
            Write-ZipEntryText -Archive $zip -EntryName 'word/styles.xml' -Content $styles.OuterXml
            Write-Output "OK NORMAL95: $file"
        } else {
            Write-Output "UNCHANGED NORMAL95: $file"
        }
    } catch {
        Write-Output ("INCIDENCIA NORMAL95: {0} :: {1}" -f $file, $_.Exception.Message)
    } finally {
        if ($null -ne $zip) { $zip.Dispose() }
    }
}
