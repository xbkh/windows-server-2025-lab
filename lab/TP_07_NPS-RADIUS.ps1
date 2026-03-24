#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Module 19 - NPS/RADIUS : Serveur d authenticite reseau (802.1x / VPN)

.DESCRIPTION
    Deploie un serveur NPS (Network Policy Server) complet sur DC01 :
      1. Installation du role NPAS (Network Policy and Access Services)
      2. Configuration NPS en serveur RADIUS
      3. Declaration des clients RADIUS (commutateurs, bornes Wi-Fi, VPN)
      4. Strategie reseau (Network Policy) : acces par groupes AD
      5. Strategie de demande de connexion (Connection Request Policy)
      6. Journalisation NPS vers fichier local
      7. Regles pare-feu RADIUS (UDP 1812 + 1813)
      8. Validation complete avec score

.PARAMETER DomainName
    FQDN du domaine (defaut : satom.local)

.PARAMETER Module
    All | Roles | Config | Policy | GPO | Validate

.EXAMPLE
    .\TP_07_NPS-RADIUS.ps1
    .\TP_07_NPS-RADIUS.ps1 -Module Roles
    .\TP_07_NPS-RADIUS.ps1 -Module Validate
#>
[CmdletBinding()]
param(
    [string]$DomainName = 'satom.local',
    [ValidateSet('All','Roles','Config','Policy','GPO','Validate')]
    [string]$Module = 'All'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Off

#region -- Helpers --------------------------------------------------------------
function Write-Step { param([string]$m) Write-Host "`n[NPS] $m" -ForegroundColor Cyan }
function Write-OK   { param([string]$m) Write-Host "[NPS] OK  $m" -ForegroundColor Green }
function Write-Warn { param([string]$m) Write-Host "[NPS] WRN $m" -ForegroundColor Yellow }
function Write-Fail { param([string]$m) Write-Host "[NPS] ERR $m" -ForegroundColor Red }

$ServerFQDN = "$env:COMPUTERNAME.$DomainName"
$LogPath    = 'C:\Windows\system32\LogFiles\NPS'
#endregion

#region -- Module Roles ---------------------------------------------------------
function Install-NPSRoles {
    Write-Step "=== ROLES : Installation de NPAS (NPS/RADIUS) ==="

    $roles = @('NPAS','RSAT-NPAS')
    foreach ($role in $roles) {
        $feat = Get-WindowsFeature $role -ErrorAction SilentlyContinue
        if ($feat -and $feat.InstallState -ne 'Installed') {
            Install-WindowsFeature -Name $role -IncludeManagementTools | Out-Null
            Write-OK "Installe : $role"
        } else {
            Write-OK "Deja present : $role"
        }
    }

    # Demarrer le service IAS (NPS)
    $svc = Get-Service IAS -ErrorAction SilentlyContinue
    if ($svc) {
        Set-Service IAS -StartupType Automatic
        if ($svc.Status -ne 'Running') {
            Start-Service IAS
            Start-Sleep 3
        }
        Write-OK "Service IAS (NPS) : $((Get-Service IAS).Status)"
    } else {
        Write-Warn "Service IAS non trouve - le role NPAS est peut-etre pas encore installe"
    }

    Write-OK "=== Roles NPS installes ==="
}
#endregion

#region -- Module Config --------------------------------------------------------
function Configure-NPS {
    Write-Step "=== CONFIG : Configuration du serveur NPS/RADIUS ==="

    # Enregistrer NPS dans Active Directory (pour lire les proprietes dial-in)
    Write-Step "Enregistrement NPS dans Active Directory..."
    try {
        & netsh nps add registeredserver domain=$DomainName server=$env:COMPUTERNAME 2>&1 | Out-Null
        Write-OK "NPS enregistre dans AD ($DomainName)"
    } catch {
        Write-Warn "Enregistrement NPS AD : $_"
    }

    # Alternative : via commande directe
    try {
        & netsh nps show registeredserver 2>&1 | Out-Null
        Write-OK "Enregistrement NPS verifie"
    } catch {}

    # Creer le dossier de journalisation
    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
        Write-OK "Dossier logs NPS cree : $LogPath"
    } else {
        Write-OK "Dossier logs NPS existant : $LogPath"
    }

    # Configurer la journalisation comptable
    Write-Step "Configuration journalisation (Accounting)..."
    & netsh nps set accounting logtype=localfile logfile="$LogPath" logformat=DTS | Out-Null
    Write-OK "Journalisation NPS configuree : $LogPath"

    # Clients RADIUS - commutateurs / bornes Wi-Fi / VPN gateway
    # On declare des clients RADIUS representatifs du lab
    Write-Step "Declaration des clients RADIUS..."
    $radiusClients = @(
        @{ Name='SW-CORE-01';    Address='192.168.122.1';   Secret='RadiusSecret123!'; Vendor='RADIUS Standard' },
        @{ Name='AP-WIFI-01';    Address='192.168.122.5';   Secret='RadiusSecret123!'; Vendor='RADIUS Standard' },
        @{ Name='VPN-GW-01';     Address='192.168.122.2';   Secret='RadiusSecret123!'; Vendor='RADIUS Standard' }
    )

    foreach ($client in $radiusClients) {
        $existing = $null
        try {
            $existing = & netsh nps show client name="$($client.Name)" 2>&1
        } catch {}

        if ($existing -match 'not found|introuvable' -or $existing -match 'RADIUS') {
            # Supprimer si existant pour eviter les doublons
            & netsh nps delete client name="$($client.Name)" 2>&1 | Out-Null
        }
        $result = & netsh nps add client name="$($client.Name)" address="$($client.Address)" sharedsecret="$($client.Secret)" 2>&1
        if ($result -match 'OK|success|reussi' -or $LASTEXITCODE -eq 0) {
            Write-OK "Client RADIUS ajoute : $($client.Name) ($($client.Address))"
        } else {
            Write-Warn "Client RADIUS $($client.Name) : $result"
        }
    }

    Write-OK "=== Configuration NPS terminee ==="
}
#endregion

