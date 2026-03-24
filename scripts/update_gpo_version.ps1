Import-Module GroupPolicy
$domain = (Get-ADDomain).DNSRoot
$domainDN = (Get-ADDomain).DistinguishedName

# Mettre a jour l'attribut versionNumber dans AD pour les deux GPOs
$gpoCN1 = "CN={342A47FB-C612-4150-BBFA-F58E01F399A4},CN=Policies,CN=System,$domainDN"
$gpoCN2 = "CN={55AF136D-A4AA-402C-AC9A-1B65B7DAD54A},CN=Policies,CN=System,$domainDN"

Set-ADObject -Identity $gpoCN1 -Replace @{versionNumber=65537}
Write-Host "AD version updated: GPO-SecuriteMdP-Stricte"

Set-ADObject -Identity $gpoCN2 -Replace @{versionNumber=65537}
Write-Host "AD version updated: GPO-VerrouillageCompte"

# Forcer gpupdate
gpupdate /force | Out-Null
Write-Host "GPUPDATE_DONE"

# Verifier que les fichiers existent
$base = "C:\Windows\SYSVOL\sysvol\$domain\Policies"
$f1 = "$base\{342A47FB-C612-4150-BBFA-F58E01F399A4}\Machine\Microsoft\Windows NT\SecEdit\GptTmpl.inf"
$f2 = "$base\{55AF136D-A4AA-402C-AC9A-1B65B7DAD54A}\Machine\Microsoft\Windows NT\SecEdit\GptTmpl.inf"
Write-Host "MDP INF exists: $(Test-Path $f1)"
Write-Host "VERROU INF exists: $(Test-Path $f2)"
Write-Host "--- Contenu MDP ---"
Get-Content $f1
Write-Host "--- Contenu VERROU ---"
Get-Content $f2
