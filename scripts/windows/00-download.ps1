# Pull all lab scripts from the KVM gateway HTTP share onto this Windows VM.
# On the Linux hypervisor first: ./scripts/host/serve-windows-scripts.sh
#
# One-liner (elevated PowerShell, DHCP or gateway 192.168.57.1):
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   irm http://192.168.57.1:8080/00-download.ps1 | iex
param(
    [string]$BaseUrl = 'http://192.168.57.1:8080',
    [string]$Dest = 'C:\Lab'
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

New-Item -ItemType Directory -Path $Dest -Force | Out-Null
$manifestUrl = "$BaseUrl/manifest.txt"
Write-Host "Fetching $manifestUrl"
$manifest = Invoke-WebRequest -Uri $manifestUrl -UseBasicParsing
$files = $manifest.Content -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^#' }

if ($files.Count -lt 1) { throw "Empty manifest from $manifestUrl" }

foreach ($name in $files) {
    $out = Join-Path $Dest $name
    Write-Host "GET $name"
    Invoke-WebRequest -Uri "$BaseUrl/$name" -OutFile $out -UseBasicParsing
}

Set-Location $Dest
Write-Host "Scripts are in $Dest"
Write-Host "Next: .\00-bootstrap.ps1 -Role DC-CORP   (use this VM's role name)"
Get-ChildItem $Dest | Select-Object Name, Length
