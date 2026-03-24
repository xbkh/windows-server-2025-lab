#Requires -RunAsAdministrator
<#
.SYNOPSIS
    TP Module 04 + 05 - OUs, Utilisateurs, Groupes & GPO
    Formation Windows Server 2025

.DESCRIPTION
    Ce script cree l'arborescence AD complete (OUs, utilisateurs, groupes)
    et configure les GPO de securite pour la formation.

    Structure creee :
        satom.local
        -- _SATOM (OU racine entreprise)
            -- Serveurs
            -- Paris
               -- Utilisateurs
               -- Groupes
            -- Bordeaux
               -- Utilisateurs
               -- Groupes
            -- IT-Admins
                -- Utilisateurs
                -- Groupes

.EXAMPLE
    .\TP_02_AD-OUs-Users-GPO.ps1
    .\TP_02_AD-OUs-Users-GPO.ps1 -DomainName "mondomaine.local" -Verbose
#>

[CmdletBinding()]
param(
    [string]$DomainName       = "satom.local",
    [string]$DefaultPassword  = "Satom@2025!"    # Mot de passe initial des comptes
)

Import-Module ActiveDirectory
Import-Module GroupPolicy

#region --- Helpers -----------------------------------------------------------
function Write-Step { param([string]$M) Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] -> $M" -ForegroundColor Cyan }
function Write-OK   { param([string]$M) Write-Host "  [OK] $M" -ForegroundColor Green  }
function Write-Warn { param([string]$M) Write-Host "  [!] $M" -ForegroundColor Yellow }

function New-OUSafe {
    param([string]$Name, [string]$Path)
    try {
        New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true -ErrorAction Stop
        Write-OK "OU creee : OU=$Name,$Path"
    } catch [Microsoft.ActiveDirectory.Management.ADException] {
        Write-Warn "OU deja existante : OU=$Name,$Path"
    }
}

function New-UserSafe {
    param(
        [string]$FirstName,
        [string]$LastName,
        [string]$Department,
        [string]$OUPath
    )
    $sam     = "$($FirstName.ToLower()).$($LastName.ToLower())"
    $upn     = "$sam@$DomainName"
    $display = "$FirstName $LastName"
    $secure  = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force

    try {
        New-ADUser -GivenName $FirstName `
                   -Surname $LastName `
                   -Name $display `
                   -SamAccountName $sam `
                   -UserPrincipalName $upn `
                   -Department $Department `
                   -Path $OUPath `
                   -AccountPassword $secure `
                   -ChangePasswordAtLogon $true `
                   -Enabled $true `
                   -ErrorAction Stop
        Write-OK "Utilisateur cree : $sam ($Department)"
    } catch [Microsoft.ActiveDirectory.Management.ADException] {
        Write-Warn "Utilisateur deja existant : $sam"
    }
    return $sam
}
#endregion

$DC = "DC=" + ($DomainName.Split(".") -join ",DC=")

Write-Host @"
+=======================================================+
|   FORMATION WS2025 - TP 04/05 : OUs / Users / GPO   |
|   Domaine : $DomainName                               
+=======================================================+
"@ -ForegroundColor Magenta

#region --- TAPE 1 : Cration de l'arborescence OU -------------------------
Write-Step "ETAPE 1 - Creation de l'arborescence Unites d'Organisation"

# OU racine entreprise
New-OUSafe -Name "_SATOM"    -Path $DC

$ouRoot = "OU=_SATOM,$DC"

# OUs de premier niveau
@("Serveurs","Paris","Bordeaux","IT-Admins") | ForEach-Object {
    New-OUSafe -Name $_ -Path $ouRoot
}

# OUs de deuxime niveau (sous chaque site)
@("Paris","Bordeaux","IT-Admins") | ForEach-Object {
    $parentOU = "OU=$_,$ouRoot"
    New-OUSafe -Name "Utilisateurs" -Path $parentOU
    New-OUSafe -Name "Groupes"      -Path $parentOU
}
#endregion

#region --- TAPE 2 : Cration des groupes de scurit ----------------------
Write-Step "ETAPE 2 - Creation des groupes de securite"

