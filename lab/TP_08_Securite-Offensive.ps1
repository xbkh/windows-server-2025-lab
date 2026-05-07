#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Module 20 - Securite offensive controlee / Purple Team

.DESCRIPTION
    Realise la partie offensive du lab sans collecte de secrets et sans outil d'attaque.
    Le script prepare une OU de test, active les audits utiles, simule des scenarios
    pedagogiques, collecte les traces defensives et fournit un nettoyage reversible.

    Modules :
      All       : Prepare + Audit + Simulate + Detect + Validate
      Prepare   : Cree l'OU, les comptes et le compte de service de test
      Audit     : Active l'audit avance utile aux scenarios AD
      Simulate  : Genere des actions et evenements de simulation sans exploitation
      Detect    : Collecte les signaux AD/Windows et produit un rapport Markdown/CSV
      Validate  : Verifie que le module offensif controle est pret
      Cleanup   : Supprime uniquement l'OU OffensiveLab et ses objets

.PARAMETER DomainName
    FQDN du domaine (defaut : satom.local)

.PARAMETER Module
    All | Prepare | Audit | Simulate | Detect | Validate | Cleanup

.PARAMETER OutputDir
    Dossier de sortie des rapports

.PARAMETER EnableVulnerableAccounts
    Cree un compte de test volontairement vulnerable a AS-REP Roasting.
    A utiliser uniquement dans le lab, puis lancer Cleanup.

.EXAMPLE
    .\TP_08_Securite-Offensive.ps1
    .\TP_08_Securite-Offensive.ps1 -Module Detect
    .\TP_08_Securite-Offensive.ps1 -Module Prepare -EnableVulnerableAccounts
    .\TP_08_Securite-Offensive.ps1 -Module Cleanup
#>

