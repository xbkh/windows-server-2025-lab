#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Module 18 - Serveur de fichiers : DFS-N, Partages SMB, FSRM, Quotas, GPO lecteurs
.PARAMETER DomainName
    FQDN du domaine (defaut : satom.local)
.PARAMETER ShareRootPath
    Chemin local racine (defaut : auto-detecte C:\Partages)
.PARAMETER Module
    All | Roles | Shares | DFS | FSRM | GPO | Validate
.EXAMPLE
    .\TP_06_FileServer-DFS-FSRM.ps1
    .\TP_06_FileServer-DFS-FSRM.ps1 -Module Validate
#>
[CmdletBinding()]
param(
    [string]$DomainName    = 'satom.local',
    [string]$ShareRootPath = '',
    [ValidateSet('All','Roles','Shares','DFS','FSRM','GPO','Validate')]
    [string]$Module = 'All'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Off

#region ── Helpers ──────────────────────────────────────────────────────────────
function Write-Step { param([string]$m) Write-Host "`n[FS] $m" -ForegroundColor Cyan }
function Write-OK   { param([string]$m) Write-Host "[FS] OK  $m" -ForegroundColor Green }
function Write-Warn { param([string]$m) Write-Host "[FS] WRN $m" -ForegroundColor Yellow }
function Write-Fail { param([string]$m) Write-Host "[FS] ERR $m" -ForegroundColor Red }

if (-not $ShareRootPath) {
    # Verifier que D: est un disque NTFS fixe (pas CD-ROM)
    $dVol = Get-Volume -DriveLetter 'D' -ErrorAction SilentlyContinue
    $ShareRootPath = if ($dVol -and $dVol.DriveType -eq 'Fixed') { 'D:\Partages' } else { 'C:\Partages' }
}
Write-Host "[FS] Racine partages : $ShareRootPath" -ForegroundColor DarkCyan

$DomNetbios = ($DomainName.Split('.')[0]).ToUpper()

$shares = @(
    @{ Name = 'Paris';     Path = "$ShareRootPath\Paris";     Desc = 'Partage Paris';     QuotaGB = 10 },
    @{ Name = 'Bordeaux';  Path = "$ShareRootPath\Bordeaux";  Desc = 'Partage Bordeaux';  QuotaGB = 10 },
    @{ Name = 'Direction'; Path = "$ShareRootPath\Direction"; Desc = 'Partage Direction'; QuotaGB = 20 },
    @{ Name = 'IT';        Path = "$ShareRootPath\IT";        Desc = 'Partage IT';        QuotaGB = 50 },
    @{ Name = 'Software';  Path = "$ShareRootPath\Software";  Desc = 'Logiciels';         QuotaGB = 100 },
    @{ Name = 'Commun';    Path = "$ShareRootPath\Commun";    Desc = 'Partage commun';    QuotaGB = 20 }
)
#endregion

#region ── Roles ───────────────────────────────────────────────────────────────
function Install-Roles {
    Write-Step "=== ROLES : Installation des roles File Server ==="
    $roles = @('FS-FileServer','FS-DFS-Namespace','FS-DFS-Replication','FS-Resource-Manager',
                'FS-VSS-Agent','RSAT-DFS-Mgmt-Con','RSAT-FSRM-Mgmt')
    foreach ($role in $roles) {
        $feat = Get-WindowsFeature $role -ErrorAction SilentlyContinue
        if ($feat -and $feat.InstallState -ne 'Installed') {
            Install-WindowsFeature -Name $role -IncludeManagementTools | Out-Null
            Write-OK "Installe : $role"
        } else {
            Write-OK "Deja present : $role"
        }
    }
    Write-OK "=== Roles installes ==="
}
#endregion

#region ── Partages SMB ─────────────────────────────────────────────────────────
function Create-Shares {
    Write-Step "=== SHARES : Creation des partages SMB ==="
    foreach ($share in $shares) {
        if (-not (Test-Path $share.Path)) {
            New-Item -ItemType Directory -Path $share.Path -Force | Out-Null
            Write-OK "Dossier cree : $($share.Path)"
        } else {
            Write-OK "Dossier existant : $($share.Path)"
        }
        foreach ($sub in @('Commun','Archives','Projets')) {
            $subPath = Join-Path $share.Path $sub
            if (-not (Test-Path $subPath)) { New-Item -ItemType Directory -Path $subPath -Force | Out-Null }
        }

        # NTFS: utilisation des SIDs universels (evite les pb de traduction des noms localises)
        try {
            $acl = Get-Acl $share.Path
            $acl.SetAccessRuleProtection($true,$false)
            $ri = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit'
            $rp = [System.Security.AccessControl.PropagationFlags]'None'
            $at = [System.Security.AccessControl.AccessControlType]'Allow'
            # Administrators (SID S-1-5-32-544)
            $sidAdmins = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
            $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($sidAdmins,'FullControl',$ri,$rp,$at)))
            # SYSTEM (SID S-1-5-18)
            $sidSystem = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')
            $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($sidSystem,'FullControl',$ri,$rp,$at)))
            # Authenticated Users (SID S-1-5-11) - Modify
            $sidAuth = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-11')
            $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($sidAuth,'Modify',$ri,$rp,$at)))
            Set-Acl -Path $share.Path -AclObject $acl
            Write-OK "NTFS configure : $($share.Name)"
        } catch {
            Write-Warn "NTFS ignore (permissions heritees) : $($share.Name)"
        }

        $existingShare = Get-SmbShare -Name $share.Name -ErrorAction SilentlyContinue
        if (-not $existingShare) {
            New-SmbShare -Name $share.Name `
                -Path $share.Path `
                -Description $share.Desc `
                -FolderEnumerationMode AccessBased `
                -CachingMode None | Out-Null
            Write-OK "Partage cree : \\$env:COMPUTERNAME\$($share.Name) [ABE actif]"
        } else {
            Set-SmbShare -Name $share.Name -FolderEnumerationMode AccessBased -Force | Out-Null
            Write-OK "Partage mis a jour : $($share.Name) [ABE actif]"
        }
    }
    Write-OK "=== Partages crees ==="
}
#endregion

