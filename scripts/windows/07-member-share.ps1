# Run on SRV-CORP after domain join.
param([string]$Role)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"
Assert-LabRole -Allowed @('SRV-CORP') -Role $Role | Out-Null

$root = 'C:\Shares\CorpData'
New-Item -ItemType Directory -Path $root -Force | Out-Null
if (-not (Get-SmbShare -Name 'Share' -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name 'Share' -Path $root -FullAccess 'Authenticated Users'
} else {
    Grant-SmbShareAccess -Name 'Share' -AccountName 'Authenticated Users' -AccessRight Full -Force
}
Write-Host "Share available as \\$env:COMPUTERNAME\Share"
Get-SmbShare Share | Format-List
