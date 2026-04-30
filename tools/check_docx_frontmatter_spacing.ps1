param(
    [Parameter(Mandatory = $true)]
    [string[]]$Paths,
    [string]$ExpectedBefore = "0",
    [string]$ExpectedAfter = "240",
    [string]$ExpectedLine = "288",
    [string]$ExpectedLineRule = "auto",
    [switch]$FailOnIssue
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$WordNs = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
$docExtensions = @(".docx", ".docm")

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
        if (-not (Test-Path -LiteralPath $absolute)) {
            throw "No existe la ruta: $inputPath"
        }

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

function Get-ParagraphText {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns
    )
    $texts = @($Paragraph.SelectNodes(".//w:t", $Ns) | ForEach-Object { $_.InnerText })
    return (($texts -join "") -replace '\s+', ' ').Trim()
}

function Get-PrevNonEmptyIndex {
    param(
        [System.Xml.XmlElement[]]$Paragraphs,
        [System.Xml.XmlNamespaceManager]$Ns,
        [int]$Start
    )
    for ($i = $Start; $i -ge 0; $i--) {
        $txt = Get-ParagraphText -Paragraph $Paragraphs[$i] -Ns $Ns
        if (-not [string]::IsNullOrWhiteSpace($txt)) { return $i }
    }
    return -1
}

function Read-Spacing {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns
    )
    $spacing = $Paragraph.SelectSingleNode("./w:pPr/w:spacing", $Ns)
    return [pscustomobject]@{
        Before = if ($spacing) { $spacing.GetAttribute("before", $WordNs) } else { "" }
        After = if ($spacing) { $spacing.GetAttribute("after", $WordNs) } else { "" }
        Line = if ($spacing) { $spacing.GetAttribute("line", $WordNs) } else { "" }
        LineRule = if ($spacing) { $spacing.GetAttribute("lineRule", $WordNs) } else { "" }
    }
}

$files = @(Resolve-DocFiles -InputPaths $Paths)
$issues = New-Object System.Collections.Generic.List[object]

foreach ($file in $files) {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($file)
    try {
        $entry = $zip.GetEntry("word/document.xml")
        if ($null -eq $entry) { continue }

        [xml]$doc = Read-ZipEntryText -Entry $entry
        $ns = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
        $ns.AddNamespace("w", $WordNs)

        [System.Xml.XmlElement[]]$paragraphs = @($doc.SelectNodes("//w:body/w:p", $ns))
        for ($i = 0; $i -lt $paragraphs.Count; $i++) {
            $txt = Get-ParagraphText -Paragraph $paragraphs[$i] -Ns $ns
            if ([string]::IsNullOrWhiteSpace($txt)) { continue }
            if ($txt -notmatch '^(?i)ÍNDICE$|^(?i)INDICE$') { continue }

            $anejoIdx = Get-PrevNonEmptyIndex -Paragraphs $paragraphs -Ns $ns -Start ($i - 1)
            $projectIdx = if ($anejoIdx -ge 0) { Get-PrevNonEmptyIndex -Paragraphs $paragraphs -Ns $ns -Start ($anejoIdx - 1) } else { -1 }

            foreach ($targetIdx in @($projectIdx, $anejoIdx)) {
                if ($targetIdx -lt 0) { continue }
                $sp = Read-Spacing -Paragraph $paragraphs[$targetIdx] -Ns $ns
                if ($sp.Before -ne $ExpectedBefore -or $sp.After -ne $ExpectedAfter -or $sp.Line -ne $ExpectedLine -or $sp.LineRule -ne $ExpectedLineRule) {
                    $issues.Add([pscustomobject]@{
                            archivo = $file
                            indice = $targetIdx
                            texto = (Get-ParagraphText -Paragraph $paragraphs[$targetIdx] -Ns $ns)
                            before = $sp.Before
                            after = $sp.After
                            line = $sp.Line
                            lineRule = $sp.LineRule
                            esperado = "before=$ExpectedBefore after=$ExpectedAfter line=$ExpectedLine lineRule=$ExpectedLineRule"
                        }) | Out-Null
                }
            }
        }
    } finally {
        $zip.Dispose()
    }
}

if ($issues.Count -eq 0) {
    Write-Output "OK FRONTMATTER: espaciado portada/indice conforme."
} else {
    $issues | Format-Table -AutoSize
    if ($FailOnIssue) {
        throw "Control de espaciado de portada/indice fallido."
    }
}
