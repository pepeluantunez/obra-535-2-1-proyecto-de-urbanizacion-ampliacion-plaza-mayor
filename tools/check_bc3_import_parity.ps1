param([Parameter(ValueFromRemainingArguments=$true)][object[]]$RemainingArgs)
$target = 'C:\Users\USUARIO\Documents\Claude\Projects\urbanizacion-toolkit\tools\\bc3\\check_bc3_import_parity.ps1'
if (!(Test-Path -LiteralPath $target)) { throw "Canonical script not found: $target" }
& $target @RemainingArgs
exit $LASTEXITCODE