$groups = @(
    @{Name="GRP_RH_Paris";         Scope="Global"; Path="OU=Groupes,OU=Paris,$ouRoot";       Desc="Groupe RH Paris"},
    @{Name="GRP_IT_Paris";         Scope="Global"; Path="OU=Groupes,OU=Paris,$ouRoot";       Desc="Groupe IT Paris"},
    @{Name="GRP_Direction_Paris";  Scope="Global"; Path="OU=Groupes,OU=Paris,$ouRoot";       Desc="Direction Paris"},
    @{Name="GRP_RH_Bordeaux";      Scope="Global"; Path="OU=Groupes,OU=Bordeaux,$ouRoot";    Desc="Groupe RH Bordeaux"},
    @{Name="GRP_IT_Bordeaux";      Scope="Global"; Path="OU=Groupes,OU=Bordeaux,$ouRoot";    Desc="Groupe IT Bordeaux"},
    @{Name="GRP_Admins_IT";        Scope="Global"; Path="OU=Groupes,OU=IT-Admins,$ouRoot";   Desc="Administrateurs IT - tous sites"},
    @{Name="GRP_Helpdesk";         Scope="Global"; Path="OU=Groupes,OU=IT-Admins,$ouRoot";   Desc="Helpdesk niveau 1/2"}
)

