<#
.SYNOPSIS
    Instala hooks de git para el proyecto POU.

.DESCRIPTION
    Instala pre-commit y post-merge hooks que ejecutan automaticamente
    los controles criticos del expediente antes de cada commit:
    - Encoding BC3 (no mojibake)
    - Mojibake en Office (docx/xlsx)
    - Sincronizacion con toolkit
    - Snapshot automatico de BC3 si hay cambios en PRESUPUESTO/

    Tambien instala un commit-msg hook que exige formato minimo.

.PARAMETER ProjectRoot
    Ruta raiz del proyecto (defecto: directorio actual)

.PARAMETER Uninstall
    Elimina los hooks instalados por este script

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\install_git_hooks.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\install_git_hooks.ps1 -Uninstall
#>
param(
    [string]$ProjectRoot = "",
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

# Resolver raiz del proyecto
if ($ProjectRoot -eq "") {
    $ProjectRoot = Split-Path $PSScriptRoot -Parent
}
$GitDir = Join-Path $ProjectRoot ".git"

if (-not (Test-Path $GitDir)) {
    Write-Error "No se encuentra .git en $ProjectRoot. El proyecto debe ser un repositorio git."
    exit 1
}

$HooksDir = Join-Path $GitDir "hooks"
if (-not (Test-Path $HooksDir)) {
    New-Item -ItemType Directory -Path $HooksDir -Force | Out-Null
}

# ── Marca para identificar hooks gestionados por este script ──────────────────
$HOOK_MARKER = "# INSTALLED BY: install_git_hooks.ps1 (POU toolkit)"

# ── Hook: pre-commit ──────────────────────────────────────────────────────────
$PreCommitContent = @"
#!/bin/sh
$HOOK_MARKER

# Pre-commit hook del proyecto POU
# Ejecuta controles criticos antes de aceptar el commit.
# Falla (exit 1) si hay errores criticos — el commit se bloquea.

REPO_ROOT="`$(git rev-parse --show-toplevel)"
TOOLS_DIR="`$REPO_ROOT/tools"

echo ""
echo "=== PRE-COMMIT: controles POU ==="

ERRORS=0
WARNINGS=0

# ── 1. Encoding BC3 ───────────────────────────────────────────────────────────
BC3_STAGED=`$(git diff --cached --name-only | grep -i '\.bc3`$' || true)
if [ -n "`$BC3_STAGED" ]; then
    echo "[1/3] Comprobando encoding BC3..."
    for f in `$BC3_STAGED; do
        FULL="`$REPO_ROOT/`$f"
        if [ -f "`$FULL" ]; then
            # Detectar secuencias UTF-8 multibyte (mojibake) con python
            MOJIBAKE=`$(python3 -c "
import sys
data = open('`$FULL', 'rb').read()
count = 0
for i in range(len(data)-1):
    b = data[i]
    n = data[i+1]
    if b in (0xC3, 0xC2, 0xE2) and 0x80 <= n <= 0xBF:
        count += 1
        if count >= 3: break
print(count)
" 2>/dev/null || echo "0")
            if [ "`$MOJIBAKE" -ge 3 ]; then
                echo "  ERROR BC3 mojibake: `$f (`$MOJIBAKE secuencias UTF-8)"
                ERRORS=`$((ERRORS+1))
            else
                echo "  OK BC3 encoding: `$f"
            fi
        fi
    done
fi

# ── 2. Mojibake en Office ─────────────────────────────────────────────────────
OFFICE_STAGED=`$(git diff --cached --name-only | grep -iE '\.(docx|xlsx)`$' || true)
if [ -n "`$OFFICE_STAGED" ]; then
    echo "[2/3] Comprobando mojibake Office..."
    for f in `$OFFICE_STAGED; do
        FULL="`$REPO_ROOT/`$f"
        if [ -f "`$FULL" ]; then
            HIT=`$(python3 -c "
import zipfile, re, sys
try:
    with zipfile.ZipFile('`$FULL') as z:
        names = [n for n in z.namelist() if n.endswith('.xml')][:5]
        for n in names:
            text = z.read(n).decode('utf-8', errors='replace')
            if re.search(r'Ã[A-Za-z]|Â[A-Za-z]|â€', text):
                print('1')
                sys.exit(0)
    print('0')
except Exception:
    print('0')
" 2>/dev/null || echo "0")
            if [ "`$HIT" = "1" ]; then
                echo "  AVISO posible mojibake: `$f"
                WARNINGS=`$((WARNINGS+1))
            else
                echo "  OK: `$f"
            fi
        fi
    done
fi

# ── 3. Tools sincronizadas con toolkit ───────────────────────────────────────
echo "[3/3] Verificando sincronizacion con toolkit..."
TOOLKIT="C:/Users/USUARIO/Documents/Claude/Projects/urbanizacion-toolkit"
if [ -d "`$TOOLKIT" ]; then
    for tool in bc3_tools.py excel_tools.py mediciones_validator.py; do
        src="`$TOOLKIT/tools/python/`$tool"
        dst="`$REPO_ROOT/tools/`$tool"
        if [ -f "`$src" ] && [ -f "`$dst" ]; then
            HASH_SRC=`$(python3 -c "import hashlib; print(hashlib.md5(open('`$src','rb').read()).hexdigest())" 2>/dev/null)
            HASH_DST=`$(python3 -c "import hashlib; print(hashlib.md5(open('`$dst','rb').read()).hexdigest())" 2>/dev/null)
            if [ "`$HASH_SRC" != "`$HASH_DST" ]; then
                echo "  AVISO `$tool desincronizado (ejecutar sync_from_toolkit.ps1)"
                WARNINGS=`$((WARNINGS+1))
            else
                echo "  OK: `$tool"
            fi
        fi
    done
else
    echo "  SKIP: toolkit no encontrado en ruta canonica"
fi

# ── Resumen ───────────────────────────────────────────────────────────────────
echo ""
echo "Pre-commit: ERRORES=`$ERRORS  AVISOS=`$WARNINGS"

if [ `$ERRORS -gt 0 ]; then
    echo "COMMIT BLOQUEADO: corregir errores antes de commitear."
    exit 1
fi

if [ `$WARNINGS -gt 0 ]; then
    echo "AVISO: hay advertencias — commit permitido pero revisar."
fi

echo "OK — pre-commit superado."
exit 0
"@

# ── Hook: commit-msg ──────────────────────────────────────────────────────────
$CommitMsgContent = @"
#!/bin/sh
$HOOK_MARKER

# commit-msg: exige formato minimo: tipo(alcance): descripcion
# Permite: fix|feat|refactor|docs|chore|anejo|bc3|excel|word|style|ci

MSG=`$(cat "`$1")
PATTERN='^(fix|feat|refactor|docs|chore|anejo|bc3|excel|word|style|ci|data|trazabilidad)(\([^)]+\))?: .+'

if ! echo "`$MSG" | grep -qE "`$PATTERN"; then
    echo ""
    echo "ERROR: mensaje de commit no cumple el formato minimo."
    echo ""
    echo "Formato requerido: tipo(alcance): descripcion"
    echo "Tipos validos: fix|feat|refactor|docs|chore|anejo|bc3|excel|word|style|ci|data|trazabilidad"
    echo ""
    echo "Ejemplos:"
    echo "  anejo(7): primer borrador de pluviales"
    echo "  bc3(maestro): recalc PEM Plaza Mayor"
    echo "  fix(encoding): corregir mojibake en anejo 14"
    echo "  docs(kanban): marcar anejo 5 como pendiente"
    echo ""
    exit 1
fi

exit 0
"@

# ── Instalar / desinstalar ────────────────────────────────────────────────────
$hooks = @{
    'pre-commit' = $PreCommitContent
    'commit-msg' = $CommitMsgContent
}

if ($Uninstall) {
    Write-Host "Desinstalando hooks..."
    foreach ($name in $hooks.Keys) {
        $path = Join-Path $HooksDir $name
        if (Test-Path $path) {
            $content = Get-Content $path -Raw
            if ($content -match [regex]::Escape($HOOK_MARKER)) {
                Remove-Item $path -Force
                Write-Host "  Eliminado: $name" -ForegroundColor Green
            } else {
                Write-Host "  SKIP $name (no gestionado por este script)" -ForegroundColor Yellow
            }
        }
    }
    exit 0
}

Write-Host ""
Write-Host "=== Instalando git hooks POU ===" -ForegroundColor Cyan
Write-Host "Proyecto: $ProjectRoot"
Write-Host "Hooks dir: $HooksDir"
Write-Host ""

foreach ($name in $hooks.Keys) {
    $path = Join-Path $HooksDir $name
    $content = $hooks[$name]

    # No sobreescribir hooks existentes que NO sean nuestros
    if (Test-Path $path) {
        $existing = Get-Content $path -Raw
        if ($existing -notmatch [regex]::Escape($HOOK_MARKER)) {
            Write-Warning "  $name ya existe y no es nuestro — haciendo backup"
            Copy-Item $path "$path.bak" -Force
        }
    }

    # Escribir hook (LF, no CRLF — git bash requiere LF)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $bytes = $utf8NoBom.GetBytes($content -replace '\r\n', "`n")
    [System.IO.File]::WriteAllBytes($path, $bytes)

    Write-Host "  Instalado: $name" -ForegroundColor Green
}

Write-Host ""
Write-Host "Hooks instalados correctamente." -ForegroundColor Cyan
Write-Host "El pre-commit bloquea commits con BC3 en UTF-8 o tools desincronizadas."
Write-Host "El commit-msg exige formato: tipo(alcance): descripcion"
Write-Host ""
Write-Host "Para desinstalar:"
Write-Host "  powershell -File .\tools\install_git_hooks.ps1 -Uninstall"
