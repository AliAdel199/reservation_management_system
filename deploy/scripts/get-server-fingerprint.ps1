$ErrorActionPreference = "Stop"

function Get-Sha256([string]$value) {
  $normalized = $value.Trim().ToLowerInvariant()
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($normalized)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $hashBytes = $sha.ComputeHash($bytes)
  return ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ""
}

try {
  $machineGuid = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Cryptography").MachineGuid
  if (-not [string]::IsNullOrWhiteSpace($machineGuid)) {
    $fingerprint = Get-Sha256 $machineGuid
    Write-Host "source=windows_machine_guid"
    Write-Host "fingerprint=$fingerprint"
    exit 0
  }
} catch {
  # Fall back to hostname below.
}

$fingerprint = Get-Sha256 $env:COMPUTERNAME
Write-Host "source=hostname"
Write-Host "fingerprint=$fingerprint"
