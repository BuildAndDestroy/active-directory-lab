# Run on DC-CORP after both forests exist.
param([string]$Role)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"
Assert-LabRole -Allowed @('DC-CORP') -Role $Role | Out-Null

$domain = (Get-ADDomain).DNSRoot
if ($domain -ne $Lab.CorpDomain) {
    throw "Expected forest $($Lab.CorpDomain), this forest is $domain"
}

if (-not (Get-DnsServerZone -Name $Lab.PartnerDomain -ErrorAction SilentlyContinue)) {
    Add-DnsServerConditionalForwarderZone -Name $Lab.PartnerDomain -MasterServers $Lab.PartnerDns -ReplicationScope Forest
}

$existing = Get-ADTrust -Filter "Name -eq '$($Lab.PartnerDomain)'" -ErrorAction SilentlyContinue
if (-not $existing) {
    netdom trust $Lab.CorpDomain /d:$($Lab.PartnerDomain) /add /twoway /forest `
        /userD:$($Lab.PartnerNetbios)\Administrator /passwordD:$($Lab.LocalAdminPassword) `
        /userO:$($Lab.CorpNetbios)\Administrator /passwordO:$($Lab.LocalAdminPassword)
}

Write-Host 'corp.lab forwarder and trust attempted. On DC-PARTNER run 04b-partner-forwarder.ps1'
Get-DnsServerZone | Format-Table Name, ZoneType
nltest /domain_trusts
