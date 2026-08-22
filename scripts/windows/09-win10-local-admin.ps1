# Run on WIN10-CORP after domain join.
param([string]$Role)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"
Assert-LabRole -Allowed @('WIN10-CORP') -Role $Role | Out-Null
Add-LocalGroupMember -Group 'Administrators' -Member "$($Lab.CorpNetbios)\jdoe" -ErrorAction SilentlyContinue
Get-LocalGroupMember Administrators
