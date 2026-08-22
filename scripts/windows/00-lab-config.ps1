# Shared lab inventory and defaults. Dot-source this from every Windows script.
$ErrorActionPreference = 'Stop'

$Lab = @{
    LocalAdminPassword = 'LabLocal!1'
    SafeModeCorp       = 'LabRestore!1'
    SafeModePartner    = 'LabRestore!1'
    CorpDomain         = 'corp.lab'
    CorpNetbios        = 'CORP'
    CorpDns1           = '192.168.57.10'
    CorpDns2           = '192.168.57.11'
    Gateway            = '192.168.57.1'
    PrefixLength       = 24
    PartnerDomain      = 'partner.lab'
    PartnerNetbios     = 'PARTNER'
    PartnerDns         = '192.168.57.20'
    JdoePassword       = 'Summer2020'
    HadminPassword     = 'Winter2020'
    SvcWebPassword     = 'Service123'
    PuserPassword      = 'Autumn2020'
    PadminPassword     = 'Spring2020'
}

$LabInventory = @{
    'DC-CORP'    = @{ Address = '192.168.57.10'; Dns = @('192.168.57.10'); Forest = 'Corp' }
    'DC-CORP2'   = @{ Address = '192.168.57.11'; Dns = @('192.168.57.10', '192.168.57.11'); Forest = 'Corp' }
    'DC-PARTNER' = @{ Address = '192.168.57.20'; Dns = @('192.168.57.20'); Forest = 'Partner' }
    'SRV-CORP'   = @{ Address = '192.168.57.30'; Dns = @('192.168.57.10', '192.168.57.11'); Forest = 'Corp' }
    'CA-CORP'    = @{ Address = '192.168.57.40'; Dns = @('192.168.57.10', '192.168.57.11'); Forest = 'Corp' }
    'WIN10-CORP' = @{ Address = '192.168.57.50'; Dns = @('192.168.57.10', '192.168.57.11'); Forest = 'Corp' }
}

$credsFile = Join-Path $PSScriptRoot '00-creds.ps1'
if (Test-Path $credsFile) {
    . $credsFile
}

function ConvertTo-LabSecureString {
    param([Parameter(Mandatory)][string]$Plain)
    ConvertTo-SecureString $Plain -AsPlainText -Force
}

function Get-LabLocalCredential {
    param([string]$User = 'Administrator')
    New-Object System.Management.Automation.PSCredential (
        $User,
        (ConvertTo-LabSecureString $Lab.LocalAdminPassword)
    )
}

function Get-CorpDaCredential {
    New-Object System.Management.Automation.PSCredential (
        "$($Lab.CorpNetbios)\Administrator",
        (ConvertTo-LabSecureString $Lab.LocalAdminPassword)
    )
}

function Get-PartnerDaCredential {
    New-Object System.Management.Automation.PSCredential (
        "$($Lab.PartnerNetbios)\Administrator",
        (ConvertTo-LabSecureString $Lab.LocalAdminPassword)
    )
}

function Get-LabRoleName {
    param([string]$Role)
    if ($Role) { return $Role.ToUpperInvariant() }
    return $env:COMPUTERNAME.ToUpperInvariant()
}

function Assert-LabRole {
    param(
        [Parameter(Mandatory)][string[]]$Allowed,
        [string]$Role
    )
    $name = Get-LabRoleName -Role $Role
    $ok = $false
    foreach ($a in $Allowed) {
        if ($name -eq $a.ToUpperInvariant()) { $ok = $true }
    }
    if (-not $ok) {
        throw "Run this on $($Allowed -join ' or '). This host is '$name'. Use -Role if the computer name is wrong."
    }
    return $name
}

function Get-LabHost {
    param([string]$Role)
    $name = Get-LabRoleName -Role $Role
    if (-not $LabInventory.ContainsKey($name)) {
        throw "Unknown lab host '$name'. Valid: $($LabInventory.Keys -join ', ')"
    }
    return $LabInventory[$name]
}

function Get-LabUpAdapter {
    $if = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.Virtual -eq $false } | Select-Object -First 1
    if (-not $if) {
        $if = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
    }
    if (-not $if) { throw 'No connected adapter found' }
    return $if
}

function Set-LabStaticIp {
    param(
        [string]$Role,
        [string]$Address,
        [string[]]$DnsServers,
        [string]$Gateway,
        [int]$PrefixLength
    )
    if (-not $Gateway) { $Gateway = $Lab.Gateway }
    if (-not $PrefixLength) { $PrefixLength = $Lab.PrefixLength }
    if (-not $Address) {
        $h = Get-LabHost -Role $Role
        $Address = $h.Address
        if (-not $DnsServers) { $DnsServers = $h.Dns }
    }

    $if = Get-LabUpAdapter
    Write-Host "Adapter $($if.Name) -> $Address/$PrefixLength gw $Gateway dns $($DnsServers -join ',')"

    Set-NetIPInterface -InterfaceIndex $if.ifIndex -Dhcp Disabled -ErrorAction SilentlyContinue
    Set-DnsClientServerAddress -InterfaceIndex $if.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue
    Get-NetIPAddress -InterfaceIndex $if.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -ne '127.0.0.1' } |
        Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
    Get-NetRoute -InterfaceIndex $if.ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
    New-NetIPAddress -InterfaceIndex $if.ifIndex -IPAddress $Address -PrefixLength $PrefixLength -DefaultGateway $Gateway | Out-Null
    if ($DnsServers) {
        Set-DnsClientServerAddress -InterfaceIndex $if.ifIndex -ServerAddresses $DnsServers
    }
    Get-NetIPConfiguration -InterfaceIndex $if.ifIndex
}
