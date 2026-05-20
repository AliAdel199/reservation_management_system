param(
  [string]$TaskName = "ReservationManagementAPI"
)

$ErrorActionPreference = "Stop"

Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
Get-Process -Name "reservation_api" -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Host "API autostart task removed: $TaskName"
