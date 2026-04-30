param(
    [Parameter(Mandatory = $true)]
    [string[]]$Paths,
    [string]$TemplatePath = ".\DOCS - ANEJOS\Plantillas\PLANTILLA_MAESTRA_ANEJOS.docx",
    [int]$CoverParagraphs = 8,
    [switch]$FailOnIssue
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$WordNs = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
$DocExt = @(".docx", ".docm")

function Resolve-FullPathSafe {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
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
                Where-Object { $_.Extension.ToLowerInvariant() -in $DocExt -and $_.Name -notmatch '^~\$' } |
                Select-Object -ExpandProperty FullName
        } elseif ($item.Extension.ToLowerInvariant() -in $DocExt) {
            $resolved += $item.FullName
        }
    }
    return @($resolved | Sort-Object -Unique)
}

function Read-DocXml {
    param([string]$Path)
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entry = $zip.GetEntry("word/document.xml")
        if ($null -eq $entry) { return $null }
        $stream = $entry.Open()
        try {
            $reader = New-Object System.IO.StreamReader($stream, [System.Text.UTF8Encoding]::new($false), $true)
            try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
        } finally { $stream.Dispose() }
    } finally { $zip.Dispose() }
}

function Get-CoverPPrProfile {
    param(
        [xml]$Doc,
        [int]$Count
    )
    $ns = New-Object System.Xml.XmlNamespaceManager($Doc.NameTable)
    $ns.AddNamespace("w", $WordNs)
    $pars = @($Doc.SelectNodes("//w:body/w:p", $ns))
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($pNode in $pars) {
        if ($out.Count -ge $Count) { break }
        if ($pNode -isnot [System.Xml.XmlElement]) { continue }
        $p = [System.Xml.XmlElement]$pNode
        $txt = @($p.SelectNodes(".//w:t", $ns) | ForEach-Object { $_.InnerText }) -join ""
        if ([string]::IsNullOrWhiteSpace(($txt -replace '\s+', ' ').Trim())) { continue }
        $pPr = $p.SelectSingleNode("./w:pPr", $ns)
        $out.Add($(if ($null -ne $pPr) { $pPr.OuterXml } else { "" })) | Out-Null
    }
    return $out.ToArray()
}

$templateFull = Resolve-FullPathSafe -Path $TemplatePath
[xml]$templateXml = Read-DocXml -Path $templateFull
if ($null -eq $templateXml) { throw "No se pudo leer document.xml de la plantilla: $templateFull" }
$templateProfile = Get-CoverPPrProfile -Doc $templateXml -Count $CoverParagraphs

$files = @(Resolve-DocFiles -InputPaths $Paths)
$issues = New-Object System.Collections.Generic.List[object]

foreach ($file in $files) {
    [xml]$docXml = Read-DocXml -Path $file
    if ($null -eq $docXml) { continue }
    $profile = Get-CoverPPrProfile -Doc $docXml -Count $CoverParagraphs
    $limit = [Math]::Min($templateProfile.Length, $profile.Length)
    for ($i = 0; $i -lt $limit; $i++) {
        if ($templateProfile[$i] -ne $profile[$i]) {
            $issues.Add([pscustomobject]@{
                    archivo = $file
                    parrafo = $i
                    problema = "pPr de portada no coincide con plantilla"
                }) | Out-Null
        }
    }
}

if ($issues.Count -eq 0) {
    Write-Output "OK COVER: contrato de portada conforme."
} else {
    $issues | Sort-Object archivo,parrafo | Format-Table -AutoSize
    if ($FailOnIssue) { throw "Contrato de portada DOCX incumplido." }
}
