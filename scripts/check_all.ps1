$ErrorActionPreference = 'SilentlyContinue'

Write-Host "`n=== DHCP ===" -ForegroundColor Cyan
$dhcp = Get-DhcpServerv4Failover
$scope = Get-DhcpServerv4Scope -ScopeId 192.168.122.0
$leases = (Get-DhcpServerv4Lease -ScopeId 192.168.122.0).Count
Write-Host "Failover : $($dhcp.Name) | Mode: $($dhcp.Mode) | State: $($dhcp.State)"
Write-Host "Scope    : $($scope.Name) | State: $($scope.State)"
Write-Host "Baux actifs : $leases"

Write-Host "`n=== AD SITES ===" -ForegroundColor Cyan
Get-ADReplicationSite -Filter * | Select-Object Name | ForEach-Object { Write-Host "  Site: $($_.Name)" }
$subnets = Get-ADReplicationSubnet -Filter * | Select-Object Name,Site
$subnets | ForEach-Object { Write-Host "  Subnet: $($_.Name) -> $($_.Site)" }

Write-Host "`n=== OUs ===" -ForegroundColor Cyan
Get-ADOrganizationalUnit -Filter * | Where-Object DistinguishedName -match '_SATOM' | Select-Object -ExpandProperty Name | ForEach-Object { Write-Host "  OU: $_" }

Write-Host "`n=== USERS AD ===" -ForegroundColor Cyan
$users = (Get-ADUser -Filter * -SearchBase "OU=_SATOM,DC=satom,DC=local").Count
Write-Host "Utilisateurs dans _SATOM : $users"

Write-Host "`n=== GPOs ===" -ForegroundColor Cyan
Get-GPO -All | Select-Object DisplayName,GpoStatus | ForEach-Object { Write-Host "  GPO: $($_.DisplayName) [$($_.GpoStatus)]" }

Write-Host "`n=== LAPS ===" -ForegroundColor Cyan
$laps = Get-LapsADPassword -Identity PC01 -AsPlainText
Write-Host "PC01 Account: $($laps.Account) | Expiry: $($laps.ExpirationTimestamp)"

Write-Host "`n=== HYPER-V ===" -ForegroundColor Cyan
$vmms = (Get-Service vmms).Status
Write-Host "Service vmms : $vmms"
Get-VMSwitch | ForEach-Object { Write-Host "  vSwitch: $($_.Name) [$($_.SwitchType)]" }
Get-VM | ForEach-Object { Write-Host "  VM: $($_.Name) | State: $($_.State) | Gen: $($_.Generation) | CPU: $($_.ProcessorCount)" }

Write-Host "`n=== SMB SECURITE ===" -ForegroundColor Cyan
$smb = Get-SmbServerConfiguration
Write-Host "SMBv1    : $($smb.EnableSMB1Protocol)  (doit etre False)"
Write-Host "Signing  : $($smb.RequireSecuritySignature)  (doit etre True)"
Write-Host "Encrypt  : $($smb.EncryptData)  (doit etre True)"

Write-Host "`n=== REGISTRE SECURITE ===" -ForegroundColor Cyan
$lm = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name LmCompatibilityLevel -ErrorAction SilentlyContinue).LmCompatibilityLevel
$wdigest = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' -Name UseLogonCredential -ErrorAction SilentlyContinue).UseLogonCredential
Write-Host "LmCompatibilityLevel : $lm  (doit etre 5)"
Write-Host "WDigest              : $wdigest  (doit etre 0)"

Write-Host "`n=== POLITIQUE MOT DE PASSE (PSO) ===" -ForegroundColor Cyan
Get-ADFineGrainedPasswordPolicy -Filter * | ForEach-Object {
    Write-Host "  PSO: $($_.Name) | MinLen: $($_.MinPasswordLength) | MaxAge: $($_.MaxPasswordAge.Days)j | Lockout: $($_.LockoutThreshold)"
}

Write-Host "`n=== TACHES PLANIFIEES ===" -ForegroundColor Cyan
Get-ScheduledTask | Where-Object TaskName -match 'Rapport|Monitoring' | ForEach-Object { Write-Host "  Task: $($_.TaskName) | State: $($_.State)" }