[CmdletBinding()]
param(
    [string]$DomainName = 'satom.local',
    [ValidateSet('All','Prepare','Audit','Simulate','Detect','Validate','Cleanup')]
    [string]$Module = 'All',
    [string]$OutputDir = 'C:\Formation\Reports\Offensive',
    [int]$LookbackHours = 4,
    [switch]$EnableVulnerableAccounts
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Off

#region -- Helpers ------------------------------------------------------------
function Write-Step { param([string]$m) Write-Host "`n[OFF] $m" -ForegroundColor Cyan }
function Write-OK   { param([string]$m) Write-Host "[OFF] OK  $m" -ForegroundColor Green }
function Write-Warn { param([string]$m) Write-Host "[OFF] WRN $m" -ForegroundColor Yellow }
function Write-Fail { param([string]$m) Write-Host "[OFF] ERR $m" -ForegroundColor Red }
function Write-Info { param([string]$m) Write-Host "[OFF] INF $m" -ForegroundColor Blue }

$script:LabOUName  = 'OffensiveLab'
$script:EventSource = 'SATOM-OffensiveLab'
$script:LabOU = $null
$script:DomainDN = $null
$script:DomNetbios = ($DomainName.Split('.')[0]).ToUpper()

function Initialize-Context {
    Import-Module ActiveDirectory -ErrorAction Stop
    $domain = Get-ADDomain -Identity $DomainName -ErrorAction Stop
    $script:DomainDN = $domain.DistinguishedName
    $script:DomNetbios = $domain.NetBIOSName

    $parent = Get-ADOrganizationalUnit -LDAPFilter '(ou=_SATOM)' -SearchBase $script:DomainDN -ErrorAction SilentlyContinue |
        Select-Object -First 1
    $parentDN = if ($parent) { $parent.DistinguishedName } else { $script:DomainDN }
    $script:LabOU = "OU=$($script:LabOUName),$parentDN"

    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
}

function Ensure-EventSource {
    if (-not [System.Diagnostics.EventLog]::SourceExists($script:EventSource)) {
        New-EventLog -LogName Application -Source $script:EventSource
        Write-OK "Source EventLog creee : $script:EventSource"
    }
}

function Write-LabEvent {
    param(
        [int]$EventId,
        [string]$Message,
        [string]$EntryType = 'Information'
    )
    Ensure-EventSource
    Write-EventLog -LogName Application -Source $script:EventSource -EventId $EventId -EntryType $EntryType -Message $Message
}

function Export-Objects {
    param(
        [object[]]$Data,
        [string]$Path
    )
    $cleanData = @($Data | Where-Object { $null -ne $_ })
    if ($cleanData.Count -gt 0) {
        $cleanData | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    } else {
        'No data' | Set-Content -Path $Path -Encoding UTF8
    }
}

function Get-OffensiveLabOU {
    if (-not $script:LabOU) { Initialize-Context }
    try {
        Get-ADOrganizationalUnit -Identity $script:LabOU -ErrorAction Stop
    } catch {
        $null
    }
}

function Get-NoPreauthUsers {
    Get-ADUser -LDAPFilter '(&(objectCategory=person)(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=4194304))' `
        -Properties DoesNotRequirePreAuth,Enabled,Description
}

function Get-LabADUser {
    param(
        [string]$Identity,
        [string[]]$Properties = @()
    )
    try {
        if ($Properties.Count -gt 0) {
            Get-ADUser -Identity $Identity -Properties $Properties -ErrorAction Stop
        } else {
            Get-ADUser -Identity $Identity -ErrorAction Stop
        }
    } catch {
        $null
    }
}

function Get-LabADGroup {
    param([string]$Identity)
    try {
        Get-ADGroup -Identity $Identity -ErrorAction Stop
    } catch {
        $null
    }
}

function New-OrUpdateLabUser {
    param(
        [string]$SamAccountName,
        [string]$Name,
        [string]$Password,
        [bool]$Enabled = $true,
        [string]$Description = 'OffensiveLab controlled test account'
    )

    $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $existing = Get-LabADUser -Identity $SamAccountName

    if (-not $existing) {
        New-ADUser -SamAccountName $SamAccountName `
            -UserPrincipalName "$SamAccountName@$DomainName" `
            -Name $Name `
            -DisplayName $Name `
            -Path $script:LabOU `
            -AccountPassword $securePassword `
            -Enabled $Enabled `
            -ChangePasswordAtLogon $false `
            -PasswordNeverExpires $false `
            -Description $Description | Out-Null
        Write-OK "Compte cree : $SamAccountName"
    } else {
        Set-ADAccountPassword -Identity $SamAccountName -Reset -NewPassword $securePassword
        Set-ADUser -Identity $SamAccountName -Description $Description -PasswordNeverExpires $false
        if ($Enabled) { Enable-ADAccount -Identity $SamAccountName } else { Disable-ADAccount -Identity $SamAccountName }
        Write-OK "Compte mis a jour : $SamAccountName"
    }
}
#endregion

