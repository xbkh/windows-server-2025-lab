#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Module 17 - PKI interne : Enterprise Root CA, LDAPS, GPO Auto-enrolement

.DESCRIPTION
    Deploie une PKI interne complete sur DC01 :
      1. Installation et configuration de l'Autorite de Certification (ADCS)
         Enterprise Root CA, RSA 4096 / SHA-256, validite 10 ans
      2. Configuration CRL hebdomadaire, AIA, CDP (LDAP + HTTP)
      3. Publication du certificat CA dans Active Directory
      4. GPO Auto-enrolement (machines + utilisateurs) sur toute l'OU _SATOM
      5. Certificat DomainController pour LDAPS (port 636)
      6. Regles pare-feu LDAPS
      7. Validation complete avec score

.PARAMETER DomainName
    FQDN du domaine (defaut : satom.local)

.PARAMETER Module
    All | CA | GPO | LDAPS | Validate

.EXAMPLE
    .\TP_05_PKI-CA.ps1
    .\TP_05_PKI-CA.ps1 -Module CA
    .\TP_05_PKI-CA.ps1 -Module Validate
#>
[CmdletBinding()]
param(
    [string]$DomainName = 'satom.local',
    [ValidateSet('All','CA','GPO','LDAPS','Validate')]
    [string]$Module = 'All'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Off

#region -- Helpers --------------------------------------------------------------
function Write-Step { param([string]$m) Write-Host "`n[PKI] $m" -ForegroundColor Cyan }
function Write-OK   { param([string]$m) Write-Host "[PKI] OK  $m" -ForegroundColor Green }
function Write-Warn { param([string]$m) Write-Host "[PKI] WRN $m" -ForegroundColor Yellow }
function Write-Fail { param([string]$m) Write-Host "[PKI] ERR $m" -ForegroundColor Red }

$DomainDN   = "DC=$($DomainName.Replace('.',',DC='))"
$ServerName = $env:COMPUTERNAME
$CAName     = "SATOM-CA"
#endregion

#region -- Module CA -----------------------------------------------------------
function Install-CA {
    Write-Step "=== CA : Installation de l'Autorite de Certification Enterprise ==="

    # Installer les roles ADCS
    $roles = @('ADCS-Cert-Authority','ADCS-Web-Enrollment','RSAT-ADCS','RSAT-ADCS-Mgmt')
    foreach ($role in $roles) {
        $feat = Get-WindowsFeature $role -ErrorAction SilentlyContinue
        if ($feat -and $feat.InstallState -ne 'Installed') {
            Install-WindowsFeature -Name $role -IncludeManagementTools | Out-Null
            Write-OK "Installe : $role"
        } else {
            Write-OK "Deja present : $role"
        }
    }

    # Verifier si CA deja configuree (cle registre Configuration)
    $caConfigured = Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration'
    if ($caConfigured) {
        Write-OK "CA deja configuree : $CAName"
        $svc = Get-Service CertSvc -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne 'Running') {
            Set-Service CertSvc -StartupType Automatic
            Start-Service CertSvc
            Start-Sleep 3
            Write-OK "Service CertSvc demarre"
        }
        return
    }

    # Installer la CA Enterprise Root
    Write-Step "Configuration de la CA Enterprise Root ($CAName)..."
    Import-Module ADCSDeployment -ErrorAction SilentlyContinue

    try {
        Install-AdcsCertificationAuthority `
            -CAType EnterpriseRootCA `
            -CACommonName $CAName `
            -CADistinguishedNameSuffix "O=SATOM,C=FR" `
            -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
            -KeyLength 4096 `
            -HashAlgorithmName SHA256 `
            -ValidityPeriod Years `
            -ValidityPeriodUnits 10 `
            -DatabaseDirectory "C:\Windows\system32\CertLog" `
            -LogDirectory "C:\Windows\system32\CertLog" `
            -Force | Out-Null
        Write-OK "CA Enterprise Root installee : $CAName (RSA 4096 / SHA256 / 10 ans)"
    } catch {
        if ($_.Exception.Message -match 'already') {
            Write-OK "CA deja installee"
        } else {
            throw
        }
    }

    # Configurer CRL et AIA
    Write-Step "Configuration CRL (hebdomadaire) et AIA/CDP..."
    $CdpURL  = "http://$ServerName.$DomainName/CertEnroll/<CaName><CRLNameSuffix><DeltaCRLAllowed>.crl"
    $AiaURL  = "http://$ServerName.$DomainName/CertEnroll/<ServerDNSName>_<CaName><CertificateName>.crt"
    $LdapCdp = "ldap:///CN=<CATruncatedName><CRLNameSuffix>,CN=<ServerShortName>,CN=CDP,CN=Public Key Services,CN=Services,<ConfigurationContainer><CDPObjectClass>"
    $LdapAia = "ldap:///CN=<CAName>,CN=AIA,CN=Public Key Services,CN=Services,<ConfigurationContainer><CAObjectClass>"

    certutil -setreg CA\CRLPublicationURLs "1:$($env:SystemRoot)\system32\CertSrv\CertEnroll\<CaName><CRLNameSuffix><DeltaCRLAllowed>.crl\n2:$CdpURL\n1:$LdapCdp" | Out-Null
    certutil -setreg CA\CACertPublicationURLs "2:$AiaURL\n1:$LdapAia" | Out-Null
    certutil -setreg CA\CRLPeriod "Weeks" | Out-Null
    certutil -setreg CA\CRLPeriodUnits 1 | Out-Null
    certutil -setreg CA\CRLDeltaPeriod "Days" | Out-Null
    certutil -setreg CA\CRLDeltaPeriodUnits 0 | Out-Null
    certutil -setreg CA\ValidityPeriod "Years" | Out-Null
    certutil -setreg CA\ValidityPeriodUnits 2 | Out-Null
    Write-OK "CRL hebdomadaire et AIA/CDP configures"

    # Activer l'audit
    certutil -setreg CA\AuditFilter 127 | Out-Null
    Write-OK "Audit CA active (toutes operations)"

    # Demarrer / Redemarrer le service
    Restart-Service CertSvc -Force | Out-Null
    Start-Sleep 3

    # Publier la CRL
    certutil -crl | Out-Null
    Write-OK "CRL publiee"

    Write-OK "=== CA installee et configuree ==="
}
#endregion

