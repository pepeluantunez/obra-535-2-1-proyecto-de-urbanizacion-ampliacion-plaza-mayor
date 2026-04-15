function New-ExcelTextCell {
    param([AllowNull()][object]$Value)
    [pscustomobject]@{
        __ExcelCell = $true
        Type        = 'String'
        Value       = if ($null -eq $Value) { '' } else { [string]$Value }
        Formula     = $null
    }
}

function New-ExcelNumberCell {
    param([AllowNull()][object]$Value)
    [pscustomobject]@{
        __ExcelCell = $true
        Type        = 'Number'
        Value       = if ($null -eq $Value -or $Value -eq '') { '' } else { [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0}', $Value) }
        Formula     = $null
    }
}

function New-ExcelFormulaCell {
    param(
        [string]$Formula,
        [AllowNull()][object]$Value,
        [ValidateSet('String','Number')]
        [string]$Type = 'Number'
    )
    [pscustomobject]@{
        __ExcelCell = $true
        Type        = $Type
        Value       = if ($null -eq $Value -or $Value -eq '') { '' } elseif ($Type -eq 'Number') { [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0}', $Value) } else { [string]$Value }
        Formula     = $Formula
    }
}

function ConvertTo-ExcelCell {
    param([AllowNull()][object]$Value)

    if ($null -ne $Value -and $null -ne $Value.PSObject -and ($Value.PSObject.Properties.Match('__ExcelCell').Count -gt 0)) {
        return $Value
    }

    if ($null -eq $Value) { return New-ExcelTextCell '' }
    if ($Value -is [int] -or $Value -is [double] -or $Value -is [decimal] -or $Value -is [float] -or $Value -is [long]) {
        return New-ExcelNumberCell $Value
    }
    return New-ExcelTextCell $Value
}

function New-ExcelObjectSheet {
    param(
        [string]$Name,
        [object[]]$Rows
    )
    [pscustomobject]@{
        Name    = $Name
        Kind    = 'Object'
        Headers = @()
        Rows    = $Rows
    }
}

function New-ExcelCustomSheet {
    param(
        [string]$Name,
        [string[]]$Headers,
        [object[]]$Rows
    )
    [pscustomobject]@{
        Name    = $Name
        Kind    = 'Custom'
        Headers = $Headers
        Rows    = $Rows
    }
}

function Get-ExcelXmlCell {
    param([AllowNull()][object]$CellValue)

    $cell = ConvertTo-ExcelCell $CellValue
    $type = $cell.Type
    $value = [Security.SecurityElement]::Escape([string]$cell.Value)
    $formulaAttr = ''
    if (-not [string]::IsNullOrWhiteSpace($cell.Formula)) {
        $formulaAttr = " ss:Formula=`"$([Security.SecurityElement]::Escape($cell.Formula))`""
    }
    return "<Cell$formulaAttr><Data ss:Type=`"$type`">$value</Data></Cell>"
}

function Get-ExcelXmlSheet {
    param([pscustomobject]$Sheet)

    $sb = [Text.StringBuilder]::new()
    [void]$sb.AppendLine("<Worksheet ss:Name=`"$([Security.SecurityElement]::Escape($Sheet.Name))`"><Table>")

    if ($Sheet.Kind -eq 'Object') {
        $headers = @()
        if ($Sheet.Rows.Count -gt 0) { $headers = $Sheet.Rows[0].PSObject.Properties.Name }
        [void]$sb.AppendLine('<Row>')
        foreach ($h in $headers) {
            [void]$sb.AppendLine((Get-ExcelXmlCell (New-ExcelTextCell $h)))
        }
        [void]$sb.AppendLine('</Row>')
        foreach ($row in $Sheet.Rows) {
            [void]$sb.AppendLine('<Row>')
            foreach ($h in $headers) {
                [void]$sb.AppendLine((Get-ExcelXmlCell $row.$h))
            }
            [void]$sb.AppendLine('</Row>')
        }
    }
    else {
        [void]$sb.AppendLine('<Row>')
        foreach ($h in $Sheet.Headers) {
            [void]$sb.AppendLine((Get-ExcelXmlCell (New-ExcelTextCell $h)))
        }
        [void]$sb.AppendLine('</Row>')
        foreach ($row in $Sheet.Rows) {
            [void]$sb.AppendLine('<Row>')
            foreach ($cell in $row) {
                [void]$sb.AppendLine((Get-ExcelXmlCell $cell))
            }
            [void]$sb.AppendLine('</Row>')
        }
    }

    [void]$sb.AppendLine('</Table></Worksheet>')
    return $sb.ToString()
}

function Write-ExcelXmlWorkbook {
    param(
        [string]$Path,
        [object[]]$Sheets
    )

    $sb = [Text.StringBuilder]::new()
    [void]$sb.AppendLine('<?xml version="1.0"?>')
    [void]$sb.AppendLine('<?mso-application progid="Excel.Sheet"?>')
    [void]$sb.AppendLine('<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet" xmlns:html="http://www.w3.org/TR/REC-html40">')
    foreach ($sheet in $Sheets) {
        [void]$sb.Append((Get-ExcelXmlSheet $sheet))
    }
    [void]$sb.AppendLine('</Workbook>')
    [IO.File]::WriteAllText($Path, $sb.ToString(), [Text.Encoding]::UTF8)
}
