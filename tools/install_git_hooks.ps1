param([Parameter(ValueFromRemainingArguments=$true)][object[]]$RemainingArgs)
$target = 'C:\Users\USUARIO\Documents\Claude\Projects\urbanizacion-toolkit\tools\\automation\\install_git_hooks.ps1'
if (!(Test-Path -LiteralPath $target)) { throw "Canonical script not found: $target" }
& $target @RemainingArgs
exit $LASTEXITCODE
