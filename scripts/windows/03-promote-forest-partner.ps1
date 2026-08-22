# Run on DC-PARTNER. Reboots when promotion finishes.
param([string]$Role)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"
Assert-LabRole -Allowed @('DC-PARTNER') -Role $Role | Out-Null

Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools
Import-Module ADDSDeployment

Install-ADDSForest `
    -DomainName $Lab.PartnerDomain `
    -DomainNetbiosName $Lab.PartnerNetbios `
    -InstallDns:$true `
    -SafeModeAdministratorPassword (ConvertTo-LabSecureString $Lab.SafeModePartner) `
    -CreateDnsDelegation:$false `
    -DatabasePath 'C:\Windows\NTDS' `
    -LogPath 'C:\Windows\NTDS' `
    -SysvolPath 'C:\Windows\SYSVOL' `
    -Force:$true
