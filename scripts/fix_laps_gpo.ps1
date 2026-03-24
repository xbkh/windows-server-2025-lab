$GpoId = 'b038c32e-f656-4558-86ab-9dc5820747e0'
$WrongKey = 'HKLM\SOFTWARE\Microsoft\Policies\LAPS'
$CorrectKey = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\LAPS'

Write-Host "=== Suppression ancien chemin (incorrect) ===" -ForegroundColor Yellow

$wrongValues = @('BackupDirectory','PasswordAgeDays','PasswordLength','PasswordComplexity','PostAuthResetDelay','AdministratorAccountName')
foreach ($v in $wrongValues) {
    Remove-GPRegistryValue -Guid $GpoId -Key $WrongKey -ValueName $v -ErrorAction SilentlyContinue
    Write-Host "  Removed (if existed): $v"
}

Write-Host "`n=== Ajout valeurs avec chemin correct ===" -ForegroundColor Cyan

# BackupDirectory: 2 = Azure AD, 1 = Active Directory
Set-GPRegistryValue -Guid $GpoId -Key $CorrectKey -ValueName 'BackupDirectory' -Type DWord -Value 1
Write-Host "  [OK] BackupDirectory = 1 (Active Directory)"

Set-GPRegistryValue -Guid $GpoId -Key $CorrectKey -ValueName 'PasswordAgeDays' -Type DWord -Value 30
Write-Host "  [OK] PasswordAgeDays = 30"

Set-GPRegistryValue -Guid $GpoId -Key $CorrectKey -ValueName 'PasswordLength' -Type DWord -Value 14
Write-Host "  [OK] PasswordLength = 14"

# PasswordComplexity: 4 = Large letters + small letters + numbers + specials
Set-GPRegistryValue -Guid $GpoId -Key $CorrectKey -ValueName 'PasswordComplexity' -Type DWord -Value 4
Write-Host "  [OK] PasswordComplexity = 4 (tous types)"

Set-GPRegistryValue -Guid $GpoId -Key $CorrectKey -ValueName 'PostAuthenticationResetDelay' -Type DWord -Value 24
Write-Host "  [OK] PostAuthenticationResetDelay = 24"

Write-Host "`n=== Verification dans Registry.pol ===" -ForegroundColor Cyan
$polPath = "C:\Windows\SYSVOL\sysvol\satom.local\Policies\{$GpoId}\Machine\Registry.pol"
$size = (Get-Item $polPath -EA SilentlyContinue).Length
Write-Host "  Registry.pol taille: $size octets"

Write-Host "`n=== Resultats Get-GPRegistryValue ===" -ForegroundColor Cyan
Get-GPRegistryValue -Guid $GpoId -Key $CorrectKey -ErrorAction SilentlyContinue | 
    Select-Object ValueName, Value, Type | Format-Table -AutoSize

Write-Host "DONE" -ForegroundColor Green
Write-Host ""
Write-Host "=> Ferme et reuvre l'editeur GPO sur DC01 pour voir les parametres"
Write-Host "   GPMC > GPO-LAPS-Configuration > Modifier >"
Write-Host "   Config ordinateur > Strategies > Modeles d'admin > Systeme > LAPS"
