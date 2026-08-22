# Run on DC-PARTNER after 04 on DC-CORP.
param([string]$Role)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"
Assert-LabRole -Allowed @('DC-PARTNER') -Role $Role | Out-Null

$domain = (Get-ADDomain).DNSRoot
if ($domain -ne $Lab.PartnerDomain) {
    throw "Expected forest $($Lab.PartnerDomain), this forest is $domain"
}

if (-not (Get-DnsServerZone -Name $Lab.CorpDomain -ErrorAction SilentlyContinue)) {
    Add-DnsServerConditionalForwarderZone -Name $Lab.CorpDomain -MasterServers @($Lab.CorpDns1, $Lab.CorpDns2) -ReplicationScope Forest
}

Write-Host 'partner.lab forwards corp.lab. Verify: nslookup dc-corp.corp.lab'
nltest /domain_trusts
