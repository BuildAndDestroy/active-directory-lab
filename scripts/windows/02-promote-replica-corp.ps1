# Run on DC-CORP2. Joins corp.lab if needed, then promotes. Reboots when promoting.
param([string]$Role)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"
Assert-LabRole -Allowed @('DC-CORP2') -Role $Role | Out-Null

$da = Get-CorpDaCredential
$part = Get-CimInstance Win32_ComputerSystem
if ($part.PartOfDomain -eq $false) {
    Add-Computer -DomainName $Lab.CorpDomain -Credential $da -Force
    Write-Host 'Joined corp.lab. Rebooting; run this script again to promote.'
    Restart-Computer -Force
    exit 0
}

Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools
Import-Module ADDSDeployment

Install-ADDSDomainController `
    -DomainName $Lab.CorpDomain `
    -Credential $da `
    -InstallDns:$true `
    -CreateDnsDelegation:$false `
    -NoGlobalCatalog:$false `
    -DatabasePath 'C:\Windows\NTDS' `
    -LogPath 'C:\Windows\NTDS' `
    -SysvolPath 'C:\Windows\SYSVOL' `
    -SafeModeAdministratorPassword (ConvertTo-LabSecureString $Lab.SafeModeCorp) `
    -Force:$true
