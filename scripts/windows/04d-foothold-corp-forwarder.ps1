# Run on DC-FOOTHOLD after 04c on DC-CORP. Requires JUMP routing enabled (11c -Mode Enable).
param([string]$Role)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"
Assert-LabRole -Allowed @('DC-FOOTHOLD') -Role $Role | Out-Null

$domain = (Get-ADDomain).DNSRoot
if ($domain -ne $Lab.FootholdDomain) {
    throw "Expected forest $($Lab.FootholdDomain), this forest is $domain"
}

Add-LabTrustSetupRoute -Side Foothold

if (-not (Get-DnsServerZone -Name $Lab.CorpDomain -ErrorAction SilentlyContinue)) {
    Add-DnsServerConditionalForwarderZone -Name $Lab.CorpDomain `
        -MasterServers @($Lab.CorpDns1, $Lab.CorpDns2) -ReplicationScope Forest
}

Write-Host 'foothold.lab forwards corp.lab. Verify: nslookup dc-corp.corp.lab'
nltest /domain_trusts
