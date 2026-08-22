# Run on CA-CORP only after domain join. Enterprise CA, default templates.
# Must run as CORP\Administrator (Enterprise Admins), not local .\Administrator.
param([string]$Role)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"
Assert-LabRole -Allowed @('CA-CORP') -Role $Role | Out-Null

$cs = Get-CimInstance Win32_ComputerSystem
if ($cs.DomainRole -ge 4) {
    throw 'Do not install AD CS on a domain controller. Use CA-CORP.'
}
if ($cs.PartOfDomain -eq $false) {
    throw 'Join CA-CORP to corp.lab first (10-join-domain.ps1).'
}

$whoami = whoami
if ($whoami -notmatch '\\') {
    throw @"
Logged on as local account '$whoami'.
Enterprise CA requires a domain account in Enterprise Admins (use CORP\Administrator / LabLocal!1).
Close PowerShell, open a new elevated window, and log on as CORP\Administrator before running this script.
"@
}

$groups = whoami /groups
if ($groups -notmatch 'Enterprise Admins|S-1-5-21-.*-519') {
    throw @"
Account '$whoami' is not in Enterprise Admins.
Use CORP\Administrator (forest install account) or another Enterprise Admin.
If certocm.log shows ENUM_ENTERPRISE_UNAVAIL_REASON_NO_INSTALL_RIGHTS, this is the cause.
"@
}

if (Get-Service CertSvc -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' }) {
    Write-Host 'CertSvc already running. CA may already be installed.'
    Get-WindowsFeature ADCS-Cert-Authority | Format-List Name, InstallState
    exit 0
}

Install-WindowsFeature AD-Certificate, ADCS-Cert-Authority -IncludeManagementTools

try {
    Install-AdcsCertificationAuthority `
        -CAType EnterpriseRootCA `
        -CACommonName 'corp-RootCA' `
        -HashAlgorithmName SHA256 `
        -KeyLength 2048 `
        -CryptoProviderName 'RSA#Microsoft Software Key Storage Provider' `
        -ValidityPeriod Years `
        -ValidityPeriodUnits 5 `
        -Force
} catch {
    Write-Host 'Install failed. Check C:\Windows\certocm.log for ENUM_ENTERPRISE_UNAVAIL_* reason codes.' -ForegroundColor Yellow
    throw
}

Install-WindowsFeature ADCS-Web-Enrollment -IncludeManagementTools
Install-AdcsWebEnrollment -Force -ErrorAction SilentlyContinue
Write-Host 'Enterprise CA installed with default templates. Restart recommended.'
