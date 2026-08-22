# Run on DC-CORP2 after promotion. Sets DNS to both corp DCs and checks replication.
param([string]$Role)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"
Assert-LabRole -Allowed @('DC-CORP2') -Role $Role | Out-Null
Set-LabStaticIp -Role 'DC-CORP2'
repadmin /replsummary
dcdiag /q