#region -- Prepare ------------------------------------------------------------
function Invoke-Prepare {
    Write-Step "=== PREPARE : OU et comptes de test controles ==="
    Initialize-Context

    if (-not (Get-OffensiveLabOU)) {
        $parentDN = $script:LabOU.Substring($script:LabOU.IndexOf(',') + 1)
        New-ADOrganizationalUnit -Name $script:LabOUName -Path $parentDN -ProtectedFromAccidentalDeletion $false | Out-Null
        Write-OK "OU creee : $script:LabOU"
    } else {
        Write-OK "OU existante : $script:LabOU"
    }

    $groupName = 'GRP_OffensiveLab_Testers'
    if (-not (Get-LabADGroup -Identity $groupName)) {
        New-ADGroup -Name $groupName `
            -SamAccountName $groupName `
            -GroupScope Global `
            -GroupCategory Security `
            -Path $script:LabOU `
            -Description 'OffensiveLab controlled testers' | Out-Null
        Write-OK "Groupe cree : $groupName"
    } else {
        Write-OK "Groupe existant : $groupName"
    }

    New-OrUpdateLabUser -SamAccountName 'olab.audit' `
        -Name 'Offensive Lab Audit User' `
        -Password 'X9q!vT7#Lm2@pR5$zN8%aK3&wB6' `
        -Description 'OffensiveLab standard account for controlled tests'

    New-OrUpdateLabUser -SamAccountName 'svc-ol-web' `
        -Name 'Offensive Lab Web Service' `
        -Password 'H3x@N7r#P2v!Q8m$L5a%Y6c&F4' `
        -Description 'OffensiveLab service account with SPN for Kerberos review'

    $spn = 'HTTP/ol-web.satom.local'
    $svc = Get-LabADUser -Identity 'svc-ol-web' -Properties @('ServicePrincipalName')
    if ($svc.ServicePrincipalName -notcontains $spn) {
        Set-ADUser -Identity 'svc-ol-web' -ServicePrincipalNames @{Add=$spn}
        Write-OK "SPN ajoute : $spn"
    } else {
        Write-OK "SPN existant : $spn"
    }

    Add-ADGroupMember -Identity $groupName -Members 'olab.audit','svc-ol-web' -ErrorAction SilentlyContinue
    Write-OK "Membres ajoutes a $groupName"

    if ($EnableVulnerableAccounts) {
        New-OrUpdateLabUser -SamAccountName 'olab.nopreauth' `
            -Name 'Offensive Lab No Preauth User' `
            -Password 'K9p!D4s@V7x#T2r%N6b&Q8m' `
            -Description 'OffensiveLab intentionally vulnerable account - AS-REP preauth disabled'
        Set-ADAccountControl -Identity 'olab.nopreauth' -DoesNotRequirePreAuth $true
        Write-Warn "Compte volontairement vulnerable active : olab.nopreauth"
    } else {
        $legacy = Get-LabADUser -Identity 'olab.nopreauth'
        if ($legacy) {
            Set-ADAccountControl -Identity 'olab.nopreauth' -DoesNotRequirePreAuth $false
            Disable-ADAccount -Identity 'olab.nopreauth'
            Write-OK "Compte olab.nopreauth neutralise"
        }
    }

    Write-LabEvent -EventId 9200 -Message 'OffensiveLab prepare completed'
    Write-OK "Preparation terminee"
}
#endregion

#region -- Audit --------------------------------------------------------------
function Invoke-Audit {
    Write-Step "=== AUDIT : Activation des traces utiles ==="
    Initialize-Context

    try {
        $auditResult = & auditpol /set /category:* /success:enable /failure:enable 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Audit avance active pour toutes les categories"
        } else {
            Write-Warn "Audit avance partiellement applique : $($auditResult -join ' ')"
        }
    } catch {
        Write-Warn "Audit avance non applique : $($_.Exception.Message)"
    }

    try {
        $auditRegPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\Audit'
        if (-not (Test-Path $auditRegPath)) {
            New-Item -Path $auditRegPath -Force | Out-Null
        }
        New-ItemProperty -Path $auditRegPath `
            -Name 'ProcessCreationIncludeCmdLine_Enabled' `
            -Value 1 `
            -PropertyType DWord `
            -Force | Out-Null
        Write-OK "Audit process creation avec ligne de commande active"
    } catch {
        Write-Warn "Ligne de commande process creation non configuree : $($_.Exception.Message)"
    }

    Write-LabEvent -EventId 9201 -Message 'OffensiveLab audit policy configured'
    Write-OK "Audit defensif pret"
}
#endregion

