Set-StrictMode -Version Latest

function Resolve-Civil3DProjectRoot {
    param([string]$Root)

    $candidate = if ([string]::IsNullOrWhiteSpace($Root)) {
        Split-Path -Parent $PSScriptRoot
    }
    else {
        $Root
    }

    return (Resolve-Path -LiteralPath $candidate).Path
}

function Resolve-Civil3DWorkFolder {
    param(
        [string]$Root,
        [string[]]$FolderNames
    )

    $projectRoot = Resolve-Civil3DProjectRoot -Root $Root
    foreach ($folderName in @($FolderNames)) {
        foreach ($prefix in @('DOCS - ANEJOS', 'DOCS\Documentos de Trabajo')) {
            $candidate = Join-Path $projectRoot (Join-Path $prefix $folderName)
            if (Test-Path -LiteralPath $candidate) {
                return (Resolve-Path -LiteralPath $candidate).Path
            }
        }
    }

    return $null
}

function Resolve-Civil3DSourcePath {
    param(
        [string]$FolderPath,
        [string]$FileName
    )

    $candidate = Join-Path $FolderPath $FileName
    if (Test-Path -LiteralPath $candidate) {
        return (Resolve-Path -LiteralPath $candidate).Path
    }

    return $null
}

function Resolve-Civil3DAnejo4Folder {
    param([string]$Root)

    return Resolve-Civil3DWorkFolder -Root $Root -FolderNames @('4.- Trazado, Replanteo y Mediciones Auxiliares')
}

function Resolve-Civil3DPluvialesFolder {
    param([string]$Root)

    return Resolve-Civil3DWorkFolder -Root $Root -FolderNames @('7.- Red de Saneamiento - Pluviales')
}

function Resolve-Civil3DFecalesFolder {
    param([string]$Root)

    return Resolve-Civil3DWorkFolder -Root $Root -FolderNames @('8.- Red de Saneamiento - Fecales')
}

function Resolve-Civil3DAnejoDocx {
    param(
        [string]$FolderPath,
        [string[]]$PreferredNames,
        [string]$Pattern = '^Anexo\s+\d+.*\.docx$'
    )

    foreach ($name in @($PreferredNames)) {
        $candidate = Join-Path $FolderPath $name
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    $match = Get-ChildItem -LiteralPath $FolderPath -File -Filter *.docx |
        Where-Object { $_.Name -match $Pattern } |
        Sort-Object Name |
        Select-Object -First 1
    if ($match) {
        return $match.FullName
    }

    return $null
}