Write-Host "`n=== PLAN D'ALIMENTATION ===" -ForegroundColor Cyan
$plan = powercfg /getactivescheme
Write-Host $plan

Write-Host "`n=== DC01 ROLE ===" -ForegroundColor Cyan
netdom query fsmo | Select-String 'PDC|RID|Schema|Naming|Infrastructure'

Write-Host "`n=== PC01 DHCP ===" -ForegroundColor Cyan
$lease = Get-DhcpServerv4Lease -ScopeId 192.168.122.0 | Where-Object HostName -match 'PC01'
Write-Host "PC01 IP: $($lease.IPAddress) | State: $($lease.AddressState)"

Write-Host "`n=== PKI (M17) ===" -ForegroundColor Cyan
$adcs = Get-WindowsFeature ADCS-Cert-Authority -ErrorAction SilentlyContinue
$certSvc = Get-Service CertSvc -ErrorAction SilentlyContinue
$crl = Get-ChildItem "$env:SystemRoot\system32\CertSrv\CertEnroll\*.crl" -ErrorAction SilentlyContinue
$ldaps = Test-NetConnection -ComputerName localhost -Port 636 -WarningAction SilentlyContinue
$pkiGpo = Get-GPO -Name 'GPO-PKI-AutoEnrollement' -ErrorAction SilentlyContinue
$dcCert = Get-ChildItem Cert:\LocalMachine\My -ErrorAction SilentlyContinue | Where-Object { $_.EnhancedKeyUsageList.FriendlyName -contains 'Server Authentication' }
Write-Host "ADCS installe   : $($adcs.InstallState)  (doit etre Installed)"
Write-Host "Service CertSvc : $($certSvc.Status)  (doit etre Running)"
Write-Host "CRL publiee     : $(if($crl){$crl[0].Name}else{'ABSENT'})"
Write-Host "LDAPS port 636  : $($ldaps.TcpTestSucceeded)  (doit etre True)"
Write-Host "GPO AutoEnroll  : $(if($pkiGpo){'Presente'}else{'ABSENTE'})"
Write-Host "Cert DC (SAN)   : $(if($dcCert){'Installe (' + $dcCert.Count + ')'}else{'ABSENT'})"

Write-Host "`n=== FILE SERVER (M18) ===" -ForegroundColor Cyan
$fsRole     = Get-WindowsFeature FS-FileServer -ErrorAction SilentlyContinue
$dfsRole    = Get-WindowsFeature FS-DFS-Namespace -ErrorAction SilentlyContinue
$fsrmRole   = Get-WindowsFeature FS-Resource-Manager -ErrorAction SilentlyContinue
$smbShares  = Get-SmbShare | Where-Object { $_.Name -in @('Commun','Paris','Bordeaux','Direction','IT','Software') }
$dfsRoot    = Get-DfsnRoot -Path "\\satom.local\data" -ErrorAction SilentlyContinue
$dfsLinks   = Get-DfsnFolder -Path "\\satom.local\data\*" -ErrorAction SilentlyContinue
$abeShare   = Get-SmbShare -Name 'Commun' -ErrorAction SilentlyContinue
$fsrmGroup  = Get-FsrmFileGroup -Name 'Executables-Bloques' -ErrorAction SilentlyContinue
$fsrmTmpl   = Get-FsrmFileScreenTemplate -Name 'Bloquer-Executables' -ErrorAction SilentlyContinue
$quotaCount = (Get-FsrmQuota -ErrorAction SilentlyContinue).Count
$gpoLecteur = Get-GPO -Name 'GPO-Lecteurs-Reseau' -ErrorAction SilentlyContinue
Write-Host "FS-FileServer   : $($fsRole.InstallState)"
Write-Host "DFS-Namespace   : $($dfsRole.InstallState)"
Write-Host "FSRM            : $($fsrmRole.InstallState)"
Write-Host "Partages SMB    : $($smbShares.Count)/6 (Commun/Paris/Bordeaux/Direction/IT/Software)"
Write-Host "ABE sur Commun  : $($abeShare.FolderEnumerationMode)  (doit etre AccessBased)"
Write-Host "Namespace DFS   : $(if($dfsRoot){'\\satom.local\data PRESENT'}else{'ABSENT'})"
Write-Host "Liens DFS       : $($dfsLinks.Count)  (attendu 6)"
Write-Host "Groupe FSRM     : $(if($fsrmGroup){'Executables-Bloques PRESENT'}else{'ABSENT'})"
Write-Host "Filtre FSRM     : $(if($fsrmTmpl){'Bloquer-Executables PRESENT'}else{'ABSENT'})"
Write-Host "Quotas actifs   : $quotaCount"
Write-Host "GPO Lecteurs    : $(if($gpoLecteur){'GPO-Lecteurs-Reseau PRESENTE'}else{'ABSENTE'})"

