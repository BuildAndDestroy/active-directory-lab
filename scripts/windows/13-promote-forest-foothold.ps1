# Run on DC-FOOTHOLD. Creates foothold.lab forest on the isolated foothold subnet.
param([string]$Role)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"
Assert-LabRole -Allowed @('DC-FOOTHOLD') -Role $Role | Out-Null

Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools
Import-Module ADDSDeployment

Install-ADDSForest `
    -DomainName $Lab.FootholdDomain `
    -DomainNetbiosName $Lab.FootholdNetbios `
    -InstallDns:$true `
    -SafeModeAdministratorPassword (ConvertTo-LabSecureString $Lab.SafeModeFoothold) `
    -CreateDnsDelegation:$false `
    -DatabasePath 'C:\Windows\NTDS' `
    -LogPath 'C:\Windows\NTDS' `
    -SysvolPath 'C:\Windows\SYSVOL' `
    -Force:$true