#region -- Module GPO ----------------------------------------------------------
function Configure-AutoEnrollGPO {
    Write-Step "=== GPO : Configuration de l'auto-enrolement des certificats ==="
    Import-Module GroupPolicy -ErrorAction Stop

    $gpoName = 'GPO-PKI-AutoEnrollement'

    # Creer la GPO si inexistante
    $gpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
    if (-not $gpo) {
        $gpo = New-GPO -Name $gpoName -Comment "Auto-enrolement certificats PKI SATOM"
        Write-OK "GPO creee : $gpoName"
    } else {
        Write-OK "GPO existante : $gpoName"
    }

    # Configurer l'auto-enrolement Ordinateurs (HKLM)
    $machineRegKey = 'HKLM\SOFTWARE\Policies\Microsoft\Cryptography\AutoEnrollment'
    Set-GPRegistryValue -Name $gpoName -Key $machineRegKey `
        -ValueName 'AEPolicy' -Type DWord -Value 7 | Out-Null
    Set-GPRegistryValue -Name $gpoName -Key $machineRegKey `
        -ValueName 'OfflineExpirationPercent' -Type DWord -Value 10 | Out-Null
    Set-GPRegistryValue -Name $gpoName -Key $machineRegKey `
        -ValueName 'OfflineExpirationStoreNames' -Type String -Value 'MY' | Out-Null

    # Configurer l'auto-enrolement Utilisateurs (HKCU)
    $userRegKey = 'HKCU\SOFTWARE\Policies\Microsoft\Cryptography\AutoEnrollment'
    Set-GPRegistryValue -Name $gpoName -Key $userRegKey `
        -ValueName 'AEPolicy' -Type DWord -Value 7 | Out-Null

    # Lier la GPO a la racine du domaine
    $domainDN = (Get-ADDomain).DistinguishedName
    $links = Get-GPInheritance -Target $domainDN
    if (-not ($links.GpoLinks | Where-Object { $_.DisplayName -eq $gpoName })) {
        New-GPLink -Name $gpoName -Target $domainDN -LinkEnabled Yes | Out-Null
        Write-OK "GPO liee a la racine : $domainDN"
    } else {
        Write-OK "Lien GPO deja existant"
    }

    Write-OK "Auto-enrolement : AEPolicy=7 (machines + utilisateurs)"
    Write-OK "=== GPO auto-enrolement configuree ==="
}
#endregion