#region -- Simulate -----------------------------------------------------------
function Invoke-Simulate {
    Write-Step "=== SIMULATE : Scenarios controles sans exploitation ==="
    Initialize-Context
    Ensure-EventSource

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $runDir = Join-Path $OutputDir "run-$timestamp"
    New-Item -ItemType Directory -Path $runDir -Force | Out-Null

    Write-Info "Dossier run : $runDir"

    $domainInfo = Get-ADDomain | Select-Object DNSRoot,NetBIOSName,DomainMode,PDCEmulator,RIDMaster,InfrastructureMaster
    Export-Objects -Data @($domainInfo) -Path (Join-Path $runDir 'recon_domain.csv')
    Write-LabEvent -EventId 9210 -Message 'SIM-Recon: domain metadata enumerated for defensive validation'
    Write-OK "Recon AD controlee : domaine"

    $dcs = Get-ADDomainController -Filter * |
        Select-Object HostName,IPv4Address,Site,IsGlobalCatalog,OperatingSystem
    Export-Objects -Data @($dcs) -Path (Join-Path $runDir 'recon_domain_controllers.csv')
    Write-OK "Recon AD controlee : controleurs de domaine"

    $objects = Get-ADObject -SearchBase $script:LabOU -LDAPFilter '(objectClass=*)' -Properties objectClass |
        Select-Object Name,ObjectClass,DistinguishedName
    Export-Objects -Data @($objects) -Path (Join-Path $runDir 'recon_offensive_lab_objects.csv')
    Write-OK "Recon AD controlee : OU OffensiveLab"

    $ports = @(53,88,135,389,445,464,636,3268,3269)
    $portResults = foreach ($port in $ports) {
        $test = Test-NetConnection -ComputerName $env:COMPUTERNAME -Port $port -WarningAction SilentlyContinue
        [pscustomobject]@{
            ComputerName = $env:COMPUTERNAME
            Port = $port
            TcpTestSucceeded = $test.TcpTestSucceeded
        }
    }
    Export-Objects -Data @($portResults) -Path (Join-Path $runDir 'recon_dc_ports.csv')
    Write-LabEvent -EventId 9211 -Message 'SIM-Recon: DC port exposure reviewed'
    Write-OK "Recon reseau controlee : ports AD locaux"

    $sharePaths = @("\\$env:COMPUTERNAME\SYSVOL","\\$env:COMPUTERNAME\NETLOGON")
    $shareResults = foreach ($path in $sharePaths) {
        [pscustomobject]@{
            Path = $path
            Accessible = Test-Path $path
            Time = Get-Date
        }
    }
    Export-Objects -Data @($shareResults) -Path (Join-Path $runDir 'recon_smb_access.csv')
    Write-LabEvent -EventId 9212 -Message 'SIM-SMB: SYSVOL and NETLOGON access checked'
    Write-OK "Acces SMB controle : SYSVOL/NETLOGON"

    Write-LabEvent -EventId 9220 -Message 'SIM-PasswordSpray: simulated only, no credential attempts performed'
    Write-LabEvent -EventId 9221 -Message 'SIM-KerberoastReview: SPN inventory prepared, no ticket extraction performed'
    Write-LabEvent -EventId 9222 -Message 'SIM-ADCSReview: certificate service review marker, no certificate abuse performed'
    Write-LabEvent -EventId 9223 -Message 'SIM-DCSyncReview: replication permissions review marker, no secret replication performed'

    Write-OK "Simulations marquees dans Application/$script:EventSource"
    Write-Info "Aucune extraction de hash, ticket, certificat ou mot de passe n'a ete effectuee."
}
#endregion

