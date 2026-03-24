#Requires -RunAsAdministrator
<#
.SYNOPSIS
    TP Modules 07-15 : LAPS, Securite avancee, Hyper-V & PowerShell
    Formation Windows Server 2025

.DESCRIPTION
    Ce script couvre :
        Module 07  - Windows LAPS (Local Administrator Password Solution)
        Module 08  - Sites Active Directory
        Module 10  - Windows Admin Center
        Module 11  - Automatisation PowerShell & WinGet
        Module 12  - Optimisations performances
        Module 13  - Disponibilite (snapshots, monitoring)
        Module 14  - Securite avancee (OSConfig, Credential Guard, SMB hardening)
        Module 15  - Hyper-V (VM automatisee)

.EXAMPLE
    # Excuter tout :
    .\TP_03_Securite-LAPS-HyperV.ps1

    # Choisir un module spcifique :
    .\TP_03_Securite-LAPS-HyperV.ps1 -Module LAPS
    .\TP_03_Securite-LAPS-HyperV.ps1 -Module HyperV
    .\TP_03_Securite-LAPS-HyperV.ps1 -Module Securite
#>

[CmdletBinding()]
param(
    [ValidateSet("Tous","LAPS","Sites","Winget","Performances","Securite","HyperV")]
    [string]$Module = "Tous",
    [string]$DomainName = "satom.local"
)

#region --- Helpers -----------------------------------------------------------
function Write-Step { param([string]$M) Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] -> $M" -ForegroundColor Cyan }
function Write-OK   { param([string]$M) Write-Host "  [OK] $M" -ForegroundColor Green  }
function Write-Warn { param([string]$M) Write-Host "  [!] $M" -ForegroundColor Yellow }
function Write-Info { param([string]$M) Write-Host "  [i] $M" -ForegroundColor Blue  }
function Invoke-Module { param([string]$Name, [scriptblock]$Code)
    if ($Module -eq "Tous" -or $Module -eq $Name) { & $Code }
    else { Write-Info "Module '$Name' ignore (selectionne: $Module)" }
}
#endregion

Write-Host @"
+==============================================================+
|  FORMATION WS2025 - TP 03 : Securite / LAPS / Hyper-V      |
|  Module selectionne : $Module                                
+==============================================================+
"@ -ForegroundColor Magenta

