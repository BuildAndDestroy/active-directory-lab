# Pull all lab scripts from the KVM gateway HTTP share onto this Windows VM.
# On the Linux hypervisor first: ./scripts/host/serve-windows-scripts.sh
#
# Corp (.57) guests:
#   irm http://192.168.57.1:8080/00-download.ps1 | iex
# Foothold (.58) guests:
#   irm http://192.168.58.1:8080/00-download.ps1 | iex
param(
    [string]$BaseUrl,
    [string]$Dest = 'C:\Lab'
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Test-LabHttpBase {
    param([string]$Url)
    try {
        $null = Invoke-WebRequest -Uri "$Url/manifest.txt" -UseBasicParsing -TimeoutSec 5
        return $true
    } catch {
        return $false
    }
}

if (-not $BaseUrl) {
    # Prefer the gateway on the subnet this guest is actually on.
    $addrs = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -like '192.168.58.*' -or $_.IPAddress -like '192.168.57.*' } |
        Select-Object -ExpandProperty IPAddress)
    $candidates = @()
    if ($addrs | Where-Object { $_ -like '192.168.58.*' }) {
        $candidates += 'http://192.168.58.1:8080'
    }
    if ($addrs | Where-Object { $_ -like '192.168.57.*' }) {
        $candidates += 'http://192.168.57.1:8080'
    }
    # Fallback order if adapters are still on DHCP / unknown
    $candidates += @('http://192.168.58.1:8080', 'http://192.168.57.1:8080')
    $candidates = $candidates | Select-Object -Unique

    foreach ($c in $candidates) {
        Write-Host "Trying $c ..."
        if (Test-LabHttpBase -Url $c) {
            $BaseUrl = $c
            break
        }
    }
    if (-not $BaseUrl) {
        throw 'Cannot reach lab script server on 192.168.58.1:8080 or 192.168.57.1:8080. Is serve-windows-scripts.sh running?'
    }
}

Write-Host "Using BaseUrl $BaseUrl"
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
Write-Host "Next: .\00-bootstrap.ps1 -Role <THIS-VM-ROLE>"
Get-ChildItem $Dest | Select-Object Name, Length