#region -- Detect -------------------------------------------------------------
function Invoke-Detect {
    Write-Step "=== DETECT : Collecte defensive et rapport ==="
    Initialize-Context

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $reportPath = Join-Path $OutputDir "offensive_detection_report_$timestamp.md"
    $csvDir = Join-Path $OutputDir "detect-$timestamp"
    New-Item -ItemType Directory -Path $csvDir -Force | Out-Null
    $since = (Get-Date).AddHours(-1 * $LookbackHours)

    $spnUsers = Get-ADUser -LDAPFilter '(servicePrincipalName=*)' -Properties ServicePrincipalName,PasswordLastSet,LastLogonDate,Enabled |
        Select-Object SamAccountName,Enabled,PasswordLastSet,LastLogonDate,@{Name='SPN';Expression={$_.ServicePrincipalName -join ';'}}
    Export-Objects -Data @($spnUsers) -Path (Join-Path $csvDir 'ad_users_with_spn.csv')

    $noPreauth = Get-NoPreauthUsers |
        Select-Object SamAccountName,Enabled,DoesNotRequirePreAuth,Description
    Export-Objects -Data @($noPreauth) -Path (Join-Path $csvDir 'ad_users_no_preauth.csv')

    $pwdNeverExpires = Get-ADUser -Filter {PasswordNeverExpires -eq $true} -Properties PasswordNeverExpires,Enabled,Description |
        Select-Object SamAccountName,Enabled,PasswordNeverExpires,Description
    Export-Objects -Data @($pwdNeverExpires) -Path (Join-Path $csvDir 'ad_users_password_never_expires.csv')

    $domain = Get-ADDomain
    $privSids = @(
        "$($domain.DomainSID.Value)-512",
        "$($domain.DomainSID.Value)-519",
        'S-1-5-32-544'
    )
    $privGroups = Get-ADGroup -Filter * -Properties SID |
        Where-Object { $privSids -contains $_.SID.Value }
    $privMembers = foreach ($group in $privGroups) {
        try {
            Get-ADGroupMember -Identity $group.DistinguishedName -Recursive | ForEach-Object {
                [pscustomobject]@{
                    Group = $group.Name
                    Member = $_.Name
                    SamAccountName = $_.SamAccountName
                    ObjectClass = $_.ObjectClass
                }
            }
        } catch {}
    }
    Export-Objects -Data @($privMembers) -Path (Join-Path $csvDir 'ad_privileged_group_members.csv')

    $smb = Get-SmbServerConfiguration |
        Select-Object EnableSMB1Protocol,RequireSecuritySignature,EncryptData,RejectUnencryptedAccess
    Export-Objects -Data @($smb) -Path (Join-Path $csvDir 'smb_security.csv')

    $securityIds = @(4624,4625,4672,4688,4720,4732,4738,4768,4769,4771,5140,5145,7045,1102)
    $securityEvents = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=$securityIds; StartTime=$since} -MaxEvents 300 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated,Id,ProviderName,MachineName,@{Name='Message';Expression={($_.Message -replace "`r?`n",' ')}}
    Export-Objects -Data @($securityEvents) -Path (Join-Path $csvDir 'windows_security_events.csv')

    $labEvents = Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName=$script:EventSource; StartTime=$since} -MaxEvents 100 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated,Id,ProviderName,MachineName,@{Name='Message';Expression={($_.Message -replace "`r?`n",' ')}}
    Export-Objects -Data @($labEvents) -Path (Join-Path $csvDir 'offensive_lab_simulation_events.csv')

    $lines = @()
    $lines += '# Rapport - Securite offensive controlee'
    $lines += ''
    $lines += "| Champ | Valeur |"
    $lines += "|-------|--------|"
    $lines += "| Domaine | $DomainName |"
    $lines += "| Serveur | $env:COMPUTERNAME |"
    $lines += "| Fenetre | $LookbackHours heures |"
    $lines += "| Dossier CSV | $csvDir |"
    $lines += ''
    $lines += '## Synthese'
    $lines += ''
    $lines += "- Comptes avec SPN : $(@($spnUsers).Count)"
    $lines += "- Comptes sans preauth Kerberos : $(@($noPreauth).Count)"
    $lines += "- Comptes PasswordNeverExpires : $(@($pwdNeverExpires).Count)"
    $lines += "- Membres groupes privilegies suivis : $(@($privMembers).Count)"
    $lines += "- Evenements Security collectes : $(@($securityEvents).Count)"
    $lines += "- Evenements OffensiveLab collectes : $(@($labEvents).Count)"
    $lines += ''
    $lines += '## Points de lecture'
    $lines += ''
    $lines += '- `ad_users_with_spn.csv` sert a reviser les comptes de service exposables a Kerberoasting.'
    $lines += '- `ad_users_no_preauth.csv` doit rester vide hors exercice AS-REP volontaire.'
    $lines += '- `windows_security_events.csv` contient les signaux utiles pour la detection.'
    $lines += '- `offensive_lab_simulation_events.csv` contient les marqueurs de simulation du TP.'
    $lines += ''
    $lines += '## Garde-fous'
    $lines += ''
    $lines += 'Ce TP ne collecte pas de hash, ticket Kerberos, mot de passe LAPS en clair ou certificat abusif.'
    $lines | Set-Content -Path $reportPath -Encoding UTF8

    Write-LabEvent -EventId 9230 -Message "OffensiveLab detection report generated: $reportPath"
    Write-OK "Rapport genere : $reportPath"
    Write-OK "CSV generes : $csvDir"
}
#endregion

