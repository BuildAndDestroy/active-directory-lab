# Temporary routing on JUMP-CORP for forest trust setup (corp.lab ↔ foothold.lab).
#   .\11c-jump-setup-routing.ps1 -Mode Enable    # before 04c / 04d trust scripts
#   .\11c-jump-setup-routing.ps1 -Mode Disable   # after trust is verified
param(
    [string]$Role,
    [ValidateSet('Enable', 'Disable')]
    [string]$Mode = 'Enable'
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"

Assert-LabRole -Allowed @('JUMP-CORP') -Role $Role | Out-Null

if ($Mode -eq 'Enable') {
    Enable-LabJumpSetupForwarding
    Write-Host @"

JUMP routing enabled for forest trust setup only.
Next: DC-CORP .\04c-corp-foothold-trust.ps1 then DC-FOOTHOLD .\04d-foothold-corp-forwarder.ps1
When done: .\11c-jump-setup-routing.ps1 -Mode Disable
"@
} else {
    Disable-LabIpForwarding
    Write-Host 'JUMP routing disabled — Kali must pivot through JUMP again.'
}