foreach ($g in $groups) {
    try {
        New-ADGroup -Name $g.Name `
                    -GroupScope $g.Scope `
                    -GroupCategory Security `
                    -Path $g.Path `
                    -Description $g.Desc `
                    -ErrorAction Stop
        Write-OK "Groupe cree : $($g.Name)"
    } catch {
        Write-Warn "Groupe deja existant : $($g.Name)"
    }
}
#endregion

#region --- TAPE 3 : Cration des utilisateurs -----------------------------
Write-Step "ETAPE 3 - Creation des comptes utilisateurs"

# Utilisateurs Paris  RH
$ouParisUsers = "OU=Utilisateurs,OU=Paris,$ouRoot"
$u1 = New-UserSafe -FirstName "Alice"   -LastName "Dupont"   -Department "RH"        -OUPath $ouParisUsers
$u2 = New-UserSafe -FirstName "Bob"     -LastName "Martin"   -Department "RH"        -OUPath $ouParisUsers
$u3 = New-UserSafe -FirstName "Claire"  -LastName "Bernard"  -Department "IT"        -OUPath $ouParisUsers
$u4 = New-UserSafe -FirstName "David"   -LastName "Leclerc"  -Department "Direction" -OUPath $ouParisUsers

# Utilisateurs Bordeaux
$ouBxUsers = "OU=Utilisateurs,OU=Bordeaux,$ouRoot"
$u5 = New-UserSafe -FirstName "Emma"    -LastName "Girard"   -Department "RH"        -OUPath $ouBxUsers
$u6 = New-UserSafe -FirstName "Franck"  -LastName "Morel"    -Department "IT"        -OUPath $ouBxUsers

# Administrateurs IT
$ouAdminUsers = "OU=Utilisateurs,OU=IT-Admins,$ouRoot"
$u7  = New-UserSafe -FirstName "Gael"   -LastName "Admin"    -Department "IT-Admins" -OUPath $ouAdminUsers
$u8  = New-UserSafe -FirstName "Helene" -LastName "Sysadmin" -Department "IT-Admins" -OUPath $ouAdminUsers
#endregion

#region --- TAPE 4 : Affectation dans les groupes ---------------------------
Write-Step "ETAPE 4 - Affectation des utilisateurs dans les groupes"

$memberships = @(
    @{Group="GRP_RH_Paris";        Members=@($u1,$u2)},
    @{Group="GRP_IT_Paris";        Members=@($u3)},
    @{Group="GRP_Direction_Paris"; Members=@($u4)},
    @{Group="GRP_RH_Bordeaux";     Members=@($u5)},
    @{Group="GRP_IT_Bordeaux";     Members=@($u6)},
    @{Group="GRP_Admins_IT";       Members=@($u7,$u8)},
    @{Group="GRP_Helpdesk";        Members=@($u3,$u6)}
)

foreach ($m in $memberships) {
    try {
        Add-ADGroupMember -Identity $m.Group -Members $m.Members -ErrorAction Stop
        Write-OK "$($m.Group) <- $($m.Members -join ', ')"
    } catch {
        Write-Warn "Memberships deja definis pour $($m.Group)"
    }
}

# Ajouter GRP_Admins_IT aux Admins du domaine (dlgation IT)
try {
    Add-ADGroupMember -Identity "Domain Admins" -Members "GRP_Admins_IT"
    Write-OK "GRP_Admins_IT ajoute a 'Domain Admins'"
} catch {
    Write-Warn "GRP_Admins_IT deja dans 'Domain Admins'"
}
#endregion

#region --- TAPE 5 : Cration et configuration des GPO ---------------------
Write-Step "ETAPE 5 - Creation des GPO (Modules 05 & 06)"

# -- GPO 1 : Politique de mots de passe stricte ----------------------------
$gpoName = "GPO-SecuriteMdP-Stricte"
try {
    $gpo = New-GPO -Name $gpoName -Comment "Politique de mot de passe renforcee" -ErrorAction Stop
    Write-OK "GPO creee : $gpoName"
} catch {
    $gpo = Get-GPO -Name $gpoName
    Write-Warn "GPO deja existante : $gpoName"
}

# Appliquer la GPO au domaine entier
New-GPLink -Name $gpoName -Target $DC -LinkEnabled Yes -ErrorAction SilentlyContinue | Out-Null

# Configurer les paramtres de mot de passe via secedit + powershell
$secEditFile = "$env:TEMP\secpol.inf"

$secPolicy = @"
[Unicode]
Unicode=yes
[System Access]
MinimumPasswordLength = 12
PasswordComplexity = 1
MaximumPasswordAge = 60
MinimumPasswordAge = 1
PasswordHistorySize = 12
[Version]
signature=`"`$CHICAGO`$"
version=1
"@

$secPolicy | Out-File -Encoding Unicode -FilePath $secEditFile
secedit /configure /db "$env:TEMP\secedit.sdb" /cfg $secEditFile /quiet 2>&1 | Out-Null
Write-OK "Politique de mot de passe : min 12 chars, complexite, 60j max"

# -- GPO 2 : Verrouillage de compte ----------------------------------------
$gpoLock = "GPO-VerrouillageCom pte"
try {
    New-GPO -Name "GPO-VerrouillageCompte" -Comment "Verrouillage apres 5 tentatives" -ErrorAction Stop | Out-Null
    Write-OK "GPO creee : GPO-VerrouillageCompte"
} catch {
    Write-Warn "GPO deja existante : GPO-VerrouillageCompte"
}

$lockPolicy = @"
[Unicode]
Unicode=yes
[System Access]
LockoutBadCount = 5
ResetLockoutCount = 30
LockoutDuration = 30
[Version]
signature=`"`$CHICAGO`$"
version=1
"@
$lockFile = "$env:TEMP\lockpol.inf"
$lockPolicy | Out-File -Encoding Unicode -FilePath $lockFile
secedit /configure /db "$env:TEMP\locksecedit.sdb" /cfg $lockFile /quiet 2>&1 | Out-Null
Write-OK "Verrouillage : 5 tentatives -> blocage 30 min"

# -- GPO 3 : Bureau standardis (postes Paris) -----------------------------
$gpoDesktop = "GPO-Bureau-Standard-Paris"
try {
    $gpo3 = New-GPO -Name $gpoDesktop -Comment "Restrictions bureau Paris" -ErrorAction Stop
    Write-OK "GPO creee : $gpoDesktop"
    
    # Dsactiver Panneau de contrle
    Set-GPRegistryValue -Name $gpoDesktop `
        -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
        -ValueName "NoControlPanel" -Type DWord -Value 1 | Out-Null
    
    # Dsactiver accs lecteur C: depuis l'Explorateur pour les utilisateurs standard
    Set-GPRegistryValue -Name $gpoDesktop `
        -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
        -ValueName "NoDrives" -Type DWord -Value 4 | Out-Null
    
    # Verrouillage cran aprs 10 minutes
    Set-GPRegistryValue -Name $gpoDesktop `
        -Key "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" `
        -ValueName "ScreenSaveTimeOut" -Type String -Value "600" | Out-Null
    Set-GPRegistryValue -Name $gpoDesktop `
        -Key "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" `
        -ValueName "ScreenSaverIsSecure" -Type String -Value "1" | Out-Null
    
    # Lier  l'OU Paris
    New-GPLink -Name $gpoDesktop -Target "OU=Paris,$ouRoot" -LinkEnabled Yes -ErrorAction SilentlyContinue | Out-Null
    Write-OK "$gpoDesktop liee a OU=Paris"
} catch {
    Write-Warn "GPO '$gpoDesktop' deja existante ou erreur"
}

# -- GPO 4 : Bloc USB pour Finance -----------------------------------------
$gpoUSB = "GPO-Blocage-USB"
try {
    $gpo4 = New-GPO -Name $gpoUSB -Comment "Blocage peripheriques USB amovibles" -ErrorAction Stop
    
    Set-GPRegistryValue -Name $gpoUSB `
        -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" `
        -ValueName "Deny_Write" -Type DWord -Value 1 | Out-Null
    Set-GPRegistryValue -Name $gpoUSB `
        -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" `
        -ValueName "Deny_Read" -Type DWord -Value 1 | Out-Null

    Write-OK "GPO '$gpoUSB' creee - lecture/ecriture USB bloquee"
} catch {
    Write-Warn "GPO '$gpoUSB' deja existante"
}
#endregion

#region --- TAPE 6 : Forcer la rplication des GPO -------------------------
Write-Step "ETAPE 6 - Forcer la replication & actualisation GPO"

gpupdate /force 2>&1 | Out-Null
Write-OK "gpupdate /force execute"

Invoke-GPUpdate -Computer $env:COMPUTERNAME -Force -ErrorAction SilentlyContinue
Write-OK "Invoke-GPUpdate execute"
#endregion

#region --- TAPE 7 : Rapport de synthse ------------------------------------
Write-Step "ETAPE 7 - Synthese de l'environnement AD cree"

Write-Host "`n  Unites d'Organisation :" -ForegroundColor White
Get-ADOrganizationalUnit -Filter * -SearchBase $ouRoot | 
    Select-Object DistinguishedName | 
    Sort-Object DistinguishedName |
    ForEach-Object { Write-Host "    - $($_.DistinguishedName)" -ForegroundColor Gray }

Write-Host "`n  Utilisateurs ($(@(Get-ADUser -Filter * -SearchBase $ouRoot).Count) comptes) :" -ForegroundColor White
Get-ADUser -Filter * -SearchBase $ouRoot -Properties Department |
    Sort-Object SamAccountName |
    ForEach-Object { Write-Host "    - $($_.SamAccountName) ($($_.Department))" -ForegroundColor Gray }

Write-Host "`n  Groupes :" -ForegroundColor White
Get-ADGroup -Filter * -SearchBase $ouRoot |
    Sort-Object Name |
    ForEach-Object { Write-Host "    - $($_.Name)" -ForegroundColor Gray }

Write-Host "`n  GPOs :" -ForegroundColor White
Get-GPO -All | Where-Object { $_.DisplayName -like "GPO-*" } |
    ForEach-Object { Write-Host "    - $($_.DisplayName) [$($_.GpoStatus)]" -ForegroundColor Gray }

Write-Host @"

+==========================================================+
|  [OK]  OUs / UTILISATEURS / GROUPES / GPO TERMINES        |
+==========================================================+
|  Mot de passe initial : $DefaultPassword                  
|  (Les utilisateurs doivent changer a la 1ere connexion) |
+==========================================================+
|  ETAPE SUIVANTE :                                       |
|    .\TP_03_Securite-LAPS-HyperV.ps1                     |
+==========================================================+
"@ -ForegroundColor Green
#endregion