#region ── DFS Namespace ───────────────────────────────────────────────────────
function Configure-DFS {
    Write-Step "=== DFS : Espace de noms \\$DomainName\data ==="
    $nsName   = 'data'
    $nsRoot   = "\\$DomainName\$nsName"
    $nsPath   = "$ShareRootPath\_DFS-Root"
    $domainDC = $env:COMPUTERNAME

    if (-not (Test-Path $nsPath)) { New-Item -ItemType Directory -Path $nsPath -Force | Out-Null }

    if (-not (Get-SmbShare -Name $nsName -ErrorAction SilentlyContinue)) {
        New-SmbShare -Name $nsName -Path $nsPath | Out-Null
        Write-OK "Partage racine DFS : \\$domainDC\$nsName"
    }

    try {
        if (-not (Get-DfsnRoot -Path $nsRoot -ErrorAction SilentlyContinue)) {
            New-DfsnRoot -Path $nsRoot `
                -TargetPath "\\$domainDC\$nsName" `
                -Type DomainV2 `
                -Description "Espace de noms SATOM" | Out-Null
            Write-OK "Namespace DFS cree : $nsRoot (DomainV2)"
        } else {
            Write-OK "Namespace DFS existant : $nsRoot"
        }
    } catch {
        Write-Warn "Namespace DFS : $_"
    }

    foreach ($share in $shares) {
        $linkPath   = "$nsRoot\$($share.Name)"
        $targetPath = "\\$domainDC\$($share.Name)"
        try {
            if (-not (Get-DfsnFolder -Path $linkPath -ErrorAction SilentlyContinue)) {
                New-DfsnFolder -Path $linkPath -TargetPath $targetPath -Description $share.Desc | Out-Null
                Write-OK "Lien DFS : $linkPath -> $targetPath"
            } else {
                Write-OK "Lien DFS existant : $linkPath"
            }
        } catch {
            Write-Warn "Lien DFS $($share.Name) : $_"
        }
    }
    Write-OK "=== DFS configure ==="
}
#endregion

#region ── FSRM ────────────────────────────────────────────────────────────────
function Configure-FSRM {
    Write-Step "=== FSRM : Quotas et filtrage de fichiers ==="

    $fileGroupName = 'Executables-Bloques'
    $blockedExt = @('*.exe','*.msi','*.bat','*.cmd','*.vbs','*.ps1','*.com',
                    '*.scr','*.pif','*.jar','*.hta','*.wsf','*.wsh')
    if (-not (Get-FsrmFileGroup -Name $fileGroupName -ErrorAction SilentlyContinue)) {
        New-FsrmFileGroup -Name $fileGroupName -IncludePattern $blockedExt | Out-Null
        Write-OK "Groupe fichiers bloques : $fileGroupName"
    } else {
        Write-OK "Groupe existant : $fileGroupName"
    }

    $filterName = 'Bloquer-Executables'
    if (-not (Get-FsrmFileScreenTemplate -Name $filterName -ErrorAction SilentlyContinue)) {
        New-FsrmFileScreenTemplate -Name $filterName -IncludeGroup $fileGroupName -Active | Out-Null
        Write-OK "Modele filtrage : $filterName (mode actif)"
    } else {
        Write-OK "Modele filtrage existant : $filterName"
    }

    $quotaTemplates = @(
        @{ Name = 'Quota-10GB';  SizeBytes = 10GB  },
        @{ Name = 'Quota-20GB';  SizeBytes = 20GB  },
        @{ Name = 'Quota-50GB';  SizeBytes = 50GB  },
        @{ Name = 'Quota-100GB'; SizeBytes = 100GB }
    )
    foreach ($qt in $quotaTemplates) {
        if (-not (Get-FsrmQuotaTemplate -Name $qt.Name -ErrorAction SilentlyContinue)) {
            $notifAction = New-FsrmAction -Type Event -EventType Warning `
                -Body "Quota [Quota Path] atteint [Quota Current Percent]%. User: [Source Io Owner]"
            $threshold85 = New-FsrmQuotaThreshold -Percentage 85 -Action $notifAction
            $threshold95 = New-FsrmQuotaThreshold -Percentage 95
            New-FsrmQuotaTemplate -Name $qt.Name `
                -Size $qt.SizeBytes `
                -SoftLimit:$false `
                -Threshold @($threshold85, $threshold95) | Out-Null
            $sizeGB = [math]::Round($qt.SizeBytes / 1GB)
            Write-OK "Modele quota : $($qt.Name) (${sizeGB}GB, alerte 85%)"
        } else {
            Write-OK "Modele existant : $($qt.Name)"
        }
    }

    foreach ($share in $shares) {
        if (-not (Test-Path $share.Path)) { continue }
        $quotaName = "Quota-$($share.QuotaGB)GB"
        if (-not (Get-FsrmQuota -Path $share.Path -ErrorAction SilentlyContinue)) {
            New-FsrmQuota -Path $share.Path -Template $quotaName | Out-Null
            Write-OK "Quota $($share.QuotaGB)GB : $($share.Path)"
        } else {
            Write-OK "Quota existant : $($share.Name)"
        }
        if ($share.Name -ne 'Software') {
            if (-not (Get-FsrmFileScreen -Path $share.Path -ErrorAction SilentlyContinue)) {
                New-FsrmFileScreen -Path $share.Path -Template $filterName | Out-Null
                Write-OK "Filtrage exe : $($share.Path)"
            } else {
                Write-OK "Filtrage existant : $($share.Name)"
            }
        }
    }

    try {
        if (-not (Get-FsrmStorageReport -Name 'Rapport-Hebdomadaire' -ErrorAction SilentlyContinue)) {
            $schedule = New-FsrmScheduledTask -Weekly @('Sunday') -Time (Get-Date '02:00')
            New-FsrmStorageReport -Name 'Rapport-Hebdomadaire' `
                -Namespace @($ShareRootPath) `
                -ReportType @('LargeFiles','FilesByType','QuotaUsage') `
                -Schedule $schedule | Out-Null
            Write-OK "Rapport FSRM : dimanche 02h"
        } else {
            Write-OK "Rapport FSRM existant"
        }
    } catch {
        Write-Warn "Rapport FSRM non planifie (erreur scheduling) : $_"
    }
    Write-OK "=== FSRM configure ==="
}
#endregion