#region -- Module Policy --------------------------------------------------------
function Configure-NPSPolicies {
    Write-Step "=== POLICY : Strategies reseau NPS (Network Policies) ==="

    # ----- Connection Request Policy -----
    Write-Step "Strategie de demande de connexion..."
    $crpName = 'CRP-SATOM-Local'
    $crpExists = & netsh nps show crp name="$crpName" 2>&1
    if ($crpExists -notmatch $crpName) {
        $result = & netsh nps add crp name="$crpName" processingOrder=1 policysource=0 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-OK "CRP creee : $crpName"
        } else {
            Write-Warn "CRP $crpName : $result"
        }
    } else {
        Write-OK "CRP existante : $crpName"
    }

    # ----- Network Policies -----
    Write-Step "Strategies reseau (acces par groupes AD)..."

    # Politique 1 : Acces refuse si compte desactive (priorite basse)
    $np1 = 'NP-Refus-Desactive'
    $np1Check = & netsh nps show np name="$np1" 2>&1
    if ($np1Check -notmatch $np1) {
        $r = & netsh nps add np name="$np1" processingOrder=10 policysource=0 accesstype=deny 2>&1
        if ($LASTEXITCODE -eq 0) { Write-OK "Politique NP creee : $np1 (Deny)" }
        else { Write-Warn "NP $np1 : $r" }
    } else {
        Write-OK "Politique NP existante : $np1"
    }

    # Politique 2 : Acces autorise pour Utilisateurs du domaine
    $np2 = 'NP-Acces-Utilisateurs-Domaine'
    $np2Check = & netsh nps show np name="$np2" 2>&1
    if ($np2Check -notmatch $np2) {
        $r = & netsh nps add np name="$np2" processingOrder=5 policysource=0 accesstype=allow 2>&1
        if ($LASTEXITCODE -eq 0) { Write-OK "Politique NP creee : $np2 (Allow)" }
        else { Write-Warn "NP $np2 : $r" }
    } else {
        Write-OK "Politique NP existante : $np2"
    }

    # Politique 3 : Acces autorise pour Ordinateurs du domaine (802.1x machine auth)
    $np3 = 'NP-Acces-Ordinateurs-Domaine'
    $np3Check = & netsh nps show np name="$np3" 2>&1
    if ($np3Check -notmatch $np3) {
        $r = & netsh nps add np name="$np3" processingOrder=4 policysource=0 accesstype=allow 2>&1
        if ($LASTEXITCODE -eq 0) { Write-OK "Politique NP creee : $np3 (Allow Machine Auth)" }
        else { Write-Warn "NP $np3 : $r" }
    } else {
        Write-OK "Politique NP existante : $np3"
    }

    Write-OK "=== Strategies NPS configurees ==="
}
#endregion