#region =======================================================================
#  MODULE 07  WINDOWS LAPS
# ============================================================================
Invoke-Module -Name "LAPS" -Code {
    Write-Step "MODULE 07 - Configuration Windows LAPS"
    Import-Module ActiveDirectory

    # 1. Mettre  jour le schma AD pour LAPS
    Write-Info "Mise a jour du schema AD pour LAPS..."
    try {
        Update-LapsADSchema -Verbose
        Write-OK "Schema AD LAPS mis a jour"
    } catch {
        Write-Warn "Schema LAPS deja a jour ou erreur : $($_.Exception.Message)"
    }

    # 2. Activer LAPS sur les OUs cibles (tous les ordinateurs du domaine)
    $DC = "DC=" + ($DomainName.Split(".") -join ",DC=")
    $OUsCibles = @(
        "OU=Serveurs,OU=_SATOM,$DC",
        "OU=Paris,OU=_SATOM,$DC",
        "OU=Bordeaux,OU=_SATOM,$DC"
    )

    foreach ($ou in $OUsCibles) {
        try {
            Set-LapsADComputerSelfPermission -Identity $ou
            Write-OK "Permissions LAPS definies sur : $ou"
        } catch {
            Write-Warn "Erreur sur $ou : $($_.Exception.Message)"
        }
    }

    # 3. Crer une GPO LAPS
    $gpoLaps = "GPO-LAPS-Configuration"
    try {
        Import-Module GroupPolicy
        $gpo = New-GPO -Name $gpoLaps -Comment "Windows LAPS - Rotation auto mot de passe admin local" -ErrorAction Stop
        Write-OK "GPO LAPS creee : $gpoLaps"

        # Activer LAPS via registry
        Set-GPRegistryValue -Name $gpoLaps `
            -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\LAPS\Config" `
            -ValueName "BackupDirectory" -Type DWord -Value 2 | Out-Null   # 2 = Active Directory

        Set-GPRegistryValue -Name $gpoLaps `
            -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\LAPS\Config" `
            -ValueName "PasswordAgeDays" -Type DWord -Value 30 | Out-Null

        Set-GPRegistryValue -Name $gpoLaps `
            -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\LAPS\Config" `
            -ValueName "PasswordLength" -Type DWord -Value 20 | Out-Null

        Set-GPRegistryValue -Name $gpoLaps `
            -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\LAPS\Config" `
            -ValueName "PasswordComplexity" -Type DWord -Value 4 | Out-Null  # 4 = Majuscules+Minuscules+Chiffres+Symboles

        Set-GPRegistryValue -Name $gpoLaps `
            -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\LAPS\Config" `
            -ValueName "AdministratorAccountName" -Type String -Value "admin" | Out-Null

        # Lier au domaine entier
        New-GPLink -Name $gpoLaps -Target $DC -LinkEnabled Yes -ErrorAction SilentlyContinue | Out-Null
        Write-OK "GPO LAPS liee au domaine"
    } catch {
        Write-Warn "GPO LAPS deja existante ou erreur"
    }

    # 4. Simuler la rcupration du mot de passe LAPS (depuis le DC)
    Write-Info "Point de controle : recuperer un mot de passe LAPS :"
    Write-Host "    Get-LapsADPassword -Identity 'PC01' -AsPlainText" -ForegroundColor Gray
    Write-Host "    Get-LapsADPassword -Identity 'DC01' -AsPlainText" -ForegroundColor Gray
}
#endregion

