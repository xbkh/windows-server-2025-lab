#Requires -RunAsAdministrator
<#
.SYNOPSIS
    LANCEUR PRINCIPAL - Formation Windows Server 2025
    Execute les TPs avec documentation automatique (screenshots + rapport HTML/PDF)

.DESCRIPTION
    Ce script est le POINT D'ENTREE UNIQUE de la formation.
    Il appelle les scripts TP_0x_*.ps1 en injectant automatiquement
    la documentation a chaque etape importante.

.PARAMETER NomEtudiant
    Votre nom complet (apparait dans le rapport)

.PARAMETER Module
    Numero du module a executer (0 a 5), ou "Tous"

.PARAMETER GeneratePDF
    Generer un PDF en plus du HTML (necessite Chrome)

.EXAMPLE
    # Excuter le TP 00 (lab + AD) avec documentation :
    .\START-Formation.ps1 -NomEtudiant "Jean Dupont" -Module 0

    # Excuter TOUS les modules d'un coup :
    .\START-Formation.ps1 -NomEtudiant "Jean Dupont" -Module Tous -GeneratePDF

    # Validation finale uniquement :
    .\START-Formation.ps1 -NomEtudiant "Jean Dupont" -Module Validation
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$NomEtudiant,

    [ValidateSet("0","1","2","3","4","5","Tous","Validation")]
    [string]$Module = "0",

    [string]$DomainName     = "satom.local",
    [string]$StaticIP       = "192.168.100.10",
    [string]$InterfaceAlias = "Ethernet0",

    [switch]$GeneratePDF,

    [string]$OutputDir = "$env:USERPROFILE\Desktop\Rapports_Formation"
)

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

#region --- Initialisation ----------------------------------------------------
# Crer dossier de sortie
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# Importer le module de documentation
$docModulePath = Join-Path $PSScriptRoot "Doc-Module.psm1"
if (-not (Test-Path $docModulePath)) {
    Write-Error "Doc-Module.psm1 introuvable dans $PSScriptRoot. Assurez-vous que tous les fichiers sont presents."
    exit 1
}
Import-Module $docModulePath -Force

function Get-ScriptPath { param([string]$Name) Join-Path $PSScriptRoot $Name }

$moduleLabels = @{
    "0" = "Module 00-02 - Lab & Active Directory"
    "1" = "Module 03 - DHCP / DNS / Client"
    "2" = "Module 04-05 - OUs / Users / GPO"
    "3" = "Module 07-15 - Securite / LAPS / Hyper-V"
    "4" = "Module 16 - Azure Arc & Validation"
    "5" = "Module 20 - Securite offensive controlee"
    "Validation" = "Validation Globale"
    "Tous" = "Formation Complete"
}

$moduleToRun = if ($Module -eq "Tous") { @("0","1","2","3","4","5") } else { @($Module) }
#endregion

#region --- Bannire ----------------------------------------------------------
Clear-Host
Write-Host @"
+==============================================================+
|                                                              |
|      [BRAIN]  FORMATION WINDOWS SERVER 2025                      |
|         Administration Systeme - Documentation Auto         |
|                                                              |
+==============================================================+
|  Etudiant  : $($NomEtudiant.PadRight(45))|
|  Module(s) : $($moduleLabels[$Module].PadRight(45))|
|  Rapports  : $($OutputDir.PadRight(45))|
+==============================================================+
"@ -ForegroundColor Magenta

Write-Host "`n  Appuyez sur [Entree] pour demarrer..." -ForegroundColor Yellow
Read-Host | Out-Null
#endregion

