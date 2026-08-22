# Static IPv4 from hostname, or -Role if the name is still wrong.
#   .\00-set-static-ip.ps1
#   .\00-set-static-ip.ps1 -Role DC-CORP
param(
    [string]$Role,
    [string]$Address,
    [string[]]$DnsServers
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"
Set-LabStaticIp -Role $Role -Address $Address -DnsServers $DnsServers