#region -- Validate -----------------------------------------------------------
function Invoke-Validation {
    Write-Step "=== VALIDATE : Etat de la partie offensive controlee ==="
    Initialize-Context
    $script:score = 0; $script:total = 0

    function Check {
        param([string]$Title, [scriptblock]$Test)
        $script:total++
        try {
            if (& $Test) { Write-OK $Title; $script:score++ }
            else         { Write-Fail $Title }
        } catch { Write-Fail "$Title [ERR: $_]" }
    }

    Check "Module ActiveDirectory disponible" { $null -ne (Get-Module ActiveDirectory) }
    Check "OU OffensiveLab presente"          { $null -ne (Get-OffensiveLabOU) }
    Check "Groupe testeurs present"           { $null -ne (Get-LabADGroup -Identity 'GRP_OffensiveLab_Testers') }
    Check "Compte standard present"           { $null -ne (Get-LabADUser -Identity 'olab.audit') }
    Check "Compte service SPN present"        {
        $u = Get-LabADUser -Identity 'svc-ol-web' -Properties @('ServicePrincipalName')
        $u -and ($u.ServicePrincipalName -contains 'HTTP/ol-web.satom.local')
    }
    Check "EventLog actif"                    { (Get-Service EventLog).Status -eq 'Running' }
    Check "Source simulation presente"        { [System.Diagnostics.EventLog]::SourceExists($script:EventSource) }
    Check "Dossier rapports present"          { Test-Path $OutputDir }
    Check "SMBv1 desactive"                   { -not (Get-SmbServerConfiguration).EnableSMB1Protocol }
    Check "Signature SMB requise"             { (Get-SmbServerConfiguration).RequireSecuritySignature }
    Check "Comptes no-preauth hors lab absents" {
        $np = Get-NoPreauthUsers
        (@($np | Where-Object { $_.Description -notmatch 'OffensiveLab' }).Count -eq 0)
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    $pct   = if ($script:total -gt 0) { [math]::Round(($script:score / $script:total) * 100) } else { 0 }
    $grade = if ($pct -ge 90) { 'A - Excellent' } elseif ($pct -ge 75) { 'B - Bien' } elseif ($pct -ge 60) { 'C - Correct' } else { 'D - A completer' }
    $col   = if ($pct -ge 90) { 'Green' } elseif ($pct -ge 75) { 'Yellow' } else { 'Red' }
    Write-Host "  Score OffensiveLab : $script:score / $script:total  ($pct%)  ->  $grade" -ForegroundColor $col
    Write-Host "========================================" -ForegroundColor Cyan
}
#endregion

#region -- Cleanup ------------------------------------------------------------
function Invoke-Cleanup {
    Write-Step "=== CLEANUP : Suppression de l'OU OffensiveLab ==="
    Initialize-Context

    $ou = Get-OffensiveLabOU
    if (-not $ou) {
        Write-OK "Aucun nettoyage necessaire : OU absente"
        return
    }

    Get-ADObject -SearchBase $script:LabOU -LDAPFilter '(objectClass=*)' -Properties ProtectedFromAccidentalDeletion |
        Sort-Object DistinguishedName -Descending |
        ForEach-Object {
            try {
                Set-ADObject -Identity $_.DistinguishedName -ProtectedFromAccidentalDeletion $false -ErrorAction SilentlyContinue
            } catch {}
        }

    Remove-ADObject -Identity $script:LabOU -Recursive -Confirm:$false
    Write-LabEvent -EventId 9299 -Message 'OffensiveLab cleanup completed'
    Write-OK "OU supprimee : $script:LabOU"
    Write-Info "Les rapports dans $OutputDir sont conserves."
}
#endregion

#region -- Main ---------------------------------------------------------------
Write-Host "+==============================================================+" -ForegroundColor Cyan
Write-Host "|   MODULE 20 - Securite offensive controlee / Purple Team     |" -ForegroundColor Cyan
Write-Host "|   Domaine : $DomainName  |  Serveur : $env:COMPUTERNAME" -ForegroundColor Cyan
Write-Host "+==============================================================+" -ForegroundColor Cyan

switch ($Module) {
    'Prepare'  { Invoke-Prepare }
    'Audit'    { Invoke-Audit }
    'Simulate' { Invoke-Simulate }
    'Detect'   { Invoke-Detect }
    'Validate' { Invoke-Validation }
    'Cleanup'  { Invoke-Cleanup }
    'All' {
        Invoke-Prepare
        Invoke-Audit
        Invoke-Simulate
        Invoke-Detect
        Invoke-Validation
    }
}
#endregion
