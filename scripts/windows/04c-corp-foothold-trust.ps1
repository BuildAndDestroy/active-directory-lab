# Run on DC-CORP after foothold.lab exists. Requires JUMP routing enabled (11c -Mode Enable).
param([string]$Role)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"
Assert-LabRole -Allowed @('DC-CORP') -Role $Role | Out-Null

$domain = (Get-ADDomain).DNSRoot
if ($domain -ne $Lab.CorpDomain) {
    throw "Expected forest $($Lab.CorpDomain), this forest is $domain"
}

Add-LabTrustSetupRoute -Side Corp

if (-not (Get-DnsServerZone -Name $Lab.FootholdDomain -ErrorAction SilentlyContinue)) {
    Add-DnsServerConditionalForwarderZone -Name $Lab.FootholdDomain `
        -MasterServers $Lab.FootholdDns -ReplicationScope Forest
}

$existing = Get-ADTrust -Filter "Name -eq '$($Lab.FootholdDomain)'" -ErrorAction SilentlyContinue
if (-not $existing) {
    netdom trust $Lab.CorpDomain /d:$($Lab.FootholdDomain) /add /twoway /forest `
        /userD:$($Lab.FootholdNetbios)\Administrator /passwordD:$($Lab.LocalAdminPassword) `
        /userO:$($Lab.CorpNetbios)\Administrator /passwordO:$($Lab.LocalAdminPassword)
}

Write-Host 'corp.lab forwarder and trust to foothold.lab attempted. On DC-FOOTHOLD run 04d-foothold-corp-forwarder.ps1'
Get-DnsServerZone | Format-Table Name, ZoneType
nltest /domain_trusts
