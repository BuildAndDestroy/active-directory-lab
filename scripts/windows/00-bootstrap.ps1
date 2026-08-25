# First-boot: set hostname and static IP from -Role. Reboots if the name changed.
#   .\00-bootstrap.ps1 -Role DC-CORP
#   .\00-bootstrap.ps1 -Role JUMP-CORP
param(
    [Parameter(Mandatory)][ValidateSet(
        'DC-CORP','DC-CORP2','DC-PARTNER','DC-FOOTHOLD','SRV-CORP','CA-CORP','WIN10-CORP','JUMP-CORP','SRV-FOOTHOLD'
    )]
    [string]$Role,
    [switch]$NoReboot
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"

$Role = $Role.ToUpperInvariant()
Set-LabStaticIp -Role $Role

$current = $env:COMPUTERNAME.ToUpperInvariant()
if ($current -ne $Role) {
    Rename-Computer -NewName $Role -Force
    Write-Host "Renamed $current -> $Role."
    if ($NoReboot) {
        Write-Host 'Reboot, then continue with the numbered script for this role.'
        exit 0
    }
    Restart-Computer -Force
}

Write-Host "Hostname and IP are set for $Role. Next: run the numbered script for this VM (see README)."
