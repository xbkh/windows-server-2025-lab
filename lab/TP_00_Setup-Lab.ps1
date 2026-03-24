#Requires -RunAsAdministrator
<#
.SYNOPSIS
    TP Module 00 + 02 - Configuration post-installation & promotion DC
    Formation Windows Server 2025 - Administration Systeme

.DESCRIPTION
    Ce script automatise entierement la configuration post-installation
    et la promotion du premier controleur de domaine (DC01).

    ORDRE D'EXECUTION :
        1. Executer ce script sur DC01 (WS2025 fraichement installe)
        2. Le serveur redemarre automatiquement apres la promotion AD
        3. Poursuivre avec TP_01_DHCP-DNS-Client.ps1

.PARAMETER DomainName
    Nom FQDN du domaine (ex: satom.local)
    
.PARAMETER ServerName
    Nom du serveur (ex: DC01)

.PARAMETER InterfaceAlias
    Alias de l'interface reseau (ex: Ethernet0)

.PARAMETER StaticIP
    Adresse IP statique du DC (ex: 192.168.100.10)

.EXAMPLE
    .\TP_00_Setup-Lab.ps1 -DomainName "satom.local" -ServerName "DC01" `
        -InterfaceAlias "Ethernet0" -StaticIP "192.168.100.10"
#>

[CmdletBinding()]
param(
    [string]$DomainName     = "satom.local",
    [string]$ServerName     = "DC01",
    [string]$InterfaceAlias = "Ethernet0",
    [string]$StaticIP       = "192.168.100.10",
    [string]$SubnetPrefix   = "24",         # /24 = 255.255.255.0
    [string]$Gateway        = "192.168.100.1",
    [string]$DSRMPassword   = "P@ssw0rd2025!"  # Mot de passe DSRM
)

#region --- Helpers -----------------------------------------------------------
function Write-Step {
    param([string]$Message)
    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] -> $Message" -ForegroundColor Cyan
}

function Write-OK   { param([string]$Msg) Write-Host "  [OK] $Msg" -ForegroundColor Green  }
function Write-Warn { param([string]$Msg) Write-Host "  [!] $Msg" -ForegroundColor Yellow }
function Write-Fail { param([string]$Msg) Write-Host "   $Msg" -ForegroundColor Red    }
#endregion

Write-Host @"
+==============================================================+
|   FORMATION WS2025 - TP 00/02 : Configuration initiale DC   |
|   Domaine : $DomainName  |  Serveur : $ServerName             
+==============================================================+
"@ -ForegroundColor Magenta

#region --- TAPE 1 : Renommer le serveur -------------------------------------
Write-Step "ETAPE 1 - Renommage du serveur -> $ServerName"

$current = $env:COMPUTERNAME
if ($current -ne $ServerName) {
    Rename-Computer -NewName $ServerName -Force
    Write-OK "Serveur renomme de '$current' -> '$ServerName' (effectif apres redemarrage)"
} else {
    Write-OK "Le serveur est deja nomme '$ServerName'"
}
#endregion

#region --- TAPE 2 : Adresse IP statique ------------------------------------
Write-Step "ETAPE 2 - Configuration IP statique ($StaticIP/$SubnetPrefix)"

# Supprimer adresses IP existantes sur l'interface
$currentIP = Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
if ($currentIP) {
    Remove-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
    Remove-NetRoute -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
    Write-OK "Ancienne configuration IP supprimee"
}

# Configurer l'IP statique
New-NetIPAddress -InterfaceAlias $InterfaceAlias `
                 -IPAddress $StaticIP `
                 -PrefixLength $SubnetPrefix `
                 -DefaultGateway $Gateway | Out-Null

# DNS pointant vers lui-mme (le serveur sera le DC/DNS)
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses "127.0.0.1","$StaticIP"

Write-OK "IP   : $StaticIP/$SubnetPrefix"
Write-OK "GW   : $Gateway"
Write-OK "DNS  : 127.0.0.1, $StaticIP"
#endregion

#region --- TAPE 3 : Politique de mot de passe ------------------------------
Write-Step "ETAPE 3 - Configuration politique de securite locale"