Write-Host "`n=== NPS/RADIUS (M19) ===" -ForegroundColor Cyan
$npsRole    = Get-WindowsFeature NPAS -ErrorAction SilentlyContinue
$iasService = Get-Service IAS -ErrorAction SilentlyContinue
$clients    = & netsh nps show client 2>&1 | Out-String
$cntClients = (@($clients -split "`n") | Where-Object { $_ -match 'Nom\s+=' -or $_ -match 'Name\s+=' }).Count
$fw1812     = Get-NetFirewallRule -DisplayName 'RADIUS-UDP-1812' -ErrorAction SilentlyContinue
$fw1813     = Get-NetFirewallRule -DisplayName 'RADIUS-UDP-1813' -ErrorAction SilentlyContinue
$npsGpo     = Get-GPO -Name 'GPO-NPS-RADIUS-Clients' -ErrorAction SilentlyContinue
$npsLog     = Test-Path 'C:\Windows\system32\LogFiles\NPS'
Write-Host "Role NPAS       : $($npsRole.InstallState)  (doit etre Installed)"
Write-Host "Service IAS     : $($iasService.Status)  (doit etre Running)"
Write-Host "Clients RADIUS  : $cntClients  (attendu 3)"
Write-Host "FW RADIUS-1812  : $(if($fw1812){'PRESENT'}else{'ABSENT'})"
Write-Host "FW RADIUS-1813  : $(if($fw1813){'PRESENT'}else{'ABSENT'})"
Write-Host "GPO NPS Clients : $(if($npsGpo){'GPO-NPS-RADIUS-Clients PRESENTE'}else{'ABSENTE'})"
Write-Host "Logs NPS        : $(if($npsLog){'PRESENT'}else{'ABSENT'})"

Write-Host "`n=== SECURITE OFFENSIVE CONTROLEE (M20) ===" -ForegroundColor Cyan
$repoRoot   = Split-Path $PSScriptRoot -Parent
$tp08       = Join-Path $repoRoot 'lab\TP_08_Securite-Offensive.ps1'
$offOu      = Get-ADOrganizationalUnit -LDAPFilter '(ou=OffensiveLab)' -ErrorAction SilentlyContinue
$offUsers   = Get-ADUser -Filter {SamAccountName -like "olab.*" -or SamAccountName -eq "svc-ol-web"} -Properties ServicePrincipalName,Enabled -ErrorAction SilentlyContinue
$offReports = Get-ChildItem 'C:\Formation\Reports\Offensive' -Filter 'offensive_detection_report_*.md' -ErrorAction SilentlyContinue
$offSource  = $false
try { $offSource = [System.Diagnostics.EventLog]::SourceExists('SATOM-OffensiveLab') } catch {}
Write-Host "Script TP08     : $(if(Test-Path $tp08){'PRESENT'}else{'ABSENT'})"
Write-Host "OU OffensiveLab : $(if($offOu){'PRESENTE'}else{'ABSENTE (non execute ou nettoyee)'})"
Write-Host "Comptes test    : $(@($offUsers).Count)"
Write-Host "Event source    : $(if($offSource){'SATOM-OffensiveLab PRESENTE'}else{'ABSENTE'})"
Write-Host "Rapports M20    : $(@($offReports).Count)"
