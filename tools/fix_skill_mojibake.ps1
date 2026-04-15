param(
    [string]$SkillsRoot = '.\.claude\skills',
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Repair-Mojibake {
    param([string]$Text)

    if ($Text -notmatch '\u00C3|\u00C2|\u00E2') {
        return $Text
    }

    $current = $Text
    for ($i = 0; $i -lt 3; $i++) {
        $next = [System.Text.Encoding]::UTF8.GetString(
            [System.Text.Encoding]::GetEncoding(1252).GetBytes($current)
        )
        if ($next -eq $current) { break }
        $current = $next
        if ($current -notmatch '\u00C3|\u00C2|\u00E2') { break }
    }
    return $current
}

$root = if ([System.IO.Path]::IsPathRooted($SkillsRoot)) {
    $SkillsRoot
} else {
    Join-Path (Get-Location) $SkillsRoot
}

if (-not (Test-Path -LiteralPath $root)) {
    throw "Skills path does not exist: $SkillsRoot"
}

$files = Get-ChildItem -LiteralPath $root -Recurse -File -Filter 'SKILL.md'
if (-not $files -or $files.Count -eq 0) {
    Write-Output 'No SKILL.md files found in target path.'
    exit 0
}

$changed = 0
foreach ($f in $files) {
    $raw = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    $fixed = Repair-Mojibake -Text $raw

    if ($fixed -ne $raw) {
        $changed++
        if ($WhatIf) {
            Write-Output ("[WHATIF] Fixable: {0}" -f $f.FullName)
            continue
        }
        [System.IO.File]::WriteAllText($f.FullName, $fixed, [System.Text.UTF8Encoding]::new($false))
        Write-Output ("[FIXED] {0}" -f $f.FullName)
    } else {
        Write-Output ("[OK] {0}" -f $f.FullName)
    }
}

Write-Output ("SKILL.md scanned: {0}" -f $files.Count)
Write-Output ("SKILL.md fixed: {0}" -f $changed)