#region -- Module LDAPS --------------------------------------------------------
function Configure-LDAPS {
    Write-Step "=== LDAPS : Activation du LDAP securise (port 636) ==="

    # Verifier que la CA est disponible
    $certSvc = Get-Service CertSvc -ErrorAction SilentlyContinue
    if (-not $certSvc -or $certSvc.Status -ne 'Running') {
        Write-Warn "Service CertSvc non disponible. Lancez d'abord le module CA."
        return
    }

    # Demander un certificat DomainController a la CA
    Write-Step "Demande du certificat DomainController a la CA..."

    $infContent = @"
[Version]
Signature = "`$Windows NT`$"

[NewRequest]
Subject = "CN=$ServerName.$DomainName"
KeySpec = 1
KeyLength = 2048
Exportable = TRUE
MachineKeySet = TRUE
SMIME = FALSE
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
ProviderType = 12
RequestType = CMC
KeyUsage = 0xa0

[EnhancedKeyUsageExtension]
OID = 1.3.6.1.5.5.7.3.1 ; Server Authentication
OID = 1.3.6.1.5.5.7.3.2 ; Client Authentication

[Extensions]
2.5.29.17 = "{text}"
_continue_ = "dns=$ServerName&"
_continue_ = "dns=$ServerName.$DomainName&"
"@

    $infPath = "$env:TEMP\ldaps_request.inf"
    $reqPath = "$env:TEMP\ldaps_request.req"
    $crtPath = "$env:TEMP\ldaps_cert.crt"
    $rspPath = "$env:TEMP\ldaps_response.rsp"

    Set-Content -Path $infPath -Value $infContent -Encoding UTF8

    try {
        # Generer la demande
        certreq -new -MachineStore $infPath $reqPath | Out-Null

        # Soumettre a la CA locale
        certreq -submit -config ".\$CAName" -attrib "CertificateTemplate:DomainController" $reqPath $crtPath 2>&1 | Out-Null

        if (Test-Path $crtPath) {
            # Installer le certificat
            certreq -accept -MachineStore $crtPath | Out-Null
            Write-OK "Certificat LDAPS installe dans le magasin Local Machine"
        } else {
            Write-Warn "Echec de la demande certreq - tentative via PowerShell..."
            # Methode alternative : forcer le renouvellement via autoenrollment
            certutil -pulse | Out-Null
            Write-OK "Auto-enrolement pulse (le certificat DC sera emis automatiquement)"
        }
    } catch {
        Write-Warn "Erreur lors de la demande de certificat : $_"
        Write-Warn "Le certificat sera emis via l'auto-enrolement GPO"
    }

    # Regle pare-feu LDAPS
    $fw = Get-NetFirewallRule -DisplayName 'LDAPS-636' -ErrorAction SilentlyContinue
    if (-not $fw) {
        New-NetFirewallRule -DisplayName 'LDAPS-636' `
            -Direction Inbound `
            -Protocol TCP `
            -LocalPort 636 `
            -Action Allow `
            -Profile Any `
            -Description "LDAP securise (LDAPS) port 636" | Out-Null
        Write-OK "Regle pare-feu creee : LDAPS TCP/636"
    } else {
        Write-OK "Regle pare-feu LDAPS existante"
    }

    # Redemarrer le service NTDS pour prendre en compte le certificat
    Write-Step "Redemarrage NTDS pour activer LDAPS..."
    try {
        Restart-Service NTDS -Force | Out-Null
        Start-Sleep 5
        Write-OK "Service NTDS redemarre - LDAPS actif sur port 636"
    } catch {
        Write-Warn "Redemarrage NTDS via sc.exe..."
        & sc.exe stop NTDS | Out-Null
        Start-Sleep 3
        & sc.exe start NTDS | Out-Null
        Start-Sleep 5
    }

    # Tester LDAPS
    $ldapsTest = Test-NetConnection -ComputerName localhost -Port 636 -WarningAction SilentlyContinue
    if ($ldapsTest.TcpTestSucceeded) {
        Write-OK "LDAPS port 636 : accessible"
    } else {
        Write-Warn "LDAPS port 636 : non encore accessible (peut necessiter quelques minutes)"
    }

    Write-OK "=== LDAPS configure ==="
}
#endregion

