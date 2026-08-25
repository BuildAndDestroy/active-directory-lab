# Shared lab inventory and defaults. Dot-source this from every Windows script.
$ErrorActionPreference = 'Stop'

$Lab = @{
    LocalAdminPassword = 'LabLocal!1'
    SafeModeCorp       = 'LabRestore!1'
    SafeModePartner    = 'LabRestore!1'
    SafeModeFoothold   = 'LabRestore!1'
    CorpDomain         = 'corp.lab'
    CorpNetbios        = 'CORP'
    CorpDns1           = '192.168.57.10'
    CorpDns2           = '192.168.57.11'
    CorpDc1            = 'dc-corp.corp.lab'
    CorpDc2            = 'dc-corp2.corp.lab'
    FootholdDomain     = 'foothold.lab'
    FootholdNetbios    = 'FOOTHOLD'
    FootholdDns        = '192.168.58.15'
    FootholdDc1        = 'dc-foothold.foothold.lab'
    Gateway            = '192.168.57.1'
    FootholdGateway    = '192.168.58.1'
    PrefixLength       = 24
    PartnerDomain      = 'partner.lab'
    PartnerNetbios     = 'PARTNER'
    PartnerDns         = '192.168.57.20'
    JumpMacCorp        = '52:54:00:57:00:60'
    JumpMacFoothold    = '52:54:00:58:00:10'
    JumpCorpIp         = '192.168.57.60'
    JumpFootholdIp     = '192.168.58.10'
    JdoePassword       = 'Summer2020'
    HadminPassword     = 'Winter2020'
    SvcWebPassword     = 'Service123'
    PuserPassword      = 'Autumn2020'
    PadminPassword     = 'Spring2020'
    FuserPassword      = 'Fall2020'
    FadminPassword     = 'Spring2021'
    # Slow lab DC / first boot after host reboot can take a while to answer LDAP/DNS.
    PreflightTcpTimeoutSec = 120
    PreflightDnsTimeoutSec = 60
    PreflightRetries       = 3
}

