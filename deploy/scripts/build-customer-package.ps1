param(
  [string]$ProjectRoot = "D:\reservation_management_system",
  [string]$ApiBaseUrl = "http://localhost:7070/api",
  [bool]$ObfuscateFlutter = $true,
  [bool]$RequireLicense = $true
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path $ProjectRoot
$deployRoot = Join-Path $repoRoot "deploy"
$apiRoot = Join-Path $deployRoot "api"
$appRoot = Join-Path $deployRoot "app"
$symbolsRoot = Join-Path $repoRoot "build\symbols\customer"

New-Item -ItemType Directory -Force $apiRoot, $appRoot | Out-Null

function Stop-ProcessIfRunning([string]$Name) {
  $processes = Get-Process -Name $Name -ErrorAction SilentlyContinue
  if ($null -eq $processes) { return }

  Write-Host "Stopping running process: $Name"
  $processes | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2
}

Stop-ProcessIfRunning "reservation_api"
Stop-ProcessIfRunning "reservation_management_system"

Write-Host "Compiling backend API..."
Push-Location (Join-Path $repoRoot "backend")
try {
  Write-Host "Restoring backend packages..."
  dart pub get
  $dartCompileArgs = @(
    "compile",
    "exe",
    "bin/server.dart",
    "-o",
    (Join-Path $apiRoot "reservation_api.exe")
  )

  if ($RequireLicense) {
    $dartCompileArgs += "-DLICENSE_REQUIRED=true"
  }

  dart @dartCompileArgs
} finally {
  Pop-Location
}

Write-Host "Building Flutter Windows app..."
Push-Location $repoRoot
try {
  Write-Host "Restoring Flutter packages..."
  flutter pub get
  $flutterArgs = @(
    "build",
    "windows",
    "--release",
    "--dart-define=API_BASE_URL=$ApiBaseUrl"
  )

  if ($ObfuscateFlutter) {
    New-Item -ItemType Directory -Force $symbolsRoot | Out-Null
    $flutterArgs += "--obfuscate"
    $flutterArgs += "--split-debug-info=$symbolsRoot"
  }

  flutter @flutterArgs
} finally {
  Pop-Location
}

$releaseDir = Join-Path $repoRoot "build\windows\x64\runner\Release"
if (-not (Test-Path $releaseDir)) {
  throw "Flutter release output was not found: $releaseDir"
}

Write-Host "Copying Flutter release files..."
Remove-Item -Recurse -Force $appRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $appRoot | Out-Null
Copy-Item -Path (Join-Path $releaseDir "*") -Destination $appRoot -Recurse -Force

Write-Host "Customer package build completed."
Write-Host "API: $apiRoot"
Write-Host "App: $appRoot"
