#Requires -RunAsAdministrator
<#
.SYNOPSIS
    TP Module 16 - Azure Arc & Verification complete du lab
    Formation Windows Server 2025

.DESCRIPTION
    Ce script couvre :
        Module 16  - Connexion du serveur a Azure Arc
                   - Validation complete de l'infrastructure

.PREREQUIS
    - Un abonnement Azure actif
    - Az PowerShell installe (Install-Module Az)
    - Connexion Internet depuis le serveur

.EXAMPLE
    # Avec paramtres Azure :
    .\TP_04_AzureArc-Synthese.ps1 -SubscriptionId "xxx" -ResourceGroup "rg-lab" -Location "francecentral"

    # Validation du lab seulement (sans Azure) :
    .\TP_04_AzureArc-Synthese.ps1 -ValidationOnly
#>

[CmdletBinding()]
param(
    [string]$DomainName      = "satom.local",
    [string]$SubscriptionId  = "",
    [string]$ResourceGroup   = "rg-ws2025-lab",
    [string]$Location        = "francecentral",
    [string]$TenantId        = "",
    [switch]$ValidationOnly    # N'effectue que la validation du lab
)

#region --- Helpers -----------------------------------------------------------
function Write-Step { param([string]$M) Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] -> $M" -ForegroundColor Cyan }
function Write-OK   { param([string]$M) Write-Host "  [OK] $M" -ForegroundColor Green  }
function Write-Warn { param([string]$M) Write-Host "  [!] $M" -ForegroundColor Yellow }
function Write-Fail { param([string]$M) Write-Host "   $M" -ForegroundColor Red    }
function Write-Info { param([string]$M) Write-Host "  [i] $M" -ForegroundColor Blue  }
#endregion

Write-Host @"
+==============================================================+
|  FORMATION WS2025 - TP 04 : Azure Arc & Validation Lab      |
+==============================================================+
"@ -ForegroundColor Magenta

#region =======================================================================
#  VALIDATION COMPLTE DU LAB
# ============================================================================
Write-Step "VALIDATION GLOBALE - Verification de tous les modules"

$global:Score     = 0
$global:MaxScore  = 0
$global:Failures  = @()

function Test-Lab {
    param([string]$Description, [scriptblock]$Test, [int]$Points = 1)
    $global:MaxScore += $Points
    try {
        $result = & $Test
        if ($result) {
            Write-OK "[$Points pts] $Description"
            $global:Score += $Points
        } else {
            Write-Fail "[$Points pts] $Description"
            $global:Failures += $Description
        }
    } catch {
        Write-Fail "[$Points pts] $Description - Exception: $($_.Exception.Message)"
        $global:Failures += $Description
    }
}

Import-Module ActiveDirectory -ErrorAction SilentlyContinue
Import-Module DnsServer       -ErrorAction SilentlyContinue

$DC   = "DC=" + ($DomainName.Split(".") -join ",DC=")
$DCIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -ne "127.0.0.1"} | Select-Object -First 1).IPAddress

Write-Host "`n  -- Module 00/02 : Infrastructure de base --" -ForegroundColor White
Test-Lab "IP Statique configuree" {
    $ip = Get-NetIPInterface | Where-Object {$_.Dhcp -eq "Disabled" -and $_.AddressFamily -eq "IPv4"}
    $ip -ne $null
} -Points 2

Test-Lab "Role AD DS installe" {
    (Get-WindowsFeature -Name AD-Domain-Services).InstallState -eq "Installed"
} -Points 2

Test-Lab "Service AD DS en cours d'execution" {
    (Get-Service -Name "ADWS").Status -eq "Running"
} -Points 2

Test-Lab "Domaine $DomainName disponible" {
    $dom = Get-ADDomain -ErrorAction Stop
    $dom.DNSRoot -eq $DomainName
} -Points 3

Test-Lab "DC promu correctement (ntds.dit present)" {
    Test-Path "C:\Windows\NTDS\ntds.dit"
} -Points 2

Write-Host "`n  -- Module 03 : DNS & DHCP --" -ForegroundColor White
Test-Lab "Role DNS installe et actif" {
    (Get-WindowsFeature -Name DNS).InstallState -eq "Installed" -and
    (Get-Service -Name DNS).Status -eq "Running"
} -Points 2

Test-Lab "Zone DNS forward '$DomainName' existe" {
    Get-DnsServerZone -Name $DomainName -ErrorAction SilentlyContinue
} -Points 2

