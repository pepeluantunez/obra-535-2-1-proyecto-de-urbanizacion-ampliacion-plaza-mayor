param([Parameter(ValueFromRemainingArguments=$true)][object[]]$RemainingArgs)
$target = 'C:\Users\USUARIO\Documents\Claude\Projects\urbanizacion-toolkit\tools\\civil3d\\build_anejo4_html_word_traceability.ps1'
if (!(Test-Path -LiteralPath $target)) { throw "Canonical script not found: $target" }
& $target @RemainingArgs
exit $LASTEXITCODE
