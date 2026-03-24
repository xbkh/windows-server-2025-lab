#Requires -RunAsAdministrator
<#
.SYNOPSIS
    TP Module 03 - Configuration DHCP, DNS et integration client
    Formation Windows Server 2025

.DESCRIPTION
    A executer APRES le redemarrage post-promotion AD (TP_00).
    Configure :
        - Serveur DHCP (etendue, options, autorisation dans AD)
        - DNS : zone de recherche inversee (PTR)
        - Jonction d'un poste client au domaine (si execute depuis le client)

.EXAMPLE
    # Sur DC01 aprs redmarrage :
    .\TP_01_DHCP-DNS-Client.ps1

    # Sur PC01 pour rejoindre le domaine :
    .\TP_01_DHCP-DNS-Client.ps1 -JoinDomain
#>

[CmdletBinding()]
param(
    [string]$DomainName       = "satom.local",
    [string]$DCName           = "DC01",
    [string]$DCIPAddress      = "192.168.100.10",

    # DHCP
    [string]$DHCPScopeName    = "LAN-Principal",
    [string]$ScopeStart       = "192.168.100.50",
    [string]$ScopeEnd         = "192.168.100.200",
    [string]$SubnetMask       = "255.255.255.0",
    [string]$ScopeGateway     = "192.168.100.1",
    [int]   $LeaseDays        = 8,

    # DNS reverse zone
    [string]$ReverseZone      = "100.168.192.in-addr.arpa",   # reseau 192.168.100.0/24

    # Client
    [switch]$JoinDomain
)

#region --- Helpers -----------------------------------------------------------
function Write-Step { param([string]$M) Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] -> $M" -ForegroundColor Cyan }
function Write-OK   { param([string]$M) Write-Host "  [OK] $M" -ForegroundColor Green  }
function Write-Warn { param([string]$M) Write-Host "  [!] $M" -ForegroundColor Yellow }
#endregion

Write-Host @"
+=======================================================+
|   FORMATION WS2025 - TP 03 : DHCP / DNS / Client     |
+=======================================================+
"@ -ForegroundColor Magenta

#region --- MODE CLIENT : Jonction au domaine ---------------------------------
if ($JoinDomain) {
    Write-Step "MODE CLIENT - Jonction au domaine $DomainName"

    # Configurer le DNS du client pour pointer vers le DC
    $iface = (Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object -First 1).Name
    Set-DnsClientServerAddress -InterfaceAlias $iface -ServerAddresses $DCIPAddress
    Write-OK "DNS client -> $DCIPAddress"

    # Demander les credentials de Admin du domaine
    $cred = Get-Credential -Message "Entrez les credentials de l'administrateur du domaine $DomainName"

    Add-Computer -DomainName $DomainName -Credential $cred -Restart -Force
    Write-OK "Jonction au domaine $DomainName - redemarrage en cours..."
    return
}
#endregion

#region --- MODE SERVEUR ------------------------------------------------------

# -- VRIFICATION AD ----------------------------------------------------------
Write-Step "Verification de la disponibilite d'Active Directory"
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $domain = Get-ADDomain -ErrorAction Stop
    Write-OK "Connecte au domaine : $($domain.DNSRoot)"
} catch {
    Write-Host "   AD DS non disponible. Attendez la fin de la promotion ou executez TP_00 d'abord." -ForegroundColor Red
    exit 1
}

#region --- TAPE 1 : Installation DHCP --------------------------------------
Write-Step "ETAPE 1 - Installation du role DHCP Server"

$dhcpFeature = Get-WindowsFeature -Name DHCP
if ($dhcpFeature.InstallState -ne 'Installed') {
    Install-WindowsFeature -Name DHCP -IncludeManagementTools
    Write-OK "Role DHCP installe"
} else {
    Write-OK "Role DHCP deja installe"
}

# Autoriser le serveur DHCP dans Active Directory
$server = "$DCName.$DomainName"
try {
    Add-DhcpServerInDC -DnsName $server -IPAddress $DCIPAddress
    Write-OK "Serveur DHCP autorise dans AD : $server ($DCIPAddress)"
} catch {
    Write-Warn "Deja autorise ou erreur : $($_.Exception.Message)"
}

# Supprimer la notification de configuration incomplte
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12" `
                 -Name "ConfigurationState" -Value 2 -ErrorAction SilentlyContinue
#endregion

#region --- TAPE 2 : Cration de l'tendue DHCP -----------------------------
Write-Step "ETAPE 2 - Configuration de l'etendue DHCP"

$scopeID = "192.168.100.0"

