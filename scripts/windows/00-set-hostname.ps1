# Rename this computer. Prefer 00-bootstrap.ps1 -Role DC-CORP (hostname + IP).
param(
    [Parameter(Mandatory)][ValidateSet('DC-CORP','DC-CORP2','DC-PARTNER','SRV-CORP','CA-CORP','WIN10-CORP')]
    [string]$Role,
    [switch]$NoReboot
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"
$Role = $Role.ToUpperInvariant()
Rename-Computer -NewName $Role -Force
Write-Host "Renamed to $Role."
if ($NoReboot) { exit 0 }
Restart-Computer -Force