#region =======================================================================
#  MODULE 08  SITES ACTIVE DIRECTORY
# ============================================================================
Invoke-Module -Name "Sites" -Code {
    Write-Step "MODULE 08 - Creation des sites Active Directory"
    Import-Module ActiveDirectory

    $sites = @(
        @{Name="Site-Paris";     Subnet="192.168.100.0/24"; LinkName="Lien-Paris-Bordeaux"},
        @{Name="Site-Bordeaux";  Subnet="192.168.200.0/24"; LinkName="Lien-Paris-Bordeaux"}
    )

    # Crer les sites
    foreach ($s in $sites) {
        try {
            New-ADReplicationSite -Name $s.Name -ErrorAction Stop
            Write-OK "Site AD cree : $($s.Name)"
        } catch {
            Write-Warn "Site deja existant : $($s.Name)"
        }

        try {
            New-ADReplicationSubnet -Name $s.Subnet -Site $s.Name -ErrorAction Stop
            Write-OK "Sous-reseau $($s.Subnet) associe au site $($s.Name)"
        } catch {
            Write-Warn "Sous-reseau deja existant : $($s.Subnet)"
        }
    }

    # Crer le lien de site
    try {
        New-ADReplicationSiteLink -Name "Lien-Paris-Bordeaux" `
            -SitesIncluded "Site-Paris","Site-Bordeaux" `
            -Cost 100 `
            -ReplicationFrequencyInMinutes 15 `
            -InterSiteTransportProtocol IP `
            -ErrorAction Stop
        Write-OK "Lien de site cree : Paris <-> Bordeaux (toutes les 15 min)"
    } catch {
        Write-Warn "Lien de site deja existant"
    }

    # Dplacer le DC dans le site Paris
    $server = (Get-ADDomainController).Name
    try {
        Move-ADDirectoryServer -Identity $server -Site "Site-Paris"
        Write-OK "DC '$server' deplace dans Site-Paris"
    } catch {
        Write-Warn "Deplacement DC : $($_.Exception.Message)"
    }
}
#endregion

#region =======================================================================
#  MODULE 11  AUTOMATISATION POWERSHELL & WINGET
# ============================================================================
Invoke-Module -Name "Winget" -Code {
    Write-Step "MODULE 11 - PowerShell automatisation & WinGet"

    # -- WinGet : installer des outils d'administration ----------------------
    $toolsToInstall = @(
        @{Id="Microsoft.WindowsTerminal";    Name="Windows Terminal"},
        @{Id="Microsoft.PowerShell";         Name="PowerShell 7"},
        @{Id="Notepad++.Notepad++";          Name="Notepad++"},
        @{Id="Microsoft.VisualStudioCode";   Name="VS Code"}
    )

    Write-Info "Installation des outils via WinGet..."
    foreach ($tool in $toolsToInstall) {
        Write-Info "Installation : $($tool.Name)..."
        try {
            winget install --id $tool.Id --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
            Write-OK "$($tool.Name) installe"
        } catch {
            Write-Warn "WinGet non disponible ou erreur pour $($tool.Name)"
        }
    }

    # -- Exemple de script de cration d'utilisateurs en masse (CSV) ---------
    $csvContent = @"
Prenom,Nom,Departement,Site
Jean,Dupuis,Comptabilite,Paris
Marie,Lambert,Marketing,Paris
Pierre,Morin,IT,Bordeaux
Sophie,Leroy,RH,Bordeaux
"@
    $csvPath = "$env:TEMP\utilisateurs_import.csv"
    $csvContent | Out-File -Encoding UTF8 $csvPath

    Write-OK "Modele CSV cree : $csvPath"
    Write-Info "Utilisation du CSV pour creer des utilisateurs en masse :"

    $DC = "DC=" + ($DomainName.Split(".") -join ",DC=")
    Import-Csv $csvPath | ForEach-Object {
        $sam = "$($_.Prenom.ToLower()).$($_.Nom.ToLower())"
        $ou  = "OU=Utilisateurs,OU=$($_.Site),OU=_SATOM,$DC"
        $pass = ConvertTo-SecureString "Satom@2025!Lab" -AsPlainText -Force

        if (-not (Get-ADUser -Filter {SamAccountName -eq $sam} -ErrorAction SilentlyContinue)) {
            try {
                New-ADUser -GivenName $_.Prenom -Surname $_.Nom `
                           -Name "$($_.Prenom) $($_.Nom)" `
                           -SamAccountName $sam `
                           -UserPrincipalName "$sam@$DomainName" `
                           -Department $_.Departement `
                           -Path $ou `
                           -AccountPassword $pass `
                           -ChangePasswordAtLogon $true `
                           -Enabled $true `
                           -ErrorAction Stop
                Write-OK "Utilisateur importe : $sam ($($_.Departement), $($_.Site))"
            } catch {
                Write-Warn "Erreur pour $sam : $($_.Exception.Message)"
            }
        } else {
            Write-Warn "Utilisateur deja existant : $sam"
        }
    }

    # -- Script de rapport quotidien (tche planifie) ------------------------
    $reportScript = @'
$date = Get-Date -Format "yyyy-MM-dd"
$report = "$env:USERPROFILE\Desktop\rapport_ad_$date.html"

$users = Get-ADUser -Filter * -Properties LastLogonDate, Department, Enabled |
    Select-Object Name, SamAccountName, Department, Enabled, 
    @{N="DerniereConnexion";E={if($_.LastLogonDate){$_.LastLogonDate.ToString("dd/MM/yyyy HH:mm")}else{"Jamais"}}}

