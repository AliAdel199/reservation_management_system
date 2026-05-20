param(
  [string]$InstallRoot = "D:\reservation_management_system\deploy",
  [string]$DatabaseName = "reservation_management",
  [string]$DatabaseUser = "postgres",
  [Parameter(Mandatory = $true)]
  [string]$DatabasePassword,
  [string]$PsqlPath = "psql",
  [string]$SqlFile = ""
)

$ErrorActionPreference = "Stop"

$deployRoot = $InstallRoot
if ([string]::IsNullOrWhiteSpace($SqlFile)) {
  $SqlFile = Join-Path $deployRoot "sql\001_customer_database_setup.sql"
}

if (-not (Test-Path $SqlFile)) {
  throw "SQL setup file was not found: $SqlFile"
}

$env:PGPASSWORD = $DatabasePassword

Write-Host "Checking PostgreSQL database '$DatabaseName'..."
$exists = & $PsqlPath -U $DatabaseUser -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$DatabaseName'"
if ($LASTEXITCODE -ne 0) {
  throw "Failed to connect to PostgreSQL using user '$DatabaseUser'."
}

if ([string]::IsNullOrWhiteSpace($exists)) {
  Write-Host "Creating database '$DatabaseName'..."
  & $PsqlPath -U $DatabaseUser -d postgres -c "CREATE DATABASE `"$DatabaseName`" WITH ENCODING 'UTF8';"
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to create database '$DatabaseName'."
  }
} else {
  Write-Host "Database '$DatabaseName' already exists."
}

Write-Host "Running customer SQL setup..."
& $PsqlPath -U $DatabaseUser -d $DatabaseName -f $SqlFile
if ($LASTEXITCODE -ne 0) {
  throw "Database setup failed."
}

Write-Host "Database setup completed successfully."
