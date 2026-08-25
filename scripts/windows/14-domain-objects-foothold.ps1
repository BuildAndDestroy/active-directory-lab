# Run on DC-FOOTHOLD after forest promotion.
param([string]$Role)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"
Assert-LabRole -Allowed @('DC-FOOTHOLD') -Role $Role | Out-Null
Import-Module ActiveDirectory

$dn = (Get-ADDomain).DistinguishedName
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'FootholdUsers'" -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name 'FootholdUsers' -Path $dn
}
$path = "OU=FootholdUsers,$dn"

function Ensure-LabUser {
    param([string]$Sam, [string]$Given, [string]$Sur, [string]$Password)
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$Sam'" -ErrorAction SilentlyContinue)) {
        New-ADUser -Name "$Given $Sur" -GivenName $Given -Surname $Sur -SamAccountName $Sam `
            -UserPrincipalName "$Sam@$($Lab.FootholdDomain)" `
            -AccountPassword (ConvertTo-LabSecureString $Password) `
            -Enabled $true -ChangePasswordAtLogon $false -PasswordNeverExpires $true `
            -Path $path
    }
}

Ensure-LabUser -Sam 'fuser' -Given 'Frank' -Sur 'User' -Password $Lab.FuserPassword
Ensure-LabUser -Sam 'fadmin' -Given 'Frank' -Sur 'Admin' -Password $Lab.FadminPassword
Add-ADGroupMember -Identity 'Domain Admins' -Members 'fadmin' -ErrorAction SilentlyContinue

Write-Host 'foothold.lab users created.'
Get-ADUser -Filter * -SearchBase $path | Select-Object SamAccountName, Enabled