#region -- Validation ----------------------------------------------------------
function Invoke-Validation {
    Write-Step "=== VALIDATION PKI ==="
    $script:score = 0; $script:total = 0

    function Check {
        param([string]$Title, [scriptblock]$Test)
        $script:total++
        try {
            if (& $Test) { Write-OK $Title; $script:score++ }
            else         { Write-Fail $Title }
        } catch { Write-Fail "$Title [ERR: $_]" }
    }

    Check "Role ADCS-Cert-Authority installe"  { (Get-WindowsFeature ADCS-Cert-Authority).InstallState -eq 'Installed' }
    Check "Service CertSvc en cours"           { (Get-Service CertSvc -ErrorAction SilentlyContinue).Status -eq 'Running' }
    Check "CA '$CAName' dans AD"               {
        $null -ne (Get-ADObject -Filter { Name -eq 'SATOM-CA' } -SearchBase "CN=Public Key Services,CN=Services,CN=Configuration,$DomainDN" -ErrorAction SilentlyContinue)
    }
    Check "CRL publiee dans CertEnroll"        {
        (Get-ChildItem "$env:SystemRoot\system32\CertSrv\CertEnroll\*.crl" -ErrorAction SilentlyContinue).Count -gt 0
    }
    Check "LDAPS port 636 accessible"          {
        (Test-NetConnection -ComputerName localhost -Port 636 -WarningAction SilentlyContinue).TcpTestSucceeded
    }
    Check "Regle pare-feu LDAPS-636"           {
        $null -ne (Get-NetFirewallRule -DisplayName 'LDAPS-636' -ErrorAction SilentlyContinue)
    }
    Check "Certificat CA dans magasin Root"    {
        (Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -match 'SATOM-CA' }).Count -gt 0
    }
    Check "Certificat machine emis par SATOM-CA" {
        (Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Issuer -match 'SATOM-CA' }).Count -gt 0
    }
    Check "GPO-PKI-AutoEnrollement existe"     {
        $null -ne (Get-GPO -Name 'GPO-PKI-AutoEnrollement' -ErrorAction SilentlyContinue)
    }
    Check "GPO AutoEnroll liee au domaine"     {
        $domainDN = (Get-ADDomain).DistinguishedName
        $links = Get-GPInheritance -Target $domainDN
        $null -ne ($links.GpoLinks | Where-Object { $_.DisplayName -eq 'GPO-PKI-AutoEnrollement' })
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    $pct   = if ($script:total -gt 0) { [math]::Round(($script:score / $script:total) * 100) } else { 0 }
    $grade = if ($pct -ge 90) { 'A - Excellent' } elseif ($pct -ge 75) { 'B - Bien' } elseif ($pct -ge 60) { 'C - Correct' } else { 'D - A completer' }
    $col   = if ($pct -ge 90) { 'Green' } elseif ($pct -ge 75) { 'Yellow' } else { 'Red' }
    Write-Host "  Score PKI : $script:score / $script:total  ($pct%)  ->  $grade" -ForegroundColor $col
    Write-Host "========================================" -ForegroundColor Cyan

    Write-Host "`n[PKI] Infos CA :" -ForegroundColor Cyan
    $ca = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -match 'SATOM-CA' } | Select-Object -First 1
    if ($ca) {
        Write-Host "  Sujet     : $($ca.Subject)"
        Write-Host "  Emetteur  : $($ca.Issuer)"
        Write-Host "  Expiration: $($ca.NotAfter.ToString('dd/MM/yyyy'))"
        Write-Host "  SHA1      : $($ca.Thumbprint)"
    }
}
#endregion

#region -- Main ----------------------------------------------------------------
Write-Host "+==============================================================+"  -ForegroundColor Cyan
Write-Host "|   MODULE 17 - PKI Interne : CA Enterprise + LDAPS + AutoEnroll |" -ForegroundColor Cyan
Write-Host "|   Domaine : $DomainName"  -ForegroundColor Cyan
Write-Host "+==============================================================+"  -ForegroundColor Cyan

switch ($Module) {
    'CA'       { Install-CA }
    'GPO'      { Configure-AutoEnrollGPO }
    'LDAPS'    { Configure-LDAPS }
    'Validate' { Invoke-Validation }
    'All' {
        Install-CA
        Configure-AutoEnrollGPO
        Configure-LDAPS
        Invoke-Validation
    }
}
#endregion
