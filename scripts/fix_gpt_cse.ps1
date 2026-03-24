$domain = (Get-ADDomain).DNSRoot
$base = "C:\Windows\SYSVOL\sysvol\$domain\Policies"
$id1 = "342A47FB-C612-4150-BBFA-F58E01F399A4"
$id2 = "55AF136D-A4AA-402C-AC9A-1B65B7DAD54A"

# Le GUID CSE pour "Security Settings" (secedit) est obligatoire dans GPT.INI
# Sans lui, l'editeur GPO n'affiche pas "Strategie de comptes"
$cseGuids = "[{827D319E-6EAC-11D2-A4EA-00C04F79F83A}{803E14A0-B4FB-11D0-A0D0-00A0C90F574B}]"

foreach ($id in @($id1, $id2)) {
    $gptIni = "$base\{$id}\GPT.INI"
    Write-Host "Mise a jour: $gptIni"
    $content = Get-Content $gptIni -Raw
    Write-Host "Contenu actuel: $content"

    # Ajouter MachineExtensionVersions si absent
    if ($content -notmatch 'MachineExtensionVersions') {
        $content = $content.TrimEnd() + "`r`nMachineExtensionVersions=$cseGuids`r`n"
    } else {
        $content = $content -replace 'MachineExtensionVersions=.*', "MachineExtensionVersions=$cseGuids"
    }

    [System.IO.File]::WriteAllText($gptIni, $content, [System.Text.Encoding]::ASCII)
    Write-Host "GPT.INI mis a jour pour {$id}"
    Get-Content $gptIni
    Write-Host "---"
}

Write-Host "DONE - Ferme et reouvre l'editeur GPO"