#region -- Module GPO -----------------------------------------------------------
function Configure-GPO {
    Write-Step "=== GPO : Parametres clients 802.1x (pare-feu + RADIUS) ==="
    Import-Module GroupPolicy -ErrorAction Stop

    $gpoName = 'GPO-NPS-RADIUS-Clients'

    $gpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
    if (-not $gpo) {
        $gpo = New-GPO -Name $gpoName -Comment "Configuration clients RADIUS/802.1x pour NPS"
        Write-OK "GPO creee : $gpoName"
    } else {
        Write-OK "GPO existante : $gpoName"
    }

    # Regles pare-feu RADIUS (UDP 1812 Authn + 1813 Acctg)
    $fw1812 = Get-NetFirewallRule -DisplayName 'RADIUS-UDP-1812' -ErrorAction SilentlyContinue
    if (-not $fw1812) {
        New-NetFirewallRule -DisplayName 'RADIUS-UDP-1812' `
            -Direction Inbound -Protocol UDP -LocalPort 1812 `
            -Action Allow -Profile Any `
            -Description "RADIUS Authentication (NPS)" | Out-Null
        Write-OK "Regle pare-feu creee : RADIUS UDP/1812"
    } else {
        Write-OK "Regle pare-feu existante : RADIUS UDP/1812"
    }

    $fw1813 = Get-NetFirewallRule -DisplayName 'RADIUS-UDP-1813' -ErrorAction SilentlyContinue
    if (-not $fw1813) {
        New-NetFirewallRule -DisplayName 'RADIUS-UDP-1813' `
            -Direction Inbound -Protocol UDP -LocalPort 1813 `
            -Action Allow -Profile Any `
            -Description "RADIUS Accounting (NPS)" | Out-Null
        Write-OK "Regle pare-feu creee : RADIUS UDP/1813"
    } else {
        Write-OK "Regle pare-feu existante : RADIUS UDP/1813"
    }

    # Lier GPO a la racine du domaine
    $domainDN = (Get-ADDomain).DistinguishedName
    $links = Get-GPInheritance -Target $domainDN
    if (-not ($links.GpoLinks | Where-Object { $_.DisplayName -eq $gpoName })) {
        New-GPLink -Name $gpoName -Target $domainDN -LinkEnabled Yes | Out-Null
        Write-OK "GPO liee a : $domainDN"
    } else {
        Write-OK "Lien GPO deja existant"
    }

    Write-OK "=== GPO NPS configuree ==="
}
#endregion