$existingScope = Get-DhcpServerv4Scope -ScopeId $scopeID -ErrorAction SilentlyContinue
if (-not $existingScope) {
    Add-DhcpServerv4Scope -Name $DHCPScopeName `
                          -StartRange $ScopeStart `
                          -EndRange   $ScopeEnd `
                          -SubnetMask $SubnetMask `
                          -LeaseDuration (New-TimeSpan -Days $LeaseDays) `
                          -State Active
    Write-OK "Etendue creee : $ScopeStart -> $ScopeEnd (bail: $LeaseDays jours)"
} else {
    Write-OK "Etendue $scopeID deja existante"
}

# Exclusions (plage serveurs & quipements fixes)
try {
    Add-DhcpServerv4ExclusionRange -ScopeId $scopeID `
                                   -StartRange "192.168.100.1" `
                                   -EndRange   "192.168.100.49"
    Write-OK "Exclusion ajoutee : 192.168.100.1 -> 192.168.100.49 (reserve serveurs)"
} catch {
    Write-Warn "Exclusion deja existante ou erreur : $($_.Exception.Message)"
}

# Options de l'tendue
Set-DhcpServerv4OptionValue -ScopeId $scopeID `
    -OptionId 3  -Value $ScopeGateway    # Passerelle par defaut
Set-DhcpServerv4OptionValue -ScopeId $scopeID `
    -OptionId 6  -Value $DCIPAddress    # Serveurs DNS
Set-DhcpServerv4OptionValue -ScopeId $scopeID `
    -OptionId 15 -Value $DomainName     # Nom de domaine DNS

Write-OK "Options DHCP configurees (GW=$ScopeGateway, DNS=$DCIPAddress, Domain=$DomainName)"

# Exemple rservation fixe (imprimante)
# Add-DhcpServerv4Reservation -ScopeId $scopeID -IPAddress "192.168.100.30" `
#     -ClientId "00-11-22-33-44-55" -Description "Imprimante HP-Bureau"

# Activer le service DHCP
Restart-Service -Name DHCPServer -Force
Set-Service   -Name DHCPServer -StartupType Automatic
Write-OK "Service DHCP demarre (demarrage automatique)"
#endregion

#region --- TAPE 3 : DNS  Zone de recherche inverse -----------------------
Write-Step "ETAPE 3 - Configuration DNS (zone inversee & PTR)"

Import-Module DnsServer

# Crer zone de recherche inverse (Reverse Lookup Zone)
$existingRevZone = Get-DnsServerZone -Name $ReverseZone -ErrorAction SilentlyContinue
if (-not $existingRevZone) {
    Add-DnsServerPrimaryZone -NetworkId "192.168.100.0/24" `
                             -ReplicationScope "Domain" `
                             -DynamicUpdate "Secure"
    Write-OK "Zone inversee creee : $ReverseZone"
} else {
    Write-OK "Zone inversee deja presente : $ReverseZone"
}

# Ajouter enregistrement PTR pour le DC
try {
    Add-DnsServerResourceRecordPtr -ZoneName $ReverseZone `
                                   -Name "10" `
                                   -PtrDomainName "$DCName.$DomainName."
    Write-OK "Enregistrement PTR cree : 10 -> $DCName.$DomainName"
} catch {
    Write-Warn "PTR deja existant ou erreur : $($_.Exception.Message)"
}

# Configurer le transfert DNS (forwarders) vers Google/Cloudflare pour la rsolution Internet
Set-DnsServerForwarder -IPAddress "8.8.8.8","1.1.1.1" -UseRootHint $false
Write-OK "Forwarders DNS configures : 8.8.8.8, 1.1.1.1"

# Activer le nettoyage automatique des enregistrements DNS obsoltes
Set-DnsServerScavenging -ScavengingState $true -RefreshInterval (New-TimeSpan -Days 7) `
                        -NoRefreshInterval (New-TimeSpan -Days 7) -ApplyOnAllZones
Write-OK "Nettoyage DNS (Scavenging) active"
#endregion

#region --- TAPE 4 : Tests de validation ------------------------------------
Write-Step "ETAPE 4 - Validation DNS & DHCP"

Write-Host "`n  -- Tests DNS --" -ForegroundColor White
$tests = @(
    @{Name="$DCName.$DomainName"; Expected=$DCIPAddress},
    @{Name=$DomainName;           Expected=$DCIPAddress}
)
foreach ($test in $tests) {
    try {
        $result = Resolve-DnsName -Name $test.Name -Server $DCIPAddress -Type A -ErrorAction Stop
        if ($result.IPAddress -contains $test.Expected) {
            Write-OK "$($test.Name) -> $($result.IPAddress -join ', ')"
        } else {
            Write-Warn "$($test.Name) resolu mais IP inattendue : $($result.IPAddress -join ', ')"
        }
    } catch {
        Write-Host "   Resolution echouee pour $($test.Name)" -ForegroundColor Red
    }
}

Write-Host "`n  -- Statistiques DHCP --" -ForegroundColor White
$stats = Get-DhcpServerv4ScopeStatistics -ScopeId $scopeID -ErrorAction SilentlyContinue
if ($stats) {
    Write-OK "Adresses disponibles : $($stats.Free)"
    Write-OK "Adresses utilisees   : $($stats.InUse)"
}

Write-Host "`n  -- SRV Records AD --" -ForegroundColor White
try {
    $srv = Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$DomainName" -Type SRV -Server $DCIPAddress
    Write-OK "Enregistrement SRV LDAP trouve : $($srv.NameTarget)"
} catch {
    Write-Warn "Enregistrement SRV non trouve (normal si AD vient d'etre installe)"
}
#endregion

#region --- RCAPITULATIF ----------------------------------------------------
Write-Host @"

+========================================================+
|  [OK]  CONFIGURATION DHCP/DNS TERMINEE                   |
+========================================================+
|  Domaine     : $DomainName                             
|  DC / DNS    : $DCName ($DCIPAddress)                  
|  DHCP        : $ScopeStart -> $ScopeEnd                 
|  Zone inverse: $ReverseZone                            
+========================================================+
|  ETAPE SUIVANTE : Jonction PC01 au domaine            |
|  Sur PC01, executer :                                 |
|    .\TP_01_DHCP-DNS-Client.ps1 -JoinDomain            |
+========================================================+
"@ -ForegroundColor Green
#endregion
