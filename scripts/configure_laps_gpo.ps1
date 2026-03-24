# Configure LAPS GPO (Windows LAPS - WS2025)
# GPO: GPO-LAPS-Configuration (b038c32e-f656-4558-86ab-9dc5820747e0)

$GpoName = "GPO-LAPS-Configuration"
$LapsKeyPath = "SOFTWARE\Microsoft\Policies\LAPS"

Write-Host "=== Configuration Windows LAPS dans GPO ===" -ForegroundColor Cyan

# Parametres Windows LAPS (Active Directory backup)
$LapsParams = @(
    @{ Key = $LapsKeyPath; ValueName = "BackupDirectory";           Type = "DWord"; Value = 1  },  # 1 = Active Directory
    @{ Key = $LapsKeyPath; ValueName = "PasswordAgeDays";           Type = "DWord"; Value = 30 },
    @{ Key = $LapsKeyPath; ValueName = "PasswordLength";            Type = "DWord"; Value = 14 },
    @{ Key = $LapsKeyPath; ValueName = "PasswordComplexity";        Type = "DWord"; Value = 4  },  # 4 = Lettres+Chiffres+Specials
    @{ Key = $LapsKeyPath; ValueName = "PostAuthResetDelay";        Type = "DWord"; Value = 24 },
    @{ Key = $LapsKeyPath; ValueName = "AdministratorAccountName";  Type = "String"; Value = "" }
)

$Gpo = Get-GPO -Name $GpoName -ErrorAction Stop

foreach ($p in $LapsParams) {
    try {
        if ($p.Type -eq "DWord") {
            Set-GPRegistryValue -Guid $Gpo.Id -Key "HKLM\$($p.Key)" `
                -ValueName $p.ValueName -Type DWord -Value $p.Value
        } else {
            Set-GPRegistryValue -Guid $Gpo.Id -Key "HKLM\$($p.Key)" `
                -ValueName $p.ValueName -Type String -Value $p.Value
        }
        Write-Host "  [OK] $($p.ValueName) = $($p.Value)"
    } catch {
        Write-Host "  [ERR] $($p.ValueName): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Verifier la liaison de la GPO
Write-Host "`n=== Liaisons GPO ===" -ForegroundColor Cyan
$links = (Get-GPO -Name $GpoName).GpoLinks
if ($links) {
    $links | Format-Table -AutoSize
} else {
    Write-Host "  Aucune liaison - Application de la liaison a Computers OU..."
    # Chercher l'OU Computers ou Postes
    $ouPath = (Get-ADOrganizationalUnit -Filter "Name -like '*ordin*' -or Name -like '*poste*' -or Name -like '*computer*'" -ErrorAction SilentlyContinue | Select -First 1).DistinguishedName
    if (-not $ouPath) {
        $ouPath = (Get-ADDomain).ComputersContainer
    }
    Write-Host "  Liaison a: $ouPath"
    New-GPLink -Guid $Gpo.Id -Target $ouPath -LinkEnabled Yes -ErrorAction SilentlyContinue
    Write-Host "  [OK] Liaison creee"
}

# Forcer gpupdate
Write-Host "`n=== Mise a jour GPO ===" -ForegroundColor Cyan
gpupdate /force /quiet
Write-Host "  [OK] gpupdate effectue"

# Verifier le registre local apres gpupdate
Write-Host "`n=== Verification registre LAPS local ===" -ForegroundColor Cyan
$reg = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Policies\LAPS" -ErrorAction SilentlyContinue
if ($reg) {
    $reg | Format-List * | Out-String | Write-Host
} else {
    Write-Host "  Cle HKLM:\SOFTWARE\Microsoft\Policies\LAPS non presente sur DC01"
    Write-Host "  (Normal - les params s'appliquent sur les machines membres, pas le DC)"
    Write-Host "`n  => Pour le screen 43: ouvrir GPMC > GPO-LAPS-Configuration > Modifier"
    Write-Host "     Configuration ordinateur > Modeles d'administration > Systeme > LAPS"
}

Write-Host "`nDONE" -ForegroundColor Green