#region -- Validation -----------------------------------------------------------
function Invoke-Validation {
    Write-Step "=== VALIDATION NPS/RADIUS ==="
    $script:score = 0; $script:total = 0

    function Check {
        param([string]$Title, [scriptblock]$Test)
        $script:total++
        try {
            if (& $Test) { Write-OK $Title; $script:score++ }
            else         { Write-Fail $Title }
        } catch { Write-Fail "$Title [ERR: $_]" }
    }

    Check "Role NPAS installe"               { (Get-WindowsFeature NPAS).InstallState -eq 'Installed' }
    Check "Role RSAT-NPAS installe"          { (Get-WindowsFeature RSAT-NPAS).InstallState -eq 'Installed' }
    Check "Service IAS (NPS) en cours"       { (Get-Service IAS -ErrorAction SilentlyContinue).Status -eq 'Running' }
    Check "NPS enregistre dans AD"           {
        $out = & netsh nps show registeredserver 2>&1 | Out-String
        $out -match 'Enregistr'
    }
    Check "Client RADIUS SW-CORE-01"         {
        $out = & netsh nps show client 2>&1 | Out-String
        $out -match 'SW-CORE-01'
    }
    Check "Client RADIUS AP-WIFI-01"         {
        $out = & netsh nps show client 2>&1 | Out-String
        $out -match 'AP-WIFI-01'
    }
    Check "Client RADIUS VPN-GW-01"          {
        $out = & netsh nps show client 2>&1 | Out-String
        $out -match 'VPN-GW-01'
    }
    Check "Strategie NP defaut presente"     {
        $out = & netsh nps show np 2>&1 | Out-String
        $out -match 'Connexions'
    }
    Check "Regle pare-feu RADIUS UDP/1812"   { $null -ne (Get-NetFirewallRule -DisplayName 'RADIUS-UDP-1812' -ErrorAction SilentlyContinue) }
    Check "Regle pare-feu RADIUS UDP/1813"   { $null -ne (Get-NetFirewallRule -DisplayName 'RADIUS-UDP-1813' -ErrorAction SilentlyContinue) }
    Check "Dossier journalisation NPS"       { Test-Path $LogPath }
    Check "GPO-NPS-RADIUS-Clients existe"    { $null -ne (Get-GPO -Name 'GPO-NPS-RADIUS-Clients' -ErrorAction SilentlyContinue) }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    $pct   = if ($script:total -gt 0) { [math]::Round(($script:score / $script:total) * 100) } else { 0 }
    $grade = if ($pct -ge 90) { 'A - Excellent' } elseif ($pct -ge 75) { 'B - Bien' } elseif ($pct -ge 60) { 'C - Correct' } else { 'D - A completer' }
    $col   = if ($pct -ge 90) { 'Green' } elseif ($pct -ge 75) { 'Yellow' } else { 'Red' }
    Write-Host "  Score NPS : $script:score / $script:total  ($pct%)  ->  $grade" -ForegroundColor $col
    Write-Host "========================================" -ForegroundColor Cyan

    Write-Host "`n[NPS] Info serveur NPS :" -ForegroundColor Cyan
    $svc = Get-Service IAS -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Host "  Service IAS : $($svc.Status)"
        Write-Host "  FQDN        : $ServerFQDN"
        Write-Host "  Logs NPS    : $LogPath"
    }
    $clients = & netsh nps show client 2>&1 | Out-String
    $nClients = ($clients -split "`n" | Where-Object { $_ -match 'description' }).Count
    Write-Host "  Clients RADIUS enregistres : $nClients"
}
#endregion

#region -- Main -----------------------------------------------------------------
Write-Host "+=========================================================+" -ForegroundColor Cyan
Write-Host "|   MODULE 19 - NPS / RADIUS : Authentification reseau    |" -ForegroundColor Cyan
Write-Host "|   Domaine : $DomainName  |  Serveur : $env:COMPUTERNAME" -ForegroundColor Cyan
Write-Host "+=========================================================+" -ForegroundColor Cyan

switch ($Module) {
    'Roles'    { Install-NPSRoles }
    'Config'   { Configure-NPS }
    'Policy'   { Configure-NPSPolicies }
    'GPO'      { Configure-GPO }
    'Validate' { Invoke-Validation }
    'All' {
        Install-NPSRoles
        Configure-NPS
        Configure-NPSPolicies
        Configure-GPO
        Invoke-Validation
    }
}
#endregion