$LabInventory = @{
    'DC-CORP'    = @{ Address = '192.168.57.10'; Dns = @('192.168.57.10'); Forest = 'Corp' }
    'DC-CORP2'   = @{ Address = '192.168.57.11'; Dns = @('192.168.57.10', '192.168.57.11'); Forest = 'Corp' }
    'DC-PARTNER' = @{ Address = '192.168.57.20'; Dns = @('192.168.57.20'); Forest = 'Partner' }
    'SRV-CORP'   = @{ Address = '192.168.57.30'; Dns = @('192.168.57.10', '192.168.57.11'); Forest = 'Corp' }
    'CA-CORP'    = @{ Address = '192.168.57.40'; Dns = @('192.168.57.10', '192.168.57.11'); Forest = 'Corp' }
    'WIN10-CORP' = @{ Address = '192.168.57.50'; Dns = @('192.168.57.10', '192.168.57.11'); Forest = 'Corp' }
    'JUMP-CORP'  = @{
        Address          = '192.168.57.60'
        FootholdAddress  = '192.168.58.10'
        FootholdDns      = @('192.168.58.15')
        Forest           = 'Foothold'
        DualHomed        = $true
    }
    'DC-FOOTHOLD' = @{
        Address      = '192.168.58.15'
        Dns          = @('192.168.58.15')
        Forest       = 'Foothold'
        FootholdOnly = $true
    }
    'SRV-FOOTHOLD' = @{
        Address      = '192.168.58.20'
        Dns          = @('192.168.58.15')
        Forest       = 'Foothold'
        FootholdOnly = $true
    }
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

function Get-FootholdDaCredential {
    New-Object System.Management.Automation.PSCredential (
        "$($Lab.FootholdNetbios)\Administrator",
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

function Get-LabAdapterByMac {
    param([Parameter(Mandatory)][string]$Mac)
    $want = ($Mac -replace '[-:]', '').ToUpperInvariant()
    $if = Get-NetAdapter | Where-Object {
        (($_.MacAddress -replace '[-:]', '').ToUpperInvariant()) -eq $want
    } | Select-Object -First 1
    if (-not $if) {
        Write-Host 'Adapters on this host:'
        Get-NetAdapter | Format-Table Name, Status, MacAddress, InterfaceDescription -AutoSize
        throw "No adapter with MAC $Mac. Check virt-install MAC order (corp first, foothold second) and that both NIC drivers are installed."
    }
    if ($if.Status -ne 'Up') {
        Write-Host "Enabling adapter $($if.Name) ($($if.MacAddress))..."
        Enable-NetAdapter -Name $if.Name -Confirm:$false
        Start-Sleep -Seconds 2
        $if = Get-NetAdapter -Name $if.Name
    }
    return $if
}

function Show-LabJumpAdapters {
    Write-Host "JUMP network adapters (expect corp MAC $($Lab.JumpMacCorp) and foothold $($Lab.JumpMacFoothold)):"
    Get-NetAdapter | Where-Object { $_.Virtual -eq $false } |
        Format-Table Name, Status, MacAddress, LinkSpeed, InterfaceDescription -AutoSize
}

function Set-LabAdapterStaticIp {
    param(
        [Parameter(Mandatory)]$Adapter,
        [Parameter(Mandatory)][string]$Address,
        [string[]]$DnsServers,
        [string]$Gateway,
        [int]$PrefixLength = 24,
        [switch]$NoGateway
    )
    $idx = $Adapter.ifIndex
    Write-Host "Adapter $($Adapter.Name) ($($Adapter.MacAddress)) -> $Address/$PrefixLength$(if ($NoGateway -or -not $Gateway) { ' (no default gw)' } else { " gw $Gateway" })"

    Set-NetIPInterface -InterfaceIndex $idx -Dhcp Disabled -ErrorAction SilentlyContinue
    Set-DnsClientServerAddress -InterfaceIndex $idx -ResetServerAddresses -ErrorAction SilentlyContinue
    Get-NetIPAddress -InterfaceIndex $idx -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -ne '127.0.0.1' } |
        Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
    Get-NetRoute -InterfaceIndex $idx -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue

    if ($NoGateway -or -not $Gateway) {
        New-NetIPAddress -InterfaceIndex $idx -IPAddress $Address -PrefixLength $PrefixLength | Out-Null
    } else {
        New-NetIPAddress -InterfaceIndex $idx -IPAddress $Address -PrefixLength $PrefixLength -DefaultGateway $Gateway | Out-Null
    }
    if ($DnsServers) {
        Set-DnsClientServerAddress -InterfaceIndex $idx -ServerAddresses $DnsServers
    }
    Get-NetIPConfiguration -InterfaceIndex $idx
}

function Disable-LabIpForwarding {
    # Keep JUMP as a pivot host, not a router — Kali must compromise/use the jump.
    Get-NetIPInterface -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        ForEach-Object {
            Set-NetIPInterface -InterfaceIndex $_.InterfaceIndex -Forwarding Disabled -ErrorAction SilentlyContinue
        }
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' `
        -Name 'IPEnableRouter' -Value 0 -Type DWord -Force
    Write-Host 'IP forwarding disabled on all interfaces (IPEnableRouter=0).'
}

function Enable-LabJumpSetupForwarding {
    # Temporary — forest trust setup between corp.lab and foothold.lab across JUMP.
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' `
        -Name 'IPEnableRouter' -Value 1 -Type DWord -Force
    Get-NetIPInterface -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        ForEach-Object {
            Set-NetIPInterface -InterfaceIndex $_.InterfaceIndex -Forwarding Enabled -ErrorAction SilentlyContinue
        }
    Write-Host 'IP forwarding ENABLED on JUMP (setup only — disable after forest trust).'
}

function Add-LabTrustSetupRoute {
    param([ValidateSet('Corp', 'Foothold')][Parameter(Mandatory)][string]$Side)
    if ($Side -eq 'Corp') {
        $localIp = $Lab.CorpDns1
        $remote = '192.168.58.0/24'
        $via = $Lab.JumpCorpIp
    } else {
        $localIp = $Lab.FootholdDns
        $remote = '192.168.57.0/24'
        $via = $Lab.JumpFootholdIp
    }
    $ifIdx = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -eq $localIp }).InterfaceIndex
    if (-not $ifIdx) { throw "No interface with $localIp for trust setup route." }
    if (-not (Get-NetRoute -DestinationPrefix $remote -ErrorAction SilentlyContinue)) {
        New-NetRoute -DestinationPrefix $remote -NextHop $via -InterfaceIndex $ifIdx | Out-Null
        Write-Host "Trust setup route: $remote via $via"
    }
}

