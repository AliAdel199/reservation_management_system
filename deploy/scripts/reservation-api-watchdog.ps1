param(
  [string]$InstallRoot = "D:\reservation_management_system\deploy"
)

$ErrorActionPreference = "Continue"

$deployRoot = $InstallRoot

$apiRoot = Join-Path $deployRoot "api"
$apiExe = Join-Path $apiRoot "reservation_api.exe"
$envPath = Join-Path $apiRoot ".env"
$logRoot = Join-Path $deployRoot "logs"
$stdoutLog = Join-Path $logRoot "reservation_api.out.log"
$stderrLog = Join-Path $logRoot "reservation_api.err.log"
$watchdogLog = Join-Path $logRoot "reservation_api.watchdog.log"
New-Item -ItemType Directory -Force $logRoot | Out-Null

function Write-WatchdogLog([string]$message) {
  try {
    Add-Content -Path $watchdogLog -Value "$(Get-Date -Format s) $message" -ErrorAction Stop
  } catch {
    Write-Host "$(Get-Date -Format s) $message"
  }
}

function Get-EnvValue([string]$key, [string]$fallback) {
  if (-not (Test-Path $envPath)) { return $fallback }
  $line = Get-Content $envPath | Where-Object { $_ -match "^$key=" } | Select-Object -First 1
  if ([string]::IsNullOrWhiteSpace($line)) { return $fallback }
  return $line.Substring($key.Length + 1).Trim()
}

function Start-Api {
  if (-not (Test-Path $apiExe)) {
    Write-WatchdogLog "API executable not found: $apiExe"
    Start-Sleep -Seconds 30
    return
  }

  $process = Start-Process `
    -FilePath $apiExe `
    -WorkingDirectory $apiRoot `
    -WindowStyle Hidden `
    -RedirectStandardOutput $stdoutLog `
    -RedirectStandardError $stderrLog `
    -PassThru

  Write-WatchdogLog "API started. PID=$($process.Id)"
}

while ($true) {
  $port = Get-EnvValue "PORT" "7070"
  $healthUrl = "http://127.0.0.1:$port/health"
  $process = Get-Process -Name "reservation_api" -ErrorAction SilentlyContinue | Select-Object -First 1

  if ($null -eq $process) {
    Start-Api
    Start-Sleep -Seconds 10
    continue
  }

  try {
    $response = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 5
    if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
      throw "Health check returned status $($response.StatusCode)."
    }
  } catch {
    Write-WatchdogLog "Health check failed: $($_.Exception.Message). Restarting API..."
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Start-Api
  }

  Start-Sleep -Seconds 15
}
