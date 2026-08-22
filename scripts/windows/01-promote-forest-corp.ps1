# Run on DC-CORP. Reboots when promotion finishes.
param([string]$Role)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"
Assert-LabRole -Allowed @('DC-CORP') -Role $Role | Out-Null

Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools
Import-Module ADDSDeployment

Install-ADDSForest `
    -DomainName $Lab.CorpDomain `
    -DomainNetbiosName $Lab.CorpNetbios `
    -InstallDns:$true `
    -SafeModeAdministratorPassword (ConvertTo-LabSecureString $Lab.SafeModeCorp) `
    -CreateDnsDelegation:$false `
    -DatabasePath 'C:\Windows\NTDS' `
    -LogPath 'C:\Windows\NTDS' `
    -SysvolPath 'C:\Windows\SYSVOL' `
    -Force:$true