Test-Lab "Zone DNS inversee configuree" {
    @(Get-DnsServerZone | Where-Object {$_.IsReverseLookupZone}).Count -gt 0
} -Points 1

Test-Lab "Forwarders DNS configures" {
    @(Get-DnsServerForwarder).Count -gt 0
} -Points 1

Test-Lab "Role DHCP installe et actif" {
    (Get-WindowsFeature -Name DHCP).InstallState -eq "Installed" -and
    (Get-Service -Name DHCPServer).Status -eq "Running"
} -Points 2

Test-Lab "Etendue DHCP active" {
    @(Get-DhcpServerv4Scope | Where-Object {$_.State -eq "Active"}).Count -gt 0
} -Points 2

Test-Lab "DHCP autorise dans AD" {
    @(Get-DhcpServerInDC).Count -gt 0
} -Points 1

Write-Host "`n  -- Module 04 : Structure AD --" -ForegroundColor White
Test-Lab "OU '_SATOM' creee" {
    Get-ADOrganizationalUnit -Filter {Name -eq "_SATOM"} -ErrorAction SilentlyContinue
} -Points 2

Test-Lab "Utilisateurs crees (> 5)" {
    $count = @(Get-ADUser -Filter * -SearchBase "OU=_SATOM,$DC" -ErrorAction SilentlyContinue).Count
    $count -gt 5
} -Points 2

Test-Lab "Groupes de securite crees (> 3)" {
    $count = @(Get-ADGroup -Filter {Name -like "GRP_*"} -ErrorAction SilentlyContinue).Count
    $count -gt 3
} -Points 2

Write-Host "`n  -- Module 05 : GPO --" -ForegroundColor White
Test-Lab "GPOs de securite creees" {
    $count = @(Get-GPO -All | Where-Object {$_.DisplayName -like "GPO-*"}).Count
    $count -gt 0
} -Points 2

Test-Lab "Service Windows Event Log actif (audit)" {
    (Get-Service -Name EventLog).Status -eq "Running"
} -Points 1