function Set-LabDualHomedIp {
    param([string]$Role)
    $h = Get-LabHost -Role $Role
    if (-not $h.DualHomed) {
        throw "Host is not dual-homed in inventory."
    }
    Show-LabJumpAdapters
    $corpIf = Get-LabAdapterByMac -Mac $Lab.JumpMacCorp
    $fhIf = Get-LabAdapterByMac -Mac $Lab.JumpMacFoothold

    Set-LabAdapterStaticIp -Adapter $corpIf -Address $h.Address -DnsServers @() `
        -Gateway $Lab.Gateway -PrefixLength $Lab.PrefixLength
    # Foothold NIC: AD + DNS via local DC; no default gw (corp route is pivot-only).
    Set-LabAdapterStaticIp -Adapter $fhIf -Address $h.FootholdAddress -DnsServers $h.FootholdDns `
        -PrefixLength $Lab.PrefixLength -NoGateway

    # Prefer foothold forest for AD; corp NIC is L3 pivot path only.
    Set-NetIPInterface -InterfaceIndex $fhIf.ifIndex -InterfaceMetric 10
    Set-NetIPInterface -InterfaceIndex $corpIf.ifIndex -InterfaceMetric 200
    Set-DnsClient -InterfaceIndex $fhIf.ifIndex -RegisterThisConnectionsAddress $true -ErrorAction SilentlyContinue
    Set-DnsClient -InterfaceIndex $corpIf.ifIndex -RegisterThisConnectionsAddress $false -ErrorAction SilentlyContinue

    Disable-LabIpForwarding

    $corpIp = Get-NetIPAddress -InterfaceIndex $corpIf.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -eq $h.Address }
    if (-not $corpIp) {
        throw "Corp NIC $($corpIf.Name) does not have $($h.Address). Check adapter in Device Manager."
    }
    Write-Host "Corp NIC verified: $($h.Address) on $($corpIf.Name)"
}

function Test-LabTcpPort {
    param(
        [Parameter(Mandatory)][string]$ComputerName,
        [Parameter(Mandatory)][int]$Port,
        [int]$TimeoutSec = 120
    )
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $connect = $client.BeginConnect($ComputerName, $Port, $null, $null)
        if (-not $connect.AsyncWaitHandle.WaitOne([TimeSpan]::FromSeconds($TimeoutSec), $false)) {
            return $false
        }
        $client.EndConnect($connect)
        return $client.Connected
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Resolve-LabDnsName {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Server,
        [int]$TimeoutSec = 60
    )
    $job = Start-Job -ScriptBlock {
        param($QueryName, $QueryServer)
        Resolve-DnsName -Name $QueryName -Server $QueryServer -Type A -ErrorAction Stop
    } -ArgumentList $Name, $Server
    try {
        if (-not (Wait-Job -Job $job -Timeout $TimeoutSec)) {
            throw "DNS query timed out after ${TimeoutSec}s"
        }
        return Receive-Job -Job $job -ErrorAction Stop
    } finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}

function Test-LabFootholdReachable {
    param(
        [int]$TcpTimeoutSec,
        [int]$DnsTimeoutSec,
        [int]$Retries
    )
    if (-not $TcpTimeoutSec) { $TcpTimeoutSec = $Lab.PreflightTcpTimeoutSec }
    if (-not $DnsTimeoutSec) { $DnsTimeoutSec = $Lab.PreflightDnsTimeoutSec }
    if (-not $Retries) { $Retries = $Lab.PreflightRetries }

    $dc = $Lab.FootholdDns
    $ldapOk = $false
    for ($i = 1; $i -le $Retries; $i++) {
        Write-Host "Preflight attempt ${i}/${Retries}: LDAP ${dc}:389 (timeout ${TcpTimeoutSec}s) ..."
        if (Test-LabTcpPort -ComputerName $dc -Port 389 -TimeoutSec $TcpTimeoutSec) {
            $ldapOk = $true
            Write-Host 'LDAP OK.'
            break
        }
        if ($i -lt $Retries) {
            Write-Host 'LDAP not ready yet; waiting 10s before retry...'
            Start-Sleep -Seconds 10
        }
    }
    if (-not $ldapOk) {
        throw "Cannot reach DC LDAP at ${dc}:389. Is DC-FOOTHOLD up?"
    }

    Write-Host "Preflight: DNS $dc for $($Lab.FootholdDomain) (timeout ${DnsTimeoutSec}s) ..."
    try {
        $r = Resolve-LabDnsName -Name $Lab.FootholdDomain -Server $dc -TimeoutSec $DnsTimeoutSec
        Write-Host "DNS OK: $($Lab.FootholdDomain) -> $($r.IPAddress -join ', ')"
    } catch {
        throw "DNS to $dc failed for $($Lab.FootholdDomain): $_"
    }
}

