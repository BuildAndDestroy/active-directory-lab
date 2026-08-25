# SRV-FOOTHOLD: join foothold.lab, deploy intentionally vulnerable IIS app.
# Prerequisite: DC-FOOTHOLD promoted and 14-domain-objects-foothold.ps1 run.
#
#   .\12-setup-foothold-web.ps1
# Reboots after domain join — run again to install the web app.
param(
    [string]$Role,
    [switch]$SkipPreflight
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-lab-config.ps1"

$name = Assert-LabRole -Allowed @('SRV-FOOTHOLD') -Role $Role
$hostinfo = Get-LabHost -Role $name
$siteRoot = 'C:\inetpub\wwwroot\foothold'
$siteName = 'FootholdWeb'

Set-LabStaticIp -Role $name

$part = Get-CimInstance Win32_ComputerSystem
if (-not $part.PartOfDomain) {
    if (-not $SkipPreflight) {
        Test-LabFootholdReachable
    }
    Write-Host "Joining $($Lab.FootholdDomain) via $($Lab.FootholdDc1) ..."
    Add-Computer -DomainName $Lab.FootholdDomain -Server $Lab.FootholdDc1 `
        -Credential (Get-FootholdDaCredential) -Force
    Write-Host 'Rebooting — run 12-setup-foothold-web.ps1 again after login.'
    Restart-Computer -Force
    exit 0
}

if (-not (Get-WindowsFeature Web-Server).Installed) {
    Write-Host 'Installing IIS and ASP.NET ...'
    Install-WindowsFeature Web-Server, Web-Asp-Net45 -IncludeManagementTools | Out-Null
}

New-Item -ItemType Directory -Path $siteRoot -Force | Out-Null

$aspx = @'
<%@ Page Language="C#" ValidateRequest="false" %>
<script runat="server">
// Lab-only: deliberate OS command injection via unsanitized ping parameter.
void Page_Load(object sender, EventArgs e) {
    string host = Request.QueryString["host"];
    if (string.IsNullOrWhiteSpace(host)) { host = "127.0.0.1"; }
    litOut.Text = Server.HtmlEncode(RunPing(host));
}
string RunPing(string host) {
    var psi = new System.Diagnostics.ProcessStartInfo("cmd.exe", "/c ping -n 2 " + host);
    psi.RedirectStandardOutput = true;
    psi.RedirectStandardError = true;
    psi.UseShellExecute = false;
    psi.CreateNoWindow = true;
    using (var p = System.Diagnostics.Process.Start(psi)) {
        string stdout = p.StandardOutput.ReadToEnd();
        string stderr = p.StandardError.ReadToEnd();
        p.WaitForExit();
        return stdout + stderr;
    }
}
</script>
<!DOCTYPE html>
<html><head><title>Foothold portal ping (lab)</title></head>
<body>
<h1>Foothold network diagnostics</h1>
<p>Isolated study lab only — intentional command injection for practice.</p>
<form method="get">
  Host: <input name="host" value="127.0.0.1" size="40" />
  <input type="submit" value="Ping" />
</form>
<pre><asp:Literal runat="server" ID="litOut" /></pre>
</body></html>
'@

Set-Content -Path (Join-Path $siteRoot 'default.aspx') -Value $aspx -Encoding UTF8

Import-Module WebAdministration
if (-not (Get-Website -Name $siteName -ErrorAction SilentlyContinue)) {
    New-Website -Name $siteName -Port 80 -PhysicalPath $siteRoot -Force | Out-Null
} else {
    Set-ItemProperty "IIS:\Sites\$siteName" -Name physicalPath -Value $siteRoot
}

New-NetFirewallRule -DisplayName 'Lab Foothold HTTP' -Direction Inbound -Protocol TCP `
    -LocalPort 80 -Action Allow -ErrorAction SilentlyContinue | Out-Null

Write-Host @"

SRV-FOOTHOLD ready:
  Host:     $($hostinfo.Address) (foothold.lab member)
  Domain:   $($Lab.FootholdDomain)
  Web app:  http://$($hostinfo.Address)/default.aspx?host=127.0.0.1
  Vuln:     unsanitized host= parameter (command injection — lab only)
"@