# Dsactiver IE Enhanced Security Configuration (ESC)
$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
$UserKey  = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0 -ErrorAction SilentlyContinue
Set-ItemProperty -Path $UserKey  -Name "IsInstalled" -Value 0 -ErrorAction SilentlyContinue
Write-OK "IE Enhanced Security Configuration desactivee"

# Activer RDP
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Write-OK "RDP active et regle pare-feu creee"

# Activer ICMP (ping)
Enable-NetFirewallRule -Name "FPS-ICMP4-ERQ-In" -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Allow ICMPv4" -Protocol ICMPv4 -IcmpType 8 `
    -Action Allow -Direction Inbound -ErrorAction SilentlyContinue | Out-Null
Write-OK "Ping (ICMPv4) autorise dans le pare-feu"

# Dsactiver IPv6 (bonne pratique en labo)
Disable-NetAdapterBinding -Name $InterfaceAlias -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
Write-OK "IPv6 desactive sur $InterfaceAlias"

# Activer WinRM pour la gestion  distance
Enable-PSRemoting -Force -SkipNetworkProfileCheck | Out-Null
Write-OK "WinRM / PS Remoting active"
#endregion

#region --- TAPE 4 : Mises  jour Windows (optionnel) -----------------------
Write-Step "ETAPE 4 - Installation du module PSWindowsUpdate"

if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    try {
        Install-Module PSWindowsUpdate -Force -Confirm:$false | Out-Null
        Write-OK "Module PSWindowsUpdate installe"
    } catch {
        Write-Warn "Impossible d'installer PSWindowsUpdate : $($_.Exception.Message)"
    }
} else {
    Write-OK "Module PSWindowsUpdate deja present"
}
# Pour dclencher manuellement : Get-WindowsUpdate -AcceptAll -Install -AutoReboot
#endregion

#region --- TAPE 5 : Installation rle AD DS --------------------------------
Write-Step "ETAPE 5 - Installation du role AD DS + outils de gestion"

$feature = Get-WindowsFeature -Name AD-Domain-Services
if ($feature.InstallState -ne 'Installed') {
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -IncludeAllSubFeature
    Write-OK "Role AD DS installe"
} else {
    Write-OK "Role AD DS deja installe"
}

# Installer aussi les outils RSAT utiles
$rsatFeatures = @(
    "RSAT-AD-Tools",
    "RSAT-DNS-Server",
    "RSAT-DHCP",
    "GPMC"              # Group Policy Management Console
)
foreach ($f in $rsatFeatures) {
    $feat = Get-WindowsFeature -Name $f
    if ($feat.InstallState -ne 'Installed') {
        Install-WindowsFeature -Name $f -IncludeManagementTools | Out-Null
        Write-OK "Role/Outil '$f' installe"
    } else {
        Write-OK "'$f' deja installe"
    }
}
#endregion

#region --- TAPE 6 : Promotion Domain Controller --------------------------
Write-Step "ETAPE 6 - Promotion en controleur de domaine (nouvelle foret $DomainName)"

$securePassword = ConvertTo-SecureString $DSRMPassword -AsPlainText -Force

Import-Module ADDSDeployment

$params = @{
    CreateDnsDelegation           = $false
    DatabasePath                  = "C:\Windows\NTDS"
    DomainMode                    = "WinThreshold"      # Windows Server 2016+ (niveau fonctionnel)
    DomainName                    = $DomainName
    DomainNetbiosName             = ($DomainName.Split(".")[0]).ToUpper()
    ForestMode                    = "WinThreshold"
    InstallDns                    = $true
    LogPath                       = "C:\Windows\NTDS"
    NoRebootOnCompletion          = $false
    SysvolPath                    = "C:\Windows\SYSVOL"
    SafeModeAdministratorPassword = $securePassword
    Force                         = $true
}

Write-Warn "Le serveur va redemarrer automatiquement apres la promotion !"
Write-Warn "Apres le redemarrage, executez TP_01_DHCP-DNS-Client.ps1"

Install-ADDSForest @params
# Le serveur redmarre automatiquement ici
#endregion