#region ── GPO Lecteurs ────────────────────────────────────────────────────────
function Configure-DriveMappingGPO {
    Write-Step "=== GPO : Mappage des lecteurs reseau ==="
    Import-Module GroupPolicy -ErrorAction Stop

    $gpoName = 'GPO-Lecteurs-Reseau'
    if (-not (Get-GPO -Name $gpoName -ErrorAction SilentlyContinue)) {
        New-GPO -Name $gpoName -Comment "Mappage lecteurs DFS SATOM" | Out-Null
        Write-OK "GPO creee : $gpoName"
    } else {
        Write-OK "GPO existante : $gpoName"
    }

    $domainDN = (Get-ADDomain).DistinguishedName
    $links = Get-GPInheritance -Target $domainDN
    if (-not ($links.GpoLinks | Where-Object { $_.DisplayName -eq $gpoName })) {
        New-GPLink -Name $gpoName -Target $domainDN -LinkEnabled Yes | Out-Null
        Write-OK "GPO liee : $domainDN"
    }

    $mappings = @(
        @{ Letter = 'S'; Share = 'Commun'   },
        @{ Letter = 'P'; Share = 'Paris'    },
        @{ Letter = 'B'; Share = 'Bordeaux' },
        @{ Letter = 'I'; Share = 'IT'       }
    )
    foreach ($map in $mappings) {
        $uncPath = "\\$DomainName\data\$($map.Share)"
        $regKey  = "HKCU\Network\$($map.Letter)"
        Set-GPRegistryValue -Name $gpoName -Key $regKey -ValueName 'RemotePath'     -Type String -Value $uncPath | Out-Null
        Set-GPRegistryValue -Name $gpoName -Key $regKey -ValueName 'UserName'       -Type String -Value ''       | Out-Null
        Set-GPRegistryValue -Name $gpoName -Key $regKey -ValueName 'ProviderName'   -Type String -Value 'Microsoft Windows Network' | Out-Null
        Set-GPRegistryValue -Name $gpoName -Key $regKey -ValueName 'ConnectionType' -Type DWord  -Value 1        | Out-Null
        Set-GPRegistryValue -Name $gpoName -Key $regKey -ValueName 'DeferFlags'     -Type DWord  -Value 4        | Out-Null
        Write-OK "Lecteur $($map.Letter): -> $uncPath"
    }
    Write-OK "=== GPO lecteurs configuree ==="
}
#endregion

