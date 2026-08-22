# Run on DC-PARTNER.
param([string]$Role)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"
Assert-LabRole -Allowed @('DC-PARTNER') -Role $Role | Out-Null
Import-Module ActiveDirectory

$dn = (Get-ADDomain).DistinguishedName
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'PartnerUsers'" -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name 'PartnerUsers' -Path $dn
}
$path = "OU=PartnerUsers,$dn"

function Ensure-LabUser {
    param([string]$Sam, [string]$Given, [string]$Sur, [string]$Password)
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$Sam'" -ErrorAction SilentlyContinue)) {
        New-ADUser -Name "$Given $Sur" -GivenName $Given -Surname $Sur -SamAccountName $Sam `
            -UserPrincipalName "$Sam@$($Lab.PartnerDomain)" `
            -AccountPassword (ConvertTo-LabSecureString $Password) `
            -Enabled $true -ChangePasswordAtLogon $false -PasswordNeverExpires $true `
            -Path $path
    }
}

Ensure-LabUser -Sam 'puser' -Given 'Pat' -Sur 'User' -Password $Lab.PuserPassword
Ensure-LabUser -Sam 'padmin' -Given 'Pat' -Sur 'Admin' -Password $Lab.PadminPassword
Add-ADGroupMember -Identity 'Domain Admins' -Members 'padmin' -ErrorAction SilentlyContinue

Write-Host 'partner.lab users created.'
Get-ADUser -Filter * -SearchBase $path | Select-Object SamAccountName, Enabled
