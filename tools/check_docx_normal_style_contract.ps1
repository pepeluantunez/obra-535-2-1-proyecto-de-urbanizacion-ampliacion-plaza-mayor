param(
    [Parameter(Mandatory = $true)]
    [string[]]$Paths,
    [double]$ExpectedFontPt = 9.5,
    [string]$ExpectedFont = 'Montserrat',
    [switch]$FailOnIssue
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$docExtensions = @('.docx', '.docm')
$WordNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
$expectedHalf = [string]([int][Math]::Round($ExpectedFontPt * 2))

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
                Where-Object { $_.Extension.ToLowerInvariant() -in $docExtensions -and $_.Name -notmatch '^~\$' } |
                Select-Object -ExpandProperty FullName
        } elseif ($item.Extension.ToLowerInvariant() -in $docExtensions) {
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

$files = @(Resolve-DocFiles -InputPaths $Paths)
$issues = @()

foreach ($file in $files) {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($file)
    try {
        $entry = $zip.GetEntry('word/styles.xml')
        if ($null -eq $entry) {
            $issues += [pscustomobject]@{ archivo=$file; tipo='styles'; detalle='sin styles.xml' }
            continue
        }

        [xml]$styles = Read-ZipEntryText -Entry $entry
        $ns = New-Object System.Xml.XmlNamespaceManager($styles.NameTable)
        $ns.AddNamespace('w', $WordNs)

        $normal = $styles.SelectSingleNode("/w:styles/w:style[@w:type='paragraph' and @w:styleId='Normal']", $ns)
        if ($null -eq $normal) {
            $issues += [pscustomobject]@{ archivo=$file; tipo='normal'; detalle='falta estilo Normal' }
            continue
        }

        $nFont = $normal.SelectSingleNode('w:rPr/w:rFonts', $ns)
        $nSz = $normal.SelectSingleNode('w:rPr/w:sz', $ns)

        if ($null -eq $nSz -or $nSz.GetAttribute('val',$WordNs) -ne $expectedHalf) {
            $issues += [pscustomobject]@{ archivo=$file; tipo='normal-size'; detalle="Normal != ${ExpectedFontPt}pt" }
        }
        if ($null -ne $nFont) {
            $ascii = $nFont.GetAttribute('ascii',$WordNs)
            if (-not [string]::IsNullOrWhiteSpace($ascii) -and $ascii -ne $ExpectedFont) {
                $issues += [pscustomobject]@{ archivo=$file; tipo='normal-font'; detalle="Normal font != $ExpectedFont" }
            }
        }

        $dSz = $styles.SelectSingleNode('/w:styles/w:docDefaults/w:rPrDefault/w:rPr/w:sz', $ns)
        if ($null -eq $dSz -or $dSz.GetAttribute('val',$WordNs) -ne $expectedHalf) {
            $issues += [pscustomobject]@{ archivo=$file; tipo='default-size'; detalle="docDefaults != ${ExpectedFontPt}pt" }
        }
    } finally {
        $zip.Dispose()
    }
}

if ($issues.Count -eq 0) {
    Write-Output "OK CONTRACT: Normal/docDefaults en ${ExpectedFontPt}pt ($ExpectedFont)."
} else {
    $issues | Sort-Object archivo,tipo | Format-Table -AutoSize
    if ($FailOnIssue) { throw 'Contrato tipografico DOCX incumplido.' }
}
