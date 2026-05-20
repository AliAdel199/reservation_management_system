param(
  [string]$InstallRoot = "D:\reservation_management_system\deploy",
  [string]$DatabaseName = "reservation_management",
  [string]$DatabaseUser = "postgres",
  [Parameter(Mandatory = $true)]
  [string]$DatabasePassword,
  [int]$ApiPort = 7070,
  [string]$AdminUsername = "admin",
  [string]$AdminPassword = "Admin@12345",
  [string]$AdminFullName = "System Administrator",
  [string]$AdminEmail = "admin@finance.local"
)

$ErrorActionPreference = "Stop"

$deployRoot = $InstallRoot
$apiRoot = Join-Path $deployRoot "api"
New-Item -ItemType Directory -Force $apiRoot | Out-Null

$secretBytes = New-Object byte[] 48
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try {
  $rng.GetBytes($secretBytes)
} finally {
  $rng.Dispose()
}
$jwtSecret = [Convert]::ToBase64String($secretBytes)

$databaseUrl = "postgresql://$DatabaseUser`:$DatabasePassword@localhost:5432/$DatabaseName`?sslmode=disable"

$envContent = @"
APP_NAME=Government Reservation API
HOST=0.0.0.0
PORT=$ApiPort
DATABASE_URL=$databaseUrl
JWT_SECRET=$jwtSecret
JWT_EXPIRES_IN_HOURS=8
DEFAULT_ADMIN_USERNAME=$AdminUsername
DEFAULT_ADMIN_PASSWORD=$AdminPassword
DEFAULT_ADMIN_FULL_NAME=$AdminFullName
DEFAULT_ADMIN_EMAIL=$AdminEmail
AUTO_SEED_ADMIN=true
"@

$envPath = Join-Path $apiRoot ".env"
Set-Content -Path $envPath -Value $envContent -Encoding UTF8
Write-Host "API environment file created: $envPath"
