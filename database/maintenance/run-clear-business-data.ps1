param(
  [string]$DatabaseUrl = $env:DATABASE_URL,
  [string]$PsqlPath = "psql"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($DatabaseUrl)) {
  throw "DATABASE_URL is required. Set `$env:DATABASE_URL or pass -DatabaseUrl."
}

$sqlPath = Join-Path $PSScriptRoot "clear_business_data.sql"

if (-not (Test-Path -LiteralPath $sqlPath)) {
  throw "SQL file was not found: $sqlPath"
}

Write-Host "Cleaning business data using: $sqlPath"
& $PsqlPath $DatabaseUrl -v ON_ERROR_STOP=1 -f $sqlPath

if ($LASTEXITCODE -ne 0) {
  throw "psql failed with exit code $LASTEXITCODE"
}

Write-Host "Business data cleanup completed successfully."