function Test-LabCorpReachable {
    param(
        [int]$TcpTimeoutSec,
        [int]$DnsTimeoutSec,
        [int]$Retries
    )
    if (-not $TcpTimeoutSec) { $TcpTimeoutSec = $Lab.PreflightTcpTimeoutSec }
    if (-not $DnsTimeoutSec) { $DnsTimeoutSec = $Lab.PreflightDnsTimeoutSec }
    if (-not $Retries) { $Retries = $Lab.PreflightRetries }

    $dc = $Lab.CorpDns1
    $ldapOk = $false
    for ($i = 1; $i -le $Retries; $i++) {
        Write-Host "Preflight attempt ${i}/${Retries}: LDAP ${dc}:389 (timeout ${TcpTimeoutSec}s) ..."
        if (Test-LabTcpPort -ComputerName $dc -Port 389 -TimeoutSec $TcpTimeoutSec) {
            $ldapOk = $true
            Write-Host 'LDAP OK.'
            break
        }
        if ($i -lt $Retries) {
            Write-Host 'LDAP not ready yet; waiting 10s before retry...'
            Start-Sleep -Seconds 10
        }
    }
    if (-not $ldapOk) {
        throw "Cannot reach DC LDAP at ${dc}:389 after $Retries attempts (${TcpTimeoutSec}s each). Is DC-CORP up? Is JUMP eth0 on ad-lab (192.168.57.60)?"
    }

    Write-Host "Preflight: DNS $dc for $($Lab.CorpDomain) (timeout ${DnsTimeoutSec}s) ..."
    try {
        $r = Resolve-LabDnsName -Name $Lab.CorpDomain -Server $dc -TimeoutSec $DnsTimeoutSec
        Write-Host "DNS OK: $($Lab.CorpDomain) -> $($r.IPAddress -join ', ')"
    } catch {
        throw "DNS to $dc failed for $($Lab.CorpDomain): $_. Fix DC DNS / Windows Firewall on DC-CORP (allow DNS), then retry."
    }
}

function Set-LabStaticIp {
    param(
        [string]$Role,
        [string]$Address,
        [string[]]$DnsServers,
        [string]$Gateway,
        [int]$PrefixLength
    )
    $name = Get-LabRoleName -Role $Role
    $h = $null
    if ($LabInventory.ContainsKey($name)) {
        $h = $LabInventory[$name]
    }
    if ($h -and $h.DualHomed) {
        Set-LabDualHomedIp -Role $name
        return
    }

    if (-not $Gateway) {
        if ($h -and $h.FootholdOnly) {
            $Gateway = $Lab.FootholdGateway
        } else {
            $Gateway = $Lab.Gateway
        }
    }
    if (-not $PrefixLength) { $PrefixLength = $Lab.PrefixLength }
    if (-not $Address) {
        if (-not $h) { $h = Get-LabHost -Role $Role }
        $Address = $h.Address
        if (-not $DnsServers) { $DnsServers = $h.Dns }
    }

    $if = Get-LabUpAdapter
    if ($h -and $h.FootholdOnly) {
        Set-LabAdapterStaticIp -Adapter $if -Address $Address -DnsServers $DnsServers `
            -Gateway $Gateway -PrefixLength $PrefixLength
    } else {
        Set-LabAdapterStaticIp -Adapter $if -Address $Address -DnsServers $DnsServers `
            -Gateway $Gateway -PrefixLength $PrefixLength
    }
}