Write-Host "`n  -- Module 07 : LAPS --" -ForegroundColor White
Test-Lab "Attribut LAPS present dans le schema AD" {
    $attr = Get-ADObject -SearchBase (Get-ADRootDSE).schemaNamingContext `
        -Filter {ldapDisplayName -eq "msLAPS-Password"} -ErrorAction SilentlyContinue
    $attr -ne $null
} -Points 3

Write-Host "`n  -- Module 14 : Securite --" -ForegroundColor White
Test-Lab "SMBv1 desactive" {
    -not (Get-SmbServerConfiguration).EnableSMB1Protocol
} -Points 2

Test-Lab "Signature SMB activee" {
    (Get-SmbServerConfiguration).RequireSecuritySignature
} -Points 2

Test-Lab "WDigest desactive (protection LSASS)" {
    $val = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" `
        -Name UseLogonCredential -ErrorAction SilentlyContinue
    $val.UseLogonCredential -eq 0
} -Points 2

Test-Lab "Pare-feu Windows actif" {
    $profiles = Get-NetFirewallProfile
    ($profiles | Where-Object {$_.Enabled -eq $true}).Count -ge 1
} -Points 1

Write-Host "`n  -- Module 15 : Hyper-V --" -ForegroundColor White
Test-Lab "Role Hyper-V installe" {
    (Get-WindowsFeature -Name Hyper-V).InstallState -eq "Installed"
} -Points 2

# -- Affichage du score final -------------------------------------------------
$percent = [math]::Round($global:Score / $global:MaxScore * 100, 1)
$color   = if ($percent -ge 80) {"Green"} elseif ($percent -ge 60) {"Yellow"} else {"Red"}
$grade   = if ($percent -ge 90) {"A - Excellent"} elseif ($percent -ge 75) {"B - Bien"} elseif ($percent -ge 60) {"C - Satisfaisant"} else {"D - A ameliorer"}

Write-Host @"

+==========================================================+
|                RESULTAT VALIDATION LAB                |
+==========================================================+
|  Score : $($global:Score)/$($global:MaxScore) points ($percent%)                        
|  Mention : $grade                                       
+==========================================================+
"@ -ForegroundColor $color

if ($global:Failures.Count -gt 0) {
    Write-Host "`n  Points a corriger :" -ForegroundColor Yellow
    $global:Failures | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
}

if ($ValidationOnly) { return }

#region =======================================================================
#  MODULE 16  AZURE ARC
# ============================================================================
Write-Step "MODULE 16 - Connexion Azure Arc"

if (-not $SubscriptionId) {
    Write-Warn "SubscriptionId non fourni. Mode demonstration (pas de connexion reelle a Azure)."
    Write-Info "Pour connecter ce serveur a Azure Arc, executez :"
    Write-Host @"

    # 1. Installer le module Az
    Install-Module -Name Az -Force -AllowClobber

    # 2. Se connecter  Azure
    Connect-AzAccount -TenantId '<votre-tenant-id>'

    # 3. Dfinir l'abonnement
    Set-AzContext -SubscriptionId '<votre-subscription-id>'

    # 4. Crer le Resource Group
    New-AzResourceGroup -Name '$ResourceGroup' -Location '$Location'

    # 5. Tlcharger et excuter le script Azure Arc
    Invoke-WebRequest -Uri 'https://aka.ms/AzureConnectedMachineAgent' -OutFile 'C:\AzureArcAgent.msi'
    msiexec /i 'C:\AzureArcAgent.msi' /l*v 'C:\AzureArcSetup.log' /quiet

    # 6. Connecter le serveur
    & 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe' connect ``
        --subscription-id '<subscription-id>' ``
        --resource-group  '$ResourceGroup' ``
        --location        '$Location' ``
        --tenant-id       '<tenant-id>'

"@ -ForegroundColor Gray
    return
}

# -- Mode oprationnel (SubscriptionId fourni) --------------------------------
try {
    Import-Module Az.ConnectedMachine -ErrorAction Stop
} catch {
    Write-Info "Installation du module Az.ConnectedMachine..."
    Install-Module Az.ConnectedMachine -Force -AllowClobber
    Import-Module Az.ConnectedMachine
}

# Connexion  Azure
if (-not (Get-AzContext -ErrorAction SilentlyContinue)) {
    Write-Info "Connexion a Azure (une fenetre de navigateur va s'ouvrir)..."
    Connect-AzAccount -TenantId $TenantId
}
Set-AzContext -SubscriptionId $SubscriptionId

# Crer le Resource Group
$rg = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue
if (-not $rg) {
    New-AzResourceGroup -Name $ResourceGroup -Location $Location
    Write-OK "Resource Group cree : $ResourceGroup ($Location)"
} else {
    Write-OK "Resource Group deja existant : $ResourceGroup"
}

# Tlcharger et installer l'agent Azure Arc
$agentMsi = "$env:TEMP\AzureConnectedMachineAgent.msi"
if (-not (Test-Path "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe")) {
    Write-Info "Telechargement de l'agent Azure Arc..."
    Invoke-WebRequest -Uri "https://aka.ms/AzureConnectedMachineAgent" -OutFile $agentMsi
    
    Write-Info "Installation de l'agent..."
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$agentMsi`" /l*v `"$env:TEMP\AzureArcSetup.log`" /quiet" -Wait
    Write-OK "Agent Azure Arc installe"
}

# Connecter le serveur  Azure Arc
Write-Info "Connexion du serveur a Azure Arc..."
$token = (Get-AzAccessToken).Token
& "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" connect `
    --subscription-id  $SubscriptionId `
    --resource-group   $ResourceGroup `
    --location         $Location `
    --tenant-id        $TenantId `
    --access-token     $token

Write-OK "Serveur connecte a Azure Arc !"
Write-Info "Pour activer le Hotpatching via Azure Arc :"
Write-Host "    https://portal.azure.com/#view/Microsoft_Azure_HybridCompute" -ForegroundColor Gray
#endregion

Write-Host @"

+==============================================================+
|  [OK]  FORMATION WINDOWS SERVER 2025 - LAB COMPLET            |
+==============================================================+
|  Modules completes :                                        |
|    [OK] 00  Environnement de laboratoire                       |
|    [OK] 01  Introduction Windows Server 2025                   |
|    [OK] 02  Active Directory Domain Services                   |
|    [OK] 03  DNS + DHCP + Client                                |
|    [OK] 04  OUs / Utilisateurs / Groupes                       |
|    [OK] 05  GPO & gestion centralisee                          |
|    [OK] 07  Windows LAPS                                       |
|    [OK] 08  Sites Active Directory                             |
|    [OK] 11  Automatisation PowerShell / WinGet                 |
|    [OK] 12  Performances & optimisations                       |
|    [OK] 13  Disponibilite & monitoring                         |
|    [OK] 14  Securite avancee & durcissement                    |
|    [OK] 15  Hyper-V                                            |
|    [OK] 16  Azure Arc (Cloud hybride)                          |
+==============================================================+
"@ -ForegroundColor Magenta