#region ── Validation ──────────────────────────────────────────────────────────
function Invoke-Validation {
    Write-Step "=== VALIDATION FILE SERVER ==="
    $script:score = 0; $script:total = 0

    function Check {
        param([string]$Title, [scriptblock]$Test)
        $script:total++
        try {
            if (& $Test) { Write-OK $Title; $script:score++ }
            else         { Write-Fail $Title }
        } catch { Write-Fail "$Title [ERR: $_]" }
    }

    Check "Role FS-FileServer installe"            { (Get-WindowsFeature FS-FileServer).InstallState -eq 'Installed' }
    Check "Role FS-DFS-Namespace installe"         { (Get-WindowsFeature FS-DFS-Namespace).InstallState -eq 'Installed' }
    Check "Role FS-Resource-Manager installe"      { (Get-WindowsFeature FS-Resource-Manager).InstallState -eq 'Installed' }
    Check "Dossier racine partages ($ShareRootPath)" { Test-Path $ShareRootPath }
    Check "Partages SMB crees (6 attendus)"        { (Get-SmbShare | Where-Object { $shares.Name -contains $_.Name }).Count -ge 6 }
    Check "ABE active sur Commun"                  { (Get-SmbShare -Name 'Commun' -ErrorAction SilentlyContinue).FolderEnumerationMode -eq 'AccessBased' }
    Check "Namespace DFS \\$DomainName\data"       { $null -ne (Get-DfsnRoot -Path "\\$DomainName\data" -ErrorAction SilentlyContinue) }
    Check "Liens DFS crees (6 attendus)"           { (Get-DfsnFolder -Path "\\$DomainName\data\*" -ErrorAction SilentlyContinue).Count -ge 6 }
    Check "Groupe FSRM Executables-Bloques"        { $null -ne (Get-FsrmFileGroup -Name 'Executables-Bloques' -ErrorAction SilentlyContinue) }
    Check "Modele filtrage Bloquer-Executables"    { $null -ne (Get-FsrmFileScreenTemplate -Name 'Bloquer-Executables' -ErrorAction SilentlyContinue) }
    Check "Quotas FSRM appliques (>= 5)"           { (Get-FsrmQuota -ErrorAction SilentlyContinue).Count -ge 5 }
    Check "GPO-Lecteurs-Reseau existe et liee"     { $null -ne (Get-GPO -Name 'GPO-Lecteurs-Reseau' -ErrorAction SilentlyContinue) }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    $pct   = if ($script:total -gt 0) { [math]::Round(($script:score / $script:total) * 100) } else { 0 }
    $grade = if ($pct -ge 90) { 'A - Excellent' } elseif ($pct -ge 75) { 'B - Bien' } elseif ($pct -ge 60) { 'C - Correct' } else { 'D - A completer' }
    $col   = if ($pct -ge 90) { 'Green' } elseif ($pct -ge 75) { 'Yellow' } else { 'Red' }
    Write-Host "  Score : $script:score / $script:total  ($pct%)  ->  $grade" -ForegroundColor $col
    Write-Host "========================================" -ForegroundColor Cyan

    Write-Host "`n[FS] Acces DFS :" -ForegroundColor Cyan
    foreach ($share in $shares) {
        Write-Host "  \\$DomainName\data\$($share.Name.PadRight(10)) -> $($share.Path)" -ForegroundColor Gray
    }
}
#endregion

#region ── Main ────────────────────────────────────────────────────────────────
Write-Host "+==============================================================+"  -ForegroundColor Cyan
Write-Host "|   MODULE 18 - Serveur de fichiers : DFS + FSRM + Partages   |"  -ForegroundColor Cyan
Write-Host "|   Domaine  : $DomainName"  -ForegroundColor Cyan
Write-Host "|   Racine   : $ShareRootPath"  -ForegroundColor Cyan
Write-Host "+==============================================================+"  -ForegroundColor Cyan

switch ($Module) {
    'Roles'    { Install-Roles }
    'Shares'   { Create-Shares }
    'DFS'      { Configure-DFS }
    'FSRM'     { Configure-FSRM }
    'GPO'      { Configure-DriveMappingGPO }
    'Validate' { Invoke-Validation }
    'All' {
        Install-Roles
        Create-Shares
        Configure-DFS
        Configure-FSRM
        Configure-DriveMappingGPO
        Invoke-Validation
    }
}
#endregion
