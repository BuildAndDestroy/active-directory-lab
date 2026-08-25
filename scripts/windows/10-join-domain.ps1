# Join the forest for this hostname. Reboots when done.
#   .\10-join-domain.ps1
param([string]$Role)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"

$name = Assert-LabRole -Allowed @('SRV-CORP', 'CA-CORP', 'WIN10-CORP', 'DC-CORP2') -Role $Role
$hostinfo = Get-LabHost -Role $name
$part = Get-CimInstance Win32_ComputerSystem
if ($part.PartOfDomain) {
    Write-Host "Already joined to $($part.Domain)"
    exit 0
}

if ($hostinfo.Forest -eq 'Partner') {
    Add-Computer -DomainName $Lab.PartnerDomain -Credential (Get-PartnerDaCredential) -Force
} elseif ($hostinfo.Forest -eq 'Foothold') {
    Add-Computer -DomainName $Lab.FootholdDomain -Server $Lab.FootholdDc1 `
        -Credential (Get-FootholdDaCredential) -Force
} else {
    Add-Computer -DomainName $Lab.CorpDomain -Credential (Get-CorpDaCredential) -Force
}
Write-Host 'Join requested. Rebooting.'
Restart-Computer -Force
