# JUMP-CORP: dual-homed IPs, join foothold.lab via local DC, then harden (no IP forwarding).
#   .\11-join-jump.ps1
# Reboots after domain join; run again after reboot to confirm forwarding stays off.
param(
    [string]$Role,
    [int]$PreflightTcpTimeoutSec,
    [int]$PreflightDnsTimeoutSec,
    [int]$PreflightRetries,
    [switch]$SkipPreflight
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"

$name = Assert-LabRole -Allowed @('JUMP-CORP') -Role $Role
$hostinfo = Get-LabHost -Role $name

Set-LabDualHomedIp -Role $name

$part = Get-CimInstance Win32_ComputerSystem
if (-not $part.PartOfDomain) {
    if (-not $SkipPreflight) {
        Test-LabFootholdReachable -TcpTimeoutSec $PreflightTcpTimeoutSec `
            -DnsTimeoutSec $PreflightDnsTimeoutSec -Retries $PreflightRetries
    } else {
        Write-Host 'Skipping preflight (-SkipPreflight). Domain join may take several minutes on a slow DC.'
    }
    $dc = $Lab.FootholdDc1
    Write-Host "Joining $($Lab.FootholdDomain) via $dc (this can take a few minutes) ..."
    Add-Computer -DomainName $Lab.FootholdDomain -Server $dc `
        -Credential (Get-FootholdDaCredential) -Force
    Write-Host 'Join requested. Rebooting — run 11-join-jump.ps1 again after login as FOOTHOLD\Administrator.'
    Restart-Computer -Force
    exit 0
}

Write-Host "Already joined to $($part.Domain)"
Disable-LabIpForwarding
Write-Host @"

JUMP-CORP ready:
  Foothold NIC: $($hostinfo.FootholdAddress) (DNS DC-FOOTHOLD, metric 10, AD member)
  Corp NIC:     $($hostinfo.Address) (gw $($Lab.Gateway), no DNS, metric 200 — pivot path only)
  IP forwarding: off — Kali on 192.168.58.0/24 must pivot through this host.
"@