$html = @"
<html><body>
<h1>Rapport AD - $date</h1>
<table border='1'>
<tr><th>Nom</th><th>Login</th><th>Dept</th><th>Actif</th><th>Derniere connexion</th></tr>
$(foreach ($u in $users) {
"<tr><td>$($u.Name)</td><td>$($u.SamAccountName)</td><td>$($u.Department)</td><td>$($u.Enabled)</td><td>$($u.DerniereConnexion)</td></tr>"
})
</table></body></html>
"@
$html | Out-File $report -Encoding UTF8
Write-Host "Rapport genere : $report"
'@

    $scriptPath = "C:\Scripts\rapport_ad.ps1"
    New-Item -ItemType Directory -Path "C:\Scripts" -Force | Out-Null
    $reportScript | Out-File -Encoding UTF8 $scriptPath
    Write-OK "Script de rapport cree : $scriptPath"

    # Crer une tche planifie pour ce rapport (tous les jours  8h)
    $action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -Daily -At "08:00"
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount

    Register-ScheduledTask -TaskName "Rapport_AD_Quotidien" `
        -Action $action -Trigger $trigger -Principal $principal `
        -Description "Genere un rapport HTML des utilisateurs AD" `
        -Force | Out-Null
    Write-OK "Tache planifiee creee : 'Rapport_AD_Quotidien' (tous les jours a 8h)"
}
#endregion

#region =======================================================================
#  MODULE 12/13  PERFORMANCES & DISPONIBILIT
# ============================================================================
Invoke-Module -Name "Performances" -Code {
    Write-Step "MODULE 12/13 - Optimisations performances & disponibilite"

    # -- Optimisations recommandes WS2025 -----------------------------------

    # Plan d'alimentation haute performance
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-Null
    Write-OK "Plan d'alimentation : Haute performance active"

    # Dsactiver l'hibernation (inutile sur serveur)
    powercfg /h off 2>&1 | Out-Null
    Write-OK "Hibernation desactivee"

    # Optimiser la mmoire virtuelle (dsactiver le fichier d'change auto sur petit lab)
    # En production : laisser Windows grer le pagefile
    Write-Info "Pagefile : laisse en gestion automatique (recommande)"

    # Activer la dduplication des donnes si rle FS prsent
    $dedup = Get-WindowsFeature -Name FS-Data-Deduplication -ErrorAction SilentlyContinue
    if ($dedup -and $dedup.InstallState -eq 'Installed') {
        Write-OK "Deduplication des donnees deja installee"
    } else {
        Write-Info "Pour activer la deduplication :"
        Write-Host '    Install-WindowsFeature FS-Data-Deduplication' -ForegroundColor Gray
        Write-Host '    Enable-DedupVolume -Volume "D:" -UsageType Default' -ForegroundColor Gray
    }

    # -- Monitoring & alertes ------------------------------------------------
    $monitorScript = @'
# Script de monitoring simplifi -  placer dans C:\Scripts\monitor.ps1
$threshold_cpu  = 80   # % CPU
$threshold_ram  = 85   # % RAM  
$threshold_disk = 90   # % Disque

# CPU
$cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
if ($cpu -gt $threshold_cpu) {
    Write-Warning "[!] CPU eleve : $cpu%"
}

# RAM
$ram = Get-CimInstance Win32_OperatingSystem
$ramUsed = [math]::Round(($ram.TotalVisibleMemorySize - $ram.FreePhysicalMemory) / $ram.TotalVisibleMemorySize * 100, 1)
if ($ramUsed -gt $threshold_ram) {
    Write-Warning "[!] RAM elevee : $ramUsed%"
}

# Disques
Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Used -and ($_.Used + $_.Free) -gt 0} | ForEach-Object {
    $used = [math]::Round($_.Used / ($_.Used + $_.Free) * 100, 1)
    if ($used -gt $threshold_disk) {
        Write-Warning "[!] Disque $($_.Name): ${used}% utilise"
    }
}

# Services critiques AD
$criticalServices = @("ADWS","DNS","DHCP","Netlogon","kdc","W32Time")
foreach ($svc in $criticalServices) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($s -and $s.Status -ne "Running") {
        Write-Warning "[!] Service $svc ARRETE -> Tentative de redemarrage..."
        Start-Service $svc -ErrorAction SilentlyContinue
    }
}
'@
    $monitorScript | Out-File -Encoding UTF8 "C:\Scripts\monitor.ps1"
    Write-OK "Script de monitoring cree : C:\Scripts\monitor.ps1"

    # Tche planifie pour le monitoring (toutes les 5 minutes)
    $action  = New-ScheduledTaskAction  -Execute "powershell.exe" -Argument "-File `"C:\Scripts\monitor.ps1`""
    $trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) -Once -At (Get-Date)
    Register-ScheduledTask -TaskName "Monitoring_Serveur" -Action $action -Trigger $trigger `
        -Principal (New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount) `
        -Force | Out-Null
    Write-OK "Monitoring automatique toutes les 5 minutes"
}
#endregion

