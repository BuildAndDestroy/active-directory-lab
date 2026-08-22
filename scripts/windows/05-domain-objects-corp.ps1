# Run on DC-CORP (or DC-CORP2).
param([string]$Role)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"
Assert-LabRole -Allowed @('DC-CORP', 'DC-CORP2') -Role $Role | Out-Null
Import-Module ActiveDirectory

$dn = (Get-ADDomain).DistinguishedName
$ous = @('CorpUsers', 'CorpGroups', 'CorpServers', 'CorpWorkstations')
foreach ($name in $ous) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$name'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $name -Path $dn
    }
}

function Ensure-LabGroup {
    param([string]$Name, [string]$Path)
    if (-not (Get-ADGroup -Filter "Name -eq '$Name'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $Name -GroupScope Global -GroupCategory Security -Path $Path
    }
}

$gPath = "OU=CorpGroups,$dn"
Ensure-LabGroup -Name 'CorpStaff' -Path $gPath
Ensure-LabGroup -Name 'ITStaff' -Path $gPath
Ensure-LabGroup -Name 'Helpdesk' -Path $gPath
Add-ADGroupMember -Identity 'CorpStaff' -Members 'ITStaff' -ErrorAction SilentlyContinue
Add-ADGroupMember -Identity 'ITStaff' -Members 'Helpdesk' -ErrorAction SilentlyContinue

function Ensure-LabUser {
    param([string]$Sam, [string]$Given, [string]$Sur, [string]$Password, [string]$Path)
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$Sam'" -ErrorAction SilentlyContinue)) {
        New-ADUser -Name "$Given $Sur" -GivenName $Given -Surname $Sur -SamAccountName $Sam `
            -UserPrincipalName "$Sam@$($Lab.CorpDomain)" `
            -AccountPassword (ConvertTo-LabSecureString $Password) `
            -Enabled $true -ChangePasswordAtLogon $false -PasswordNeverExpires $true `
            -Path $Path
    }
}

$uPath = "OU=CorpUsers,$dn"
Ensure-LabUser -Sam 'jdoe' -Given 'Jane' -Sur 'Doe' -Password $Lab.JdoePassword -Path $uPath
Ensure-LabUser -Sam 'hadmin' -Given 'Hank' -Sur 'Admin' -Password $Lab.HadminPassword -Path $uPath
Ensure-LabUser -Sam 'svc_web' -Given 'Web' -Sur 'Service' -Password $Lab.SvcWebPassword -Path $uPath
Add-ADGroupMember -Identity 'CorpStaff' -Members 'jdoe' -ErrorAction SilentlyContinue
Add-ADGroupMember -Identity 'Helpdesk' -Members 'hadmin' -ErrorAction SilentlyContinue

setspn -S 'HTTP/srv-corp.corp.lab' "$($Lab.CorpNetbios)\svc_web"
setspn -S 'HTTP/srv-corp' "$($Lab.CorpNetbios)\svc_web"

Write-Host 'corp.lab OUs, nested groups, users, and svc_web SPNs in place.'
Get-ADUser -Filter * -SearchBase $uPath | Select-Object SamAccountName, Enabled
Get-ADGroupMember -Identity Helpdesk -Recursive | Select-Object SamAccountName
