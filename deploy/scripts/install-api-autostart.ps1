param(
  [string]$TaskName = "ReservationManagementAPI",
  [string]$InstallRoot = "D:\reservation_management_system\deploy"
)

$ErrorActionPreference = "Stop"

$deployRoot = $InstallRoot

$watchdog = Join-Path $deployRoot "scripts\reservation-api-watchdog.ps1"
$apiExe = Join-Path $deployRoot "api\reservation_api.exe"
$envPath = Join-Path $deployRoot "api\.env"

if (-not (Test-Path $watchdog)) { throw "Watchdog script was not found: $watchdog" }
if (-not (Test-Path $apiExe)) { throw "API executable was not found: $apiExe" }
if (-not (Test-Path $envPath)) { throw "API .env was not found: $envPath" }

$action = New-ScheduledTaskAction `
  -Execute "powershell.exe" `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$watchdog`" -InstallRoot `"$deployRoot`""

$triggers = @(
  New-ScheduledTaskTrigger -AtStartup
  New-ScheduledTaskTrigger -AtLogOn
)

$settings = New-ScheduledTaskSettingsSet `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -ExecutionTimeLimit ([TimeSpan]::Zero) `
  -RestartCount 999 `
  -RestartInterval (New-TimeSpan -Minutes 1)

$principal = New-ScheduledTaskPrincipal `
  -UserId "SYSTEM" `
  -LogonType ServiceAccount `
  -RunLevel Highest

Register-ScheduledTask `
  -TaskName $TaskName `
  -Action $action `
  -Trigger $triggers `
  -Settings $settings `
  -Principal $principal `
  -Force | Out-Null

Start-ScheduledTask -TaskName $TaskName
Write-Host "API autostart task installed and started: $TaskName"
