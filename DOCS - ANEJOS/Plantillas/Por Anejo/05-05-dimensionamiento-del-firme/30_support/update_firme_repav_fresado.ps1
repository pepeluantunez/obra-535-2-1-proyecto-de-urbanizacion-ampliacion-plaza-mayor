param(
    [string]$Root = "C:\Users\USUARIO\Documents\Claude\Projects\MEJORA CARRETERA GUADALMAR\PROYECTO 535\535.2\535.2.2 Mejora Carretera Guadalmar\POU 2026"
)

$ErrorActionPreference = "Stop"

$bc3Path = Join-Path $Root 'PRESUPUESTO\535.2.bc3'
$encoding = [System.Text.Encoding]::GetEncoding(1252)
$bc3 = [System.IO.File]::ReadAllText($bc3Path, $encoding)

$repavArea = 4919.637
$repavAreaRounded = 4919.64
$repavTn = [math]::Round(($repavArea * 2.40 * 0.05), 2)
$newPav006 = 3032.49
$newRiegoAd = 25270.72

$fresadoArea = 4924.218
$fresadoAreaRounded = 4924.22
$newDyt012Price = 5.87

$patterns = @(
    @{
        Pattern = '^~C\|DYT012\|.*$'
        Replacement = '~C|DYT012|m²|FRESADO DE FIRME 4 CMS ESPESOR|5.87|260407|0|'
    },
    @{
        Pattern = '^~D\|DYT012\|.*$'
        Replacement = '~D|DYT012|R_FRESADORA\1\0.04\M07CB020\1\0.01\O01OA070\1\0.02\%CI\1\0.03\|'
    },
    @{
        Pattern = '^~M\|MCG-1\.01#\\DYT012\|.*$'
        Replacement = '~M|MCG-1.01#\DYT012|1\1\6\|4924.22|\Según mediciones auxiliares\\\\\\FRESADO 4CM (Civil 3D)\1\4924.22\\\|'
    },
    @{
        Pattern = '^~M\|MCG-1\.03#\\PAV006\|.*$'
        Replacement = '~M|MCG-1.03#\PAV006|1\3\5\|3032.49|\Según mediciones auxiliares\\\\\\TRAMO 1\1\1700.98\\\\TRAMO 2\1\512.26\\\\AV MANUEL CASTILLO\1\67.20\\\\CTRA GUADALMAR\1\76.13\\\\CALLE GUADALHORCE\1\85.56\\\\REPAVIMENTACION 5CM (4919,64 m2 x 0,05 m x 2,40 t/m3)\1\590.36\\\|'
    },
    @{
        Pattern = '^~M\|MCG-1\.03#\\RIEGOAD\|.*$'
        Replacement = '~M|MCG-1.03#\RIEGOAD|1\3\6\|25270.72|\Según mediciones auxiliares (tn/2,40/0,05)\\\\\\TRAMO 1\1\14174.83\\\\TRAMO 2\1\4268.83\\\\AV MANUEL CASTILLO\1\560.00\\\\CTRA GUADALMAR\1\634.42\\\\CALLE GUADALHORCE\1\713.00\\\\REPAVIMENTACION 5CM\1\4919.64\\\|'
    }
)

foreach ($item in $patterns) {
    if (-not [regex]::IsMatch($bc3, $item.Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)) {
        throw "No se ha encontrado en el BC3 el patron esperado: $($item.Pattern)"
    }
    $bc3 = [regex]::Replace($bc3, $item.Pattern, $item.Replacement, [System.Text.RegularExpressions.RegexOptions]::Multiline)
}

[System.IO.File]::WriteAllText($bc3Path, $bc3, $encoding)

$summary = @"
Actualizacion de firme aplicada:
- DYT012 actualizado a 4 cm, precio 5,87 EUR/m2.
- Medicion DYT012 actualizada a $fresadoAreaRounded m2 segun FRESADO 4CM.html.
- PAV006 incrementado en $repavTn tn por REPAVIMENTACION 5CM.
- RIEGOAD incrementado en $repavAreaRounded m2 por REPAVIMENTACION 5CM.
"@

[System.IO.File]::WriteAllText((Join-Path $Root 'DOCS\Documentos de Trabajo\5.- Dimensionamiento del Firme\Actualizacion_Firme_Repav_Fresado.md'), $summary, [System.Text.Encoding]::UTF8)
