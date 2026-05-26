param(
  [string]$TaskName = "ReservationManagementDatabaseBackup",
  [string]$InstallRoot = "D:\reservation_management_system\deploy",
  [string]$DailyAt = "02:00"
)

$ErrorActionPreference = "Stop"

$deployRoot = $InstallRoot
$backupScript = Join-Path $deployRoot "scripts\run-database-backup.ps1"
$apiRoot = Join-Path $deployRoot "api"
$envPath = Join-Path $apiRoot ".env"

if (-not (Test-Path $backupScript)) { throw "Backup script was not found: $backupScript" }
if (-not (Test-Path $envPath)) { throw "API .env was not found: $envPath" }

$runAt = [DateTime]::ParseExact($DailyAt, "HH:mm", $null)

$action = New-ScheduledTaskAction `
  -Execute "powershell.exe" `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$backupScript`" -ApiRoot `"$apiRoot`""

$trigger = New-ScheduledTaskTrigger -Daily -At $runAt

$settings = New-ScheduledTaskSettingsSet `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -StartWhenAvailable `
  -ExecutionTimeLimit (New-TimeSpan -Hours 2)

$principal = New-ScheduledTaskPrincipal `
  -UserId "SYSTEM" `
  -LogonType ServiceAccount `
  -RunLevel Highest

Register-ScheduledTask `
  -TaskName $TaskName `
  -Action $action `
  -Trigger $trigger `
  -Settings $settings `
  -Principal $principal `
  -Force | Out-Null

Write-Host "Database backup task installed: $TaskName at $DailyAt"