foreach ($mod in $moduleToRun) {

    switch ($mod) {

        #region --- MODULE 0 : Lab + AD -----------------------------------------
        "0" {
            Start-LabDoc -Title $moduleLabels["0"] -StudentName $NomEtudiant -Module "TP 00/02"

            # -- Capture 1 : tat rseau initial -----------------------------
            Add-DocStep -Title "Verification de l'interface reseau" `
                        -Description "Interface reseau disponible avant configuration IP statique" `
                        -Command 'Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Format-Table Name,InterfaceDescription,LinkSpeed -AutoSize' `
                        -Screenshot -Status "info"

            Add-DocStep -Title "Configuration IP actuelle" `
                        -Command 'Get-NetIPAddress -AddressFamily IPv4 | Format-Table InterfaceAlias,IPAddress,PrefixLength,AddressState -AutoSize' `
                        -Screenshot -Status "info"

            # -- Excuter le TP 00 --------------------------------------------
            Add-DocStep -Title "Demarrage de la configuration post-installation" `
                        -Description "Execution de TP_00_Setup-Lab.ps1 : IP statique, renommage, AD DS" `
                        -Status "info"

            # On excute les tapes cls individuellement pour pouvoir capturer entre chaque
            Write-Host "`n  -- Etape : Configuration IP statique --" -ForegroundColor Cyan

            # IP Statique
            try {
                $currentIP = Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
                if ($currentIP -and $currentIP.IPAddress -ne $StaticIP) {
                    Remove-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -Confirm:$false -EA SilentlyContinue
                    Remove-NetRoute    -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -Confirm:$false -EA SilentlyContinue
                }
                New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $StaticIP -PrefixLength 24 -DefaultGateway "192.168.100.1" -EA SilentlyContinue | Out-Null
                Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses "127.0.0.1","$StaticIP"
                Add-DocStep -Title "IP statique configuree ($StaticIP)" `
                            -Command "Get-NetIPAddress -InterfaceAlias '$InterfaceAlias' -AddressFamily IPv4 | Format-Table IPAddress,PrefixLength,AddressState" `
                            -Screenshot -Status "success" `
                            -CheckItems @("IP : $StaticIP/24","DNS : 127.0.0.1 (loopback)","Passerelle : 192.168.100.1")
            } catch {
                Add-DocStep -Title "Configuration IP - erreur" -Output $_.Exception.Message -Status "error"
            }

            # Renommage
            $serverName = "DC01"
            if ($env:COMPUTERNAME -ne $serverName) {
                try {
                    Rename-Computer -NewName $serverName -Force -EA SilentlyContinue
                    Add-DocStep -Title "Serveur renomme en $serverName" `
                                -Screenshot -Status "success" `
                                -CheckItems @("Nouveau nom : $serverName","Effectif apres redemarrage")
                } catch {
                    Add-DocStep -Title "Renommage - deja effectue ou erreur" -Status "warning"
                }
            } else {
                Add-DocStep -Title "Nom du serveur : $serverName (deja configure)" -Status "success" -Screenshot
            }

            # Activation RDP
            Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -Value 0
            Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -EA SilentlyContinue
            Add-DocStep -Title "RDP active" `
                        -Command 'Get-NetFirewallRule -DisplayGroup "Remote Desktop" | Select-Object Name,Enabled,Action | Format-Table -AutoSize' `
                        -Screenshot -Status "success"

            # Installation AD DS
            Add-DocStep -Title "Debut installation role AD DS" `
                        -Description "Installation du role Active Directory Domain Services et des outils RSAT associes" `
                        -Status "info" -Screenshot

            $adFeature = Get-WindowsFeature -Name AD-Domain-Services
            if ($adFeature.InstallState -ne "Installed") {
                Install-WindowsFeature -Name AD-Domain-Services,RSAT-AD-Tools,GPMC,RSAT-DNS-Server,RSAT-DHCP -IncludeManagementTools
                Add-DocStep -Title "Role AD DS installe avec succes" `
                            -Command 'Get-WindowsFeature AD-Domain-Services,RSAT-AD-Tools,GPMC | Select-Object Name,InstallState | Format-Table -AutoSize' `
                            -Screenshot -Status "success"
            } else {
                Add-DocStep -Title "Role AD DS deja installe" `
                            -Command 'Get-WindowsFeature AD-Domain-Services | Select-Object Name,InstallState | Format-Table -AutoSize' `
                            -Screenshot -Status "success"
            }

            # Promotion AD
            Add-DocStep -Title "Promotion en controleur de domaine (nouvelle foret)" `
                        -Description "Creation de la foret $DomainName. Le serveur redemarrera automatiquement apres cette etape." `
                        -CheckItems @(
                            "Foret : $DomainName",
                            "Niveau fonctionnel : WinThreshold (WS2016+)",
                            "DNS integre : Oui",
                            "SYSVOL : C:\Windows\SYSVOL"
                        ) `
                        -Screenshot -Status "warning"

            # Gnrer rapport intermdiaire avant le redmarrage
            $reportPath = "$OutputDir\TP00_PreReboot_$(Get-Date -Format 'HHmm').html"
            New-LabReport -OutputPath $reportPath $(if ($GeneratePDF) {"-AsPdf"}) -StudentName $NomEtudiant
            Write-Host "`n  [SAVE] Rapport sauvegarde avant redemarrage : $reportPath" -ForegroundColor Green

            # Lancer la promotion relle
            $spasswd = ConvertTo-SecureString "P@ssw0rd2025!" -AsPlainText -Force
            Import-Module ADDSDeployment
            Install-ADDSForest -DomainName $DomainName -DomainMode WinThreshold -ForestMode WinThreshold `
                               -InstallDns:$true -SafeModeAdministratorPassword $spasswd `
                               -CreateDnsDelegation:$false -DatabasePath "C:\Windows\NTDS" `
                               -SysvolPath "C:\Windows\SYSVOL" -LogPath "C:\Windows\NTDS" `
                               -NoRebootOnCompletion:$false -Force:$true
        }
        #endregion

        #region --- MODULE 1 : DHCP / DNS ---------------------------------------
        "1" {
            Start-LabDoc -Title $moduleLabels["1"] -StudentName $NomEtudiant -Module "TP 03"

            Add-DocStep -Title "Verification Active Directory" `
                        -Command 'Get-ADDomain | Select-Object DNSRoot,DomainMode,PDCEmulator | Format-List' `
                        -Screenshot -Status "success"

            # Excuter TP_01 et capturer les tapes cls
            & (Get-ScriptPath "TP_01_DHCP-DNS-Client.ps1") -DomainName $DomainName

            # Documenter le rsultat
            Invoke-DocCheck -Module "DHCP & DNS" -Checks @(
                @{Title="Service DHCP actif";             Command='Get-Service DHCPServer | Select-Object Name,Status,StartType'},
                @{Title="Etendue DHCP configuree";        Command='Get-DhcpServerv4Scope | Format-Table ScopeId,Name,StartRange,EndRange,State -AutoSize'},
                @{Title="Options DHCP de l''etendue";     Command='Get-DhcpServerv4OptionValue -ScopeId 192.168.100.0 | Format-Table OptionId,Name,Value -AutoSize'},
                @{Title="Zone DNS forward";               Command="Get-DnsServerZone -Name '$DomainName' | Format-Table ZoneName,ZoneType,DynamicUpdate,IsADIntegrated -AutoSize"},
                @{Title="Zone DNS inversee";              Command='Get-DnsServerZone | Where-Object {$_.IsReverseLookupZone} | Format-Table ZoneName,ZoneType -AutoSize'},
                @{Title="Enregistrements DNS (A/PTR)";   Command="Get-DnsServerResourceRecord -ZoneName '$DomainName' -RRType A | Select-Object HostName,RecordType,@{N='IP';E={`$_.RecordData.IPv4Address}} | Format-Table -AutoSize"},
                @{Title="Forwarders DNS";                 Command='Get-DnsServerForwarder | Format-Table IPAddress,TimeoutInterval'}
            )

            $reportPath = "$OutputDir\TP01_DHCP-DNS_$(Get-Date -Format 'HHmm').html"
            New-LabReport -OutputPath $reportPath $(if ($GeneratePDF) {"-AsPdf"}) -StudentName $NomEtudiant
        }
        #endregion

        #region --- MODULE 2 : OUs / Users / GPO --------------------------------
        "2" {
            Start-LabDoc -Title $moduleLabels["2"] -StudentName $NomEtudiant -Module "TP 04/05"

            # Excuter TP_02
            & (Get-ScriptPath "TP_02_AD-OUs-Users-GPO.ps1") -DomainName $DomainName

            $DC = "DC=" + ($DomainName.Split(".") -join ",DC=")

            Invoke-DocCheck -Module "Active Directory - OUs / Users / GPO" -Checks @(
                @{Title="Arborescence OUs creee";
                  Command="Get-ADOrganizationalUnit -Filter * -SearchBase 'OU=_SATOM,$DC' | Sort-Object DistinguishedName | Select-Object -ExpandProperty DistinguishedName"},
                @{Title="Utilisateurs du domaine";
                  Command="Get-ADUser -Filter * -SearchBase 'OU=_SATOM,$DC' -Properties Department | Select-Object Name,SamAccountName,Department,Enabled | Format-Table -AutoSize"},
                @{Title="Groupes de securite";
                  Command="Get-ADGroup -Filter {Name -like 'GRP_*'} | Select-Object Name,GroupScope,GroupCategory | Format-Table -AutoSize"},
                @{Title="Membres du groupe Admins IT";
                  Command="Get-ADGroupMember 'GRP_Admins_IT' | Select-Object Name,SamAccountName,objectClass | Format-Table -AutoSize"},
                @{Title="GPOs appliquees";
                  Command='Get-GPO -All | Where-Object {$_.DisplayName -like "GPO-*"} | Select-Object DisplayName,GpoStatus,ModificationTime | Format-Table -AutoSize'},
                @{Title="Resultats GPO (gpresult)";
                  Command='gpresult /r /scope computer 2>&1'},
                @{Title="Politique de mot de passe du domaine";
                  Command="Get-ADDefaultDomainPasswordPolicy -Identity '$DomainName' | Format-List"}
            )

            # Screenshot du Centre d'administration AD (si ouvert)
            Write-Host "`n  [TIP] Ouvrez 'Utilisateurs et ordinateurs Active Directory' et appuyez sur Entree..." -ForegroundColor Yellow
            Add-DocManualScreenshot -Title "Console ADUC - Arborescence Active Directory"

            $reportPath = "$OutputDir\TP02_OUs-GPO_$(Get-Date -Format 'HHmm').html"
            New-LabReport -OutputPath $reportPath $(if ($GeneratePDF) {"-AsPdf"}) -StudentName $NomEtudiant
        }
        #endregion

        #region --- MODULE 3 : Scurit / LAPS / Hyper-V ------------------------
        "3" {
            Start-LabDoc -Title $moduleLabels["3"] -StudentName $NomEtudiant -Module "TP 03"

            # LAPS
            & (Get-ScriptPath "TP_03_Securite-LAPS-HyperV.ps1") -Module "LAPS"

            Invoke-DocCheck -Module "Windows LAPS" -Checks @(
                @{Title="Attributs LAPS dans le schema AD";
                  Command='Get-ADObject -SearchBase (Get-ADRootDSE).schemaNamingContext -Filter {ldapDisplayName -eq "msLAPS-Password"} | Select-Object Name,DistinguishedName'},
                @{Title="GPO LAPS configuree";
                  Command='Get-GPO -Name "GPO-LAPS-Configuration" -ErrorAction SilentlyContinue | Format-List DisplayName,GpoStatus,ModificationTime'},
                @{Title="Droits LAPS sur les OUs";
                  Command='Get-ADOrganizationalUnit -Filter * -SearchBase "OU=_SATOM,DC=satom,DC=local" | ForEach-Object { $_.DistinguishedName }'}
            )

            # Scurit
            & (Get-ScriptPath "TP_03_Securite-LAPS-HyperV.ps1") -Module "Securite"

            Invoke-DocCheck -Module "Securite avancee" -Checks @(
                @{Title="SMBv1 desactive";
                  Command='Get-SmbServerConfiguration | Select-Object EnableSMB1Protocol,EnableSMB2Protocol,RequireSecuritySignature,EncryptData'},
                @{Title="Regles de pare-feu AD";
                  Command='Get-NetFirewallRule | Where-Object {$_.DisplayName -like "AD-*"} | Select-Object DisplayName,Enabled,Action,Direction | Format-Table -AutoSize'},
                @{Title="Audit avance - categories actives";
                  Command='auditpol /get /category:* 2>&1 | Select-Object -First 30'},
                @{Title="LM Compatibility Level (protection NTLM)";
                  Command='Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Lsa | Select-Object LmCompatibilityLevel'},
                @{Title="WDigest desactive";
                  Command='Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest | Select-Object UseLogonCredential'}
            )

            # Hyper-V
            & (Get-ScriptPath "TP_03_Securite-LAPS-HyperV.ps1") -Module "HyperV"

            Invoke-DocCheck -Module "Hyper-V" -Checks @(
                @{Title="Role Hyper-V installe";
                  Command='Get-WindowsFeature Hyper-V | Select-Object Name,InstallState,FeatureType'},
                @{Title="Switches virtuels";
                  Command='Get-VMSwitch | Select-Object Name,SwitchType,NetAdapterInterfaceDescription | Format-Table -AutoSize'},
                @{Title="VMs creees";
                  Command='Get-VM | Select-Object Name,State,Generation,MemoryStartup,ProcessorCount | Format-Table -AutoSize'}
            )

            Write-Host "`n  [TIP] Ouvrez le Gestionnaire Hyper-V et appuyez sur Entree..." -ForegroundColor Yellow
            Add-DocManualScreenshot -Title "Console Hyper-V Manager"

            $reportPath = "$OutputDir\TP03_Securite-LAPS-HyperV_$(Get-Date -Format 'HHmm').html"
            New-LabReport -OutputPath $reportPath $(if ($GeneratePDF) {"-AsPdf"}) -StudentName $NomEtudiant
        }
        #endregion

        #region --- MODULE 4 / VALIDATION ---------------------------------------
        "4" {
            Start-LabDoc -Title $moduleLabels["4"] -StudentName $NomEtudiant -Module "TP 04/Validation"

            # Excuter la validation et capturer le score
            Add-DocStep -Title "Lancement de la validation globale" `
                        -Description "Execution de tous les tests de validation des modules 00 a 16" `
                        -Screenshot -Status "info"

            $validOutput = & (Get-ScriptPath "TP_04_AzureArc-Synthese.ps1") -ValidationOnly 2>&1 | Out-String
            Add-DocStep -Title "Resultats validation globale" `
                        -Output $validOutput `
                        -Screenshot -Status "info"

            Invoke-DocCheck -Module "Synthese finale" -Checks @(
                @{Title="Controleurs de domaine";           Command='Get-ADDomainController -Filter * | Select-Object Name,IPv4Address,Site,IsGlobalCatalog | Format-Table -AutoSize'},
                @{Title="Replication AD";                   Command='Get-ADReplicationPartnerMetadata * | Select-Object Server,LastReplicationSuccess,LastReplicationResult | Format-Table -AutoSize'},
                @{Title="Evenements critiques (24h)";       Command='Get-WinEvent -FilterHashtable @{LogName="System";Level=1,2;StartTime=(Get-Date).AddHours(-24)} -MaxEvents 10 -EA SilentlyContinue | Select-Object TimeCreated,Message | Format-Table -Wrap -AutoSize'},
                @{Title="Services Active Directory";        Command='Get-Service ADWS,DNS,NETLOGON,KDC,W32Time,DHCPServer | Select-Object Name,Status,StartType | Format-Table -AutoSize'},
                @{Title="Utilisation CPU/RAM";              Command='@{CPU=(Get-WmiObject Win32_Processor|Measure-Object LoadPercentage -Avg).Average; RAM=[math]::Round((1-(Get-WmiObject Win32_OS).FreePhysicalMemory/(Get-WmiObject Win32_OS).TotalVisibleMemorySize)*100,1)} | Format-List'},
                @{Title="Espace disque";                    Command='Get-PSDrive -PSProvider FileSystem | Select-Object Name,@{N="Used(GB)";E={[math]::Round($_.Used/1GB,1)}},@{N="Free(GB)";E={[math]::Round($_.Free/1GB,1)}} | Format-Table -AutoSize'}
            )

            $reportPath = "$OutputDir\TP04_Validation-Finale_$(Get-Date -Format 'HHmm').html"
            New-LabReport -OutputPath $reportPath $(if ($GeneratePDF) {"-AsPdf"}) -StudentName $NomEtudiant
        }
        #endregion

        #region --- MODULE 5 : Securite offensive controlee --------------------
        "5" {
            Start-LabDoc -Title $moduleLabels["5"] -StudentName $NomEtudiant -Module "TP 08"

            $offensiveOut = Join-Path $OutputDir "OffensiveLab"

            Add-DocStep -Title "Demarrage du TP securite offensive controlee" `
                        -Description "Creation d'une OU OffensiveLab, activation des audits, simulation defensive et rapport de detection" `
                        -Status "info" -Screenshot

            & (Get-ScriptPath "TP_08_Securite-Offensive.ps1") -Module "All" -DomainName $DomainName -OutputDir $offensiveOut

            Invoke-DocCheck -Module "Securite offensive controlee" -Checks @(
                @{Title="OU OffensiveLab";
                  Command='Get-ADOrganizationalUnit -LDAPFilter "(ou=OffensiveLab)" | Select-Object Name,DistinguishedName | Format-List'},
                @{Title="Comptes de test OffensiveLab";
                  Command='Get-ADUser -Filter {SamAccountName -like "olab.*" -or SamAccountName -eq "svc-ol-web"} -Properties ServicePrincipalName,Enabled,Description | Select-Object SamAccountName,Enabled,Description,@{N="SPN";E={$_.ServicePrincipalName -join ";"}} | Format-Table -AutoSize'},
                @{Title="Groupes privilegies surveilles";
                  Command='$d=(Get-ADDomain).DomainSID.Value; Get-ADGroup -Filter * -Properties SID | Where-Object {$_.SID.Value -in @("$d-512","$d-519","S-1-5-32-544")} | Select-Object Name,SID | Format-Table -AutoSize'},
                @{Title="Comptes sans preauth Kerberos";
                  Command='Get-ADUser -LDAPFilter "(&(objectCategory=person)(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=4194304))" -Properties Description,Enabled | Select-Object SamAccountName,Enabled,Description | Format-Table -AutoSize'},
                @{Title="Evenements de simulation OffensiveLab";
                  Command='Get-WinEvent -FilterHashtable @{LogName="Application";ProviderName="SATOM-OffensiveLab";StartTime=(Get-Date).AddHours(-4)} -MaxEvents 20 -EA SilentlyContinue | Select-Object TimeCreated,Id,Message | Format-Table -Wrap -AutoSize'},
                @{Title="Rapports generes";
                  Command="Get-ChildItem '$offensiveOut' -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 10 FullName,Length,LastWriteTime | Format-Table -AutoSize"}
            )

            $reportPath = "$OutputDir\TP08_Securite-Offensive_$(Get-Date -Format 'HHmm').html"
            New-LabReport -OutputPath $reportPath $(if ($GeneratePDF) {"-AsPdf"}) -StudentName $NomEtudiant
        }
        #endregion

        "Validation" {
            # Validation seule sans rapport
            & (Get-ScriptPath "TP_04_AzureArc-Synthese.ps1") -ValidationOnly
        }
    }
}

#region --- Rapport consolid final (si Tous) ---------------------------------
if ($Module -eq "Tous") {
    Write-Host @"

+==============================================================+
|  [OK]  Tous les modules ont ete executes et documentes         |
|     Rapports disponibles dans : $OutputDir                   
+==============================================================+
"@ -ForegroundColor Green

    # Lister tous les rapports gnrs
    Get-ChildItem $OutputDir -Filter "*.html" | Sort-Object LastWriteTime |
        ForEach-Object { Write-Host "    [FILE] $($_.Name)" -ForegroundColor Gray }
}
#endregion
