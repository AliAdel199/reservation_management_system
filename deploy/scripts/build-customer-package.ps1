param(
  [string]$ProjectRoot = "D:\reservation_management_system",
  [string]$ApiBaseUrl = "http://localhost:7070/api"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path $ProjectRoot
$deployRoot = Join-Path $repoRoot "deploy"
$apiRoot = Join-Path $deployRoot "api"
$appRoot = Join-Path $deployRoot "app"

New-Item -ItemType Directory -Force $apiRoot, $appRoot | Out-Null

Write-Host "Compiling backend API..."
Push-Location (Join-Path $repoRoot "backend")
try {
  Write-Host "Restoring backend packages..."
  dart pub get
  dart compile exe bin/server.dart -o (Join-Path $apiRoot "reservation_api.exe")
} finally {
  Pop-Location
}

Write-Host "Building Flutter Windows app..."
Push-Location $repoRoot
try {
  Write-Host "Restoring Flutter packages..."
  flutter pub get
  flutter build windows --release --dart-define=API_BASE_URL=$ApiBaseUrl
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
