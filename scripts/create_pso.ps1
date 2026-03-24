Import-Module ActiveDirectory
$psoName = 'PSO-Admins'
$existing = Get-ADFineGrainedPasswordPolicy -Filter {Name -eq 'PSO-Admins'} -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "PSO existe deja: $($existing.Name)"
} else {
    New-ADFineGrainedPasswordPolicy -Name $psoName `
        -Precedence 10 `
        -MinPasswordLength 16 `
        -MaxPasswordAge (New-TimeSpan -Days 30) `
        -MinPasswordAge (New-TimeSpan -Days 1) `
        -LockoutThreshold 3 `
        -LockoutDuration (New-TimeSpan -Minutes 60) `
        -LockoutObservationWindow (New-TimeSpan -Minutes 60) `
        -PasswordHistoryCount 24 `
        -ComplexityEnabled $true `
        -ReversibleEncryptionEnabled $false `
        -Description 'Politique renforcee pour les administrateurs'
    Write-Host "PSO_CREATED"
}
$grp = Get-ADGroup -Filter {Name -eq 'GRP-IT-Admins'} -ErrorAction SilentlyContinue
if ($grp) {
    Add-ADFineGrainedPasswordPolicySubject -Identity $psoName -Subjects 'GRP-IT-Admins'
    Write-Host "PSO_APPLIED_TO_GRP-IT-Admins"
} else {
    Write-Host "WARN: groupe GRP-IT-Admins introuvable"
}
Write-Host "--- Verification ---"
Get-ADFineGrainedPasswordPolicy -Filter * | Select Name,Precedence,MinPasswordLength,MaxPasswordAge,LockoutThreshold | Format-Table -AutoSize
