$domain = (Get-ADDomain).DNSRoot
$base = "C:\Windows\SYSVOL\sysvol\$domain\Policies"
$id1 = "342A47FB-C612-4150-BBFA-F58E01F399A4"
$id2 = "55AF136D-A4AA-402C-AC9A-1B65B7DAD54A"

# GptTmpl.inf COMPLET pour GPO-SecuriteMdP-Stricte
$infMdp = "[Unicode]`r`nUnicode=yes`r`n[Version]`r`nsignature=`"`$CHICAGO`$`"`r`nRevision=1`r`n[System Access]`r`nMinimumPasswordAge = 1`r`nMaximumPasswordAge = 60`r`nMinimumPasswordLength = 12`r`nPasswordComplexity = 1`r`nPasswordHistorySize = 10`r`nClearTextPassword = 0`r`n"

$pathMdp = "$base\{$id1}\Machine\Microsoft\Windows NT\SecEdit"
New-Item -Path $pathMdp -ItemType Directory -Force | Out-Null
[System.IO.File]::WriteAllText("$pathMdp\GptTmpl.inf", $infMdp, [System.Text.Encoding]::Unicode)
Write-Host "MDP: GptTmpl.inf ecrit"

# GptTmpl.inf COMPLET pour GPO-VerrouillageCompte
$infVerrou = "[Unicode]`r`nUnicode=yes`r`n[Version]`r`nsignature=`"`$CHICAGO`$`"`r`nRevision=1`r`n[System Access]`r`nLockoutBadCount = 5`r`nLockoutDuration = 30`r`nResetLockoutCount = 30`r`n"

$pathVerrou = "$base\{$id2}\Machine\Microsoft\Windows NT\SecEdit"
New-Item -Path $pathVerrou -ItemType Directory -Force | Out-Null
[System.IO.File]::WriteAllText("$pathVerrou\GptTmpl.inf", $infVerrou, [System.Text.Encoding]::Unicode)
Write-Host "VERROU: GptTmpl.inf ecrit"

# Verifier le contenu
Write-Host "`n--- MDP ---"
Get-Content "$pathMdp\GptTmpl.inf"
Write-Host "`n--- VERROU ---"
Get-Content "$pathVerrou\GptTmpl.inf"

# Incrementer les versions dans GPT.INI
foreach ($id in @($id1, $id2)) {
    $gptIni = "$base\{$id}\GPT.INI"
    $c = Get-Content $gptIni -Raw
    $c = $c -replace 'Version=\d+', 'Version=65537'
    [System.IO.File]::WriteAllText($gptIni, $c, [System.Text.Encoding]::ASCII)
}
Write-Host "`nVersions GPT.INI mises a jour"

# Mettre a jour versionNumber dans AD
$domainDN = (Get-ADDomain).DistinguishedName
Set-ADObject -Identity "CN={$id1},CN=Policies,CN=System,$domainDN" -Replace @{versionNumber=65537}
Set-ADObject -Identity "CN={$id2},CN=Policies,CN=System,$domainDN" -Replace @{versionNumber=65537}
Write-Host "AD versionNumber mis a jour"

Write-Host "`nFERME l'editeur GPO et reouvre-le"
