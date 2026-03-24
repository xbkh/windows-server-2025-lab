$gpo1 = Get-GPO -Name 'GPO-SecuriteMdP-Stricte'
$gpo2 = Get-GPO -Name 'GPO-VerrouillageCompte'
$domain = (Get-ADDomain).DNSRoot
$sysvolBase = "C:\Windows\SYSVOL\sysvol\$domain\Policies"

Write-Host "ID_MDP=$($gpo1.Id.ToString().ToUpper())"
Write-Host "ID_VERROU=$($gpo2.Id.ToString().ToUpper())"
Write-Host "SYSVOL=$sysvolBase"

# Creer GptTmpl.inf pour GPO-SecuriteMdP-Stricte (politique mot de passe)
$pathMdp = "$sysvolBase\{$($gpo1.Id.ToString().ToUpper())}\Machine\Microsoft\Windows NT\SecEdit"
New-Item -Path $pathMdp -ItemType Directory -Force | Out-Null

$infMdp = @"
[Unicode]
Unicode=yes
[System Access]
MinimumPasswordAge = 1
MaximumPasswordAge = 60
MinimumPasswordLength = 12
PasswordComplexity = 1
PasswordHistorySize = 10
ClearTextPassword = 0
"@
[System.IO.File]::WriteAllText("$pathMdp\GptTmpl.inf", $infMdp, [System.Text.Encoding]::Unicode)
Write-Host "MDP_INF_WRITTEN"

# Creer GptTmpl.inf pour GPO-VerrouillageCompte (verrouillage)
$pathVerrou = "$sysvolBase\{$($gpo2.Id.ToString().ToUpper())}\Machine\Microsoft\Windows NT\SecEdit"
New-Item -Path $pathVerrou -ItemType Directory -Force | Out-Null

$infVerrou = @"
[Unicode]
Unicode=yes
[System Access]
LockoutBadCount = 5
LockoutDuration = 30
ResetLockoutCount = 30
"@
[System.IO.File]::WriteAllText("$pathVerrou\GptTmpl.inf", $infVerrou, [System.Text.Encoding]::Unicode)
Write-Host "VERROU_INF_WRITTEN"

# Mettre a jour le numero de version des GPOs (requis pour que le DC detecte les changements)
function Update-GpoVersion {
    param($GpoId, $Domain)
    $sysvolPath = "C:\Windows\SYSVOL\sysvol\$Domain\Policies\{$($GpoId.ToUpper())}"
    $gptIniPath = "$sysvolPath\GPT.INI"
    if (Test-Path $gptIniPath) {
        $content = Get-Content $gptIniPath -Raw
        if ($content -match 'Version=(\d+)') {
            $oldVer = [int]$Matches[1]
            $newVer = $oldVer + 1
            $content = $content -replace "Version=\d+", "Version=$newVer"
            [System.IO.File]::WriteAllText($gptIniPath, $content, [System.Text.Encoding]::ASCII)
            Write-Host "GPT.INI updated: $oldVer -> $newVer"
        }
    } else {
        Write-Host "WARN: GPT.INI not found at $gptIniPath"
    }
}

Update-GpoVersion -GpoId $gpo1.Id.ToString() -Domain $domain
Update-GpoVersion -GpoId $gpo2.Id.ToString() -Domain $domain

Write-Host "DONE"
