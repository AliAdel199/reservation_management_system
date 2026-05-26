param(
  [string]$ApiRoot = "D:\reservation_management_system\deploy\api"
)

$ErrorActionPreference = "Stop"

$envPath = Join-Path $ApiRoot ".env"
if (-not (Test-Path $envPath)) {
  throw "API .env was not found: $envPath"
}

function Get-EnvValue([string]$Key, [string]$Fallback = "") {
  $line = Get-Content $envPath | Where-Object { $_ -match "^$Key=" } | Select-Object -First 1
  if ([string]::IsNullOrWhiteSpace($line)) { return $Fallback }
  return $line.Substring($Key.Length + 1).Trim()
}

$databaseUrl = Get-EnvValue "DATABASE_URL"
if ([string]::IsNullOrWhiteSpace($databaseUrl)) {
  throw "DATABASE_URL is missing from $envPath"
}

$pgDumpPath = Get-EnvValue "PG_DUMP_PATH" "pg_dump"
$backupDir = Get-EnvValue "BACKUP_DIR" (Join-Path $ApiRoot "backups")
$retentionDays = [int](Get-EnvValue "BACKUP_RETENTION_DAYS" "30")

if (-not [System.IO.Path]::IsPathRooted($backupDir)) {
  $backupDir = Join-Path $ApiRoot $backupDir
}

New-Item -ItemType Directory -Force $backupDir | Out-Null

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = Join-Path $backupDir "reservation_backup_$stamp.dump"

& $pgDumpPath --format=custom --no-owner --no-privileges --file "$backupPath" "$databaseUrl"
if ($LASTEXITCODE -ne 0) {
  if (Test-Path $backupPath) { Remove-Item $backupPath -Force -ErrorAction SilentlyContinue }
  throw "pg_dump failed with exit code $LASTEXITCODE"
}

if ($retentionDays -gt 0) {
  $cutoff = (Get-Date).AddDays(-$retentionDays)
  Get-ChildItem -Path $backupDir -Filter "*.dump" -File |
    Where-Object { $_.LastWriteTime -lt $cutoff } |
    Remove-Item -Force -ErrorAction SilentlyContinue
}

Write-Host "Database backup created: $backupPath"