#region =======================================================================
#  MODULE 14  SCURIT AVANCE & DURCISSEMENT
# ============================================================================
Invoke-Module -Name "Securite" -Code {
    Write-Step "MODULE 14 - Securite avancee (OSConfig, SMB Hardening, Credential Guard)"

    # -- SMB Hardening --------------------------------------------------------
    Write-Info "Durcissement SMB..."

    # Dsactiver SMBv1 (OBSOLTE et dangereux)
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
    Write-OK "SMBv1 desactive sur le serveur"

    # Activer la signature SMB (obligatoire)
    Set-SmbServerConfiguration -RequireSecuritySignature $true -Force
    Set-SmbClientConfiguration -RequireSecuritySignature $true -Force
    Write-OK "Signature SMB obligatoire (client + serveur)"

    # Activer le chiffrement SMB
    Set-SmbServerConfiguration -EncryptData $true -Force
    Write-OK "Chiffrement SMB active"

    # -- Audit avanc ---------------------------------------------------------
    Write-Info "Configuration de l'audit avance..."

    $auditCategories = @(
        "Account Logon",
        "Account Management",
        "DS Access",
        "Logon/Logoff",
        "Object Access",
        "Policy Change",
        "Privilege Use",
        "System"
    )

    foreach ($cat in $auditCategories) {
        auditpol /set /category:"$cat" /success:enable /failure:enable 2>&1 | Out-Null
    }
    Write-OK "Audit avance active pour toutes les categories requises"

    # -- Dsactiver protocoles faibles ----------------------------------------

    # Dsactiver NTLM v1 (garder NTLMv2 pour compatibilit, Kerberos prfr)
    $ntlmPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
    Set-ItemProperty -Path $ntlmPath -Name "LmCompatibilityLevel" -Value 5 -Type DWord
    Write-OK "LM Compatibility Level = 5 (NTLMv2 uniquement, Kerberos prefere)"

    # Dsactiver WDigest (empche le stockage des mots de passe en clair dans LSASS)
    $wdigestPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest"
    if (-not (Test-Path $wdigestPath)) { New-Item -Path $wdigestPath -Force | Out-Null }
    Set-ItemProperty -Path $wdigestPath -Name "UseLogonCredential" -Value 0 -Type DWord
    Write-OK "WDigest desactive (protection contre Pass-the-Hash)"

    # -- Credential Guard (WS2025 activ par dfaut, vrification) ------------
    $credGuardPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
    if (-not (Test-Path $credGuardPath)) { New-Item -Path $credGuardPath -Force | Out-Null }
    Set-ItemProperty -Path $credGuardPath -Name "EnableVirtualizationBasedSecurity" -Value 1 -Type DWord
    Set-ItemProperty -Path $credGuardPath -Name "RequirePlatformSecurityFeatures"   -Value 3 -Type DWord

    $credGuardCred = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
    Set-ItemProperty -Path $credGuardCred -Name "LsaCfgFlags" -Value 1 -Type DWord
    Write-OK "Credential Guard active (redemarrage requis)"

    # -- OSConfig  Baselines de scurit Microsoft ---------------------------
    Write-Info "OSConfig - Application de la security baseline..."

    if (Get-Command "Set-OSConfigDesiredConfiguration" -ErrorAction SilentlyContinue) {
        try {
            Set-OSConfigDesiredConfiguration -Scenario SecurityBaseline -Default
            Write-OK "OSConfig : Security Baseline Microsoft appliquee"
        } catch {
            Write-Warn "OSConfig erreur : $($_.Exception.Message)"
        }
    } else {
        Write-Warn "OSConfig non disponible. Telecharger via : winget install Microsoft.OSConfig"
        Write-Info "Alternative : appliquer manuellement via lgpo.exe (Microsoft Security Compliance Toolkit)"
    }

    # -- Pare-feu Windows -----------------------------------------------------
    Set-NetFirewallProfile -Profile Domain,Private,Public -NotifyOnListen True
    # Bloquer toutes connexions entrantes non-explicitement autorises (par profil Domain)
    Set-NetFirewallProfile -Profile Domain -DefaultInboundAction Block -DefaultOutboundAction Allow
    Write-OK "Pare-feu Windows : trafic entrant bloque par defaut (profil Domaine)"

    # Autoriser les ports critiques AD
    $fwRules = @(
        @{Name="AD-LDAP";      Port=389;  Protocol="TCP"},
        @{Name="AD-LDAPS";     Port=636;  Protocol="TCP"},
        @{Name="AD-Kerberos";  Port=88;   Protocol="TCP"},
        @{Name="AD-KerbUDP";   Port=88;   Protocol="UDP"},
        @{Name="AD-DNS-TCP";   Port=53;   Protocol="TCP"},
        @{Name="AD-DNS-UDP";   Port=53;   Protocol="UDP"},
        @{Name="AD-SMB";       Port=445;  Protocol="TCP"},
        @{Name="AD-NetLogon";  Port=49152; Protocol="TCP"},
        @{Name="AD-RPC";       Port=135;  Protocol="TCP"},
        @{Name="AD-WinRM";     Port=5985; Protocol="TCP"},
        @{Name="AD-WinRMSSL";  Port=5986; Protocol="TCP"}
    )

    foreach ($rule in $fwRules) {
        New-NetFirewallRule -DisplayName $rule.Name `
            -Direction Inbound -Protocol $rule.Protocol -LocalPort $rule.Port `
            -Action Allow -Profile Domain -ErrorAction SilentlyContinue | Out-Null
    }
    Write-OK "Regles de pare-feu creees pour les ports critiques AD/DNS/LDAP/Kerberos"
}
#endregion

