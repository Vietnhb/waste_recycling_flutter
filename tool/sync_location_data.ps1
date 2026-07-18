param(
    [switch]$Check
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $projectRoot
$source = Join-Path $workspaceRoot '_source/server-side/src/main/resources/data/data_vn.json'
$destination = Join-Path $projectRoot 'assets/data/data_vn.json'

if (-not (Test-Path -LiteralPath $source)) {
    throw "Location source not found: $source"
}

if ($Check) {
    if (-not (Test-Path -LiteralPath $destination)) {
        throw "Flutter location fallback is missing: $destination"
    }
    $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash
    $destinationHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $destination).Hash
    if ($sourceHash -ne $destinationHash) {
        throw 'Flutter location fallback is out of sync. Run tool/sync_location_data.ps1.'
    }
    Write-Output 'Location catalogs are in sync.'
    exit 0
}

Copy-Item -LiteralPath $source -Destination $destination -Force
Write-Output "Synced location catalog to $destination"
