[CmdletBinding()]
param(
    [string]$NodesPath = ".\\CONTROL\\trazabilidad\\nodes.json",
    [string]$EdgesPath = ".\\CONTROL\\trazabilidad\\edges.json",
    [string]$CoveragePath = ".\\CONTROL\\trazabilidad\\coverage.json",
    [string]$RootPath = "."
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-Result {
    param(
        [System.Collections.Generic.List[object]]$Bucket,
        [string]$Level,
        [string]$Message
    )

    $Bucket.Add([pscustomobject]@{
        Level = $Level
        Message = $Message
    })
}

$rootResolved = (Resolve-Path -LiteralPath $RootPath).Path
$results = New-Object 'System.Collections.Generic.List[object]'

foreach ($file in @($NodesPath, $EdgesPath, $CoveragePath)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        Add-Result -Bucket $results -Level "ERROR" -Message "Missing traceability file: $file"
    }
}

if (@($results | Where-Object { $_.Level -eq "ERROR" }).Count -gt 0) {
    foreach ($errorItem in $results) {
        if ($errorItem.Level -eq "ERROR") {
            Write-Error $errorItem.Message -ErrorAction Continue
        }
    }
    exit 1
}

$nodesDoc = Get-Content -LiteralPath $NodesPath -Raw | ConvertFrom-Json
$edgesDoc = Get-Content -LiteralPath $EdgesPath -Raw | ConvertFrom-Json
$coverageDoc = Get-Content -LiteralPath $CoveragePath -Raw | ConvertFrom-Json
$graphStatus = ""
if ($null -ne $nodesDoc.status) {
    $graphStatus = [string]$nodesDoc.status
}

if ($null -eq $nodesDoc.nodes) {
    Add-Result -Bucket $results -Level "ERROR" -Message "nodes.json does not contain a nodes array"
}
elseif ($nodesDoc.nodes.Count -eq 0) {
    if ($graphStatus -eq "bootstrap") {
        Add-Result -Bucket $results -Level "WARN" -Message "Traceability graph is still at bootstrap scope; nodes array is intentionally empty"
    }
    else {
        Add-Result -Bucket $results -Level "ERROR" -Message "nodes.json does not contain any nodes"
    }
}

if ($null -eq $edgesDoc.edges) {
    Add-Result -Bucket $results -Level "ERROR" -Message "edges.json does not contain an edges array"
}

$nodeIds = @{}
foreach ($node in $nodesDoc.nodes) {
    if ([string]::IsNullOrWhiteSpace($node.id)) {
        Add-Result -Bucket $results -Level "ERROR" -Message "A node is missing id"
        continue
    }

    if ($nodeIds.ContainsKey($node.id)) {
        Add-Result -Bucket $results -Level "ERROR" -Message "Duplicate node id: $($node.id)"
        continue
    }
    $nodeIds[$node.id] = $true

    if ([string]::IsNullOrWhiteSpace($node.type)) {
        Add-Result -Bucket $results -Level "ERROR" -Message "Node $($node.id) is missing type"
    }

    if ([string]::IsNullOrWhiteSpace($node.path)) {
        Add-Result -Bucket $results -Level "ERROR" -Message "Node $($node.id) is missing path"
    }
    else {
        $resolvedPath = Join-Path $rootResolved $node.path
        if (-not (Test-Path -LiteralPath $resolvedPath)) {
            if (($node.status -as [string]) -eq "missing_local") {
                Add-Result -Bucket $results -Level "WARN" -Message "Node $($node.id) is declared as missing_local: $($node.path)"
            }
            else {
                Add-Result -Bucket $results -Level "ERROR" -Message "Node $($node.id) points to missing path: $($node.path)"
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($node.authority)) {
        Add-Result -Bucket $results -Level "WARN" -Message "Node $($node.id) has no authority declared"
    }
}

$allowedRelations = @(
    "backs",
    "derived_from",
    "justifies",
    "summarizes",
    "checks",
    "exports_to"
)

foreach ($edge in $edgesDoc.edges) {
    if ([string]::IsNullOrWhiteSpace($edge.from) -or [string]::IsNullOrWhiteSpace($edge.to)) {
        Add-Result -Bucket $results -Level "ERROR" -Message "An edge is missing from or to"
        continue
    }

    if (-not $nodeIds.ContainsKey($edge.from)) {
        Add-Result -Bucket $results -Level "ERROR" -Message "Edge source node does not exist: $($edge.from)"
    }

    if (-not $nodeIds.ContainsKey($edge.to)) {
        Add-Result -Bucket $results -Level "ERROR" -Message "Edge target node does not exist: $($edge.to)"
    }

    if ([string]::IsNullOrWhiteSpace($edge.relation)) {
        Add-Result -Bucket $results -Level "ERROR" -Message "Edge $($edge.from) -> $($edge.to) is missing relation"
    }
    elseif ($allowedRelations -notcontains [string]$edge.relation) {
        Add-Result -Bucket $results -Level "WARN" -Message "Edge $($edge.from) -> $($edge.to) uses non-canonical relation: $($edge.relation)"
    }
}

$coverageFields = @(
    "word_tables_with_excel_source_pct",
    "memoria_sections_backed_by_annex_pct",
    "bc3_concepts_with_document_support_pct",
    "outputs_with_authority_defined_pct"
)

foreach ($field in $coverageFields) {
    if ($null -eq $coverageDoc.$field) {
        Add-Result -Bucket $results -Level "ERROR" -Message "coverage.json is missing metric: $field"
        continue
    }

    $value = [double]$coverageDoc.$field
    if ($value -lt 0 -or $value -gt 100) {
        Add-Result -Bucket $results -Level "ERROR" -Message "coverage.json metric out of range 0-100: $field=$value"
    }
}

if ($coverageDoc.scope -eq "bootstrap") {
    Add-Result -Bucket $results -Level "WARN" -Message "Traceability graph is still at bootstrap scope; project-specific relations are pending"
}
elseif ($coverageDoc.scope -eq "seed") {
    Add-Result -Bucket $results -Level "WARN" -Message "Traceability graph is still at seed scope; table-level and concept-level links remain pending"
}

$errors = @($results | Where-Object { $_.Level -eq "ERROR" })
$warnings = @($results | Where-Object { $_.Level -eq "WARN" })

Write-Host "Traceability graph summary"
Write-Host "  Root: $rootResolved"
Write-Host "  Nodes: $($nodesDoc.nodes.Count)"
Write-Host "  Edges: $($edgesDoc.edges.Count)"
Write-Host "  Errors: $($errors.Count)"
Write-Host "  Warnings: $($warnings.Count)"

foreach ($warning in $warnings) {
    Write-Warning $warning.Message
}

foreach ($errorItem in $errors) {
    Write-Error $errorItem.Message -ErrorAction Continue
}

if ($errors.Count -gt 0) {
    exit 1
}