#region =======================================================================
#  MODULE 15  HYPER-V
# ============================================================================
Invoke-Module -Name "HyperV" -Code {
    Write-Step "MODULE 15 - Installation & Configuration Hyper-V"

    # Vrifier si la virtualisation imbrique est disponible
    $vmInfo = Get-CimInstance Win32_Processor
    $vtx    = $vmInfo.VirtualizationFirmwareEnabled

    if (-not $vtx) {
        Write-Warn "Virtualisation materielle non detectee. Hyper-V necessite VT-x/AMD-V."
        Write-Info "Sur VMware : VM Settings > CPU > Expose hardware virtualization to guest OS"
    }

    # Installer Hyper-V
    $hyperv = Get-WindowsFeature -Name Hyper-V
    if ($hyperv.InstallState -ne 'Installed') {
        Install-WindowsFeature -Name Hyper-V -IncludeManagementTools
        Write-OK "Role Hyper-V installe (redemarrage requis)"
    } else {
        Write-OK "Hyper-V deja installe"
    }

    # Vrifier si on peut configurer Hyper-V maintenant
    if ($hyperv.InstallState -eq 'Installed') {
        Import-Module Hyper-V -ErrorAction SilentlyContinue

        # Crer un switch virtuel interne pour les VMs
        $switchName = "vSwitch-Interne"
        if (-not (Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue)) {
            New-VMSwitch -Name $switchName -SwitchType Internal
            Write-OK "Switch virtuel cree : $switchName (reseau interne)"
        } else {
            Write-OK "Switch '$switchName' deja existant"
        }

        # Crer un switch externe (accs rseau physique)
        $netAdapter = (Get-NetAdapter | Where-Object {$_.Status -eq "Up" -and $_.InterfaceDescription -notlike "*Virtual*"} | Select-Object -First 1)
        if ($netAdapter) {
            $extSwitchName = "vSwitch-Externe"
            if (-not (Get-VMSwitch -Name $extSwitchName -ErrorAction SilentlyContinue)) {
                New-VMSwitch -Name $extSwitchName -NetAdapterName $netAdapter.Name -AllowManagementOS $true
                Write-OK "Switch externe cree : $extSwitchName (via $($netAdapter.Name))"
            } else {
                Write-OK "Switch '$extSwitchName' deja existant"
            }
        }

        # Configurer l'emplacement par dfaut des VMs
        $vmPath   = "D:\VMs"
        $vhdxPath = "D:\VMs\VHDs"
        if (Test-Path "D:\") {
            New-Item -ItemType Directory -Path $vmPath   -Force | Out-Null
            New-Item -ItemType Directory -Path $vhdxPath -Force | Out-Null
            Set-VMHost -VirtualMachinePath $vmPath -VirtualHardDiskPath $vhdxPath
            Write-OK "Repertoire des VMs : $vmPath"
        } else {
            Write-Warn "Lecteur D: non disponible, VMs creees sur C: par defaut"
        }

        # -- Exemple : crer une VM de dmonstration -----------------------
        $vmName = "VM-Demo-WS2025"
        if (-not (Get-VM -Name $vmName -ErrorAction SilentlyContinue)) {
            $vhdSize = 40GB
            $vhdPath_demo = if (Test-Path "D:\") {"D:\VMs\VHDs\$vmName.vhdx"} else {"C:\VMs\VHDs\$vmName.vhdx"}
            New-Item -ItemType Directory -Path (Split-Path $vhdPath_demo) -Force | Out-Null

            New-VHD -Path $vhdPath_demo -SizeBytes $vhdSize -Dynamic | Out-Null

            $vm = New-VM -Name $vmName `
                         -MemoryStartupBytes 2GB `
                         -VHDPath $vhdPath_demo `
                         -Generation 2 `
                         -SwitchName $switchName

            # Configurer la VM
            Set-VM -Name $vmName -ProcessorCount 2 -DynamicMemory -MemoryMinimumBytes 1GB -MemoryMaximumBytes 4GB
            
            # Activer VBS (Virtualization Based Security) pour la VM
            Set-VMSecurity -VMName $vmName -VirtualizationBasedSecurityOptOut $false -ErrorAction SilentlyContinue

            Write-OK "VM creee : $vmName (Gen2, 2vCPU, 2-4GB RAM dynamique, 40GB VHDX)"
            Write-Info "Monter l'ISO WS2025 et demarrer la VM :"
            Write-Host "    Add-VMDvdDrive -VMName '$vmName' -Path 'C:\ISO\WS2025.iso'" -ForegroundColor Gray
            Write-Host "    Start-VM -Name '$vmName'" -ForegroundColor Gray
        } else {
            Write-OK "VM '$vmName' deja existante"
        }

        # -- Activer Hyper-V Replica (pour la HA) --------------------------
        $replicaPath = "C:\HyperVReplica"
        New-Item -ItemType Directory -Path $replicaPath -Force | Out-Null
        Set-VMReplicationServer -ReplicationEnabled $true `
            -AllowedAuthenticationType Kerberos `
            -ReplicationAllowedFromAnyServer $true `
            -DefaultStorageLocation $replicaPath `
            -ErrorAction SilentlyContinue
        Write-OK "Hyper-V Replica active (stockage : $replicaPath)"
    }
}
#endregion

Write-Host @"

+==========================================================+
|  [OK]  TP SECURITE / LAPS / HYPER-V TERMINE               |
+==========================================================+
|  ETAPE SUIVANTE :                                       |
|    .\TP_04_AzureArc-Synthese.ps1                        |
+==========================================================+
"@ -ForegroundColor Green
