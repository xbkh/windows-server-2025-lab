Import-Module NetworkPolicyServer -ErrorAction SilentlyContinue

# Creer les politiques NPS via l'API .NET NPS directement
# Windows Server 2025 : netsh nps add np n'accepte plus accesstype

# Obtenir le SID des groupes AD
$domainSID = (Get-ADDomain).DomainSID.Value
$usersDomaineSID = "$domainSID-513"   # Utilisateurs du domaine
$ordoSID = "$domainSID-515"           # Ordinateurs du domaine

Write-Host "Domain SID: $domainSID"
Write-Host "Users SID: $usersDomaineSID"
Write-Host "Computers SID: $ordoSID"

# Exporter la config NPS actuelle
$exportPath = "C:\Formation\nps_current.xml"
netsh nps export filename="$exportPath" exportPSK=YES | Out-Null
Write-Host "Export NPS: $exportPath"

# Lire le XML
[xml]$npsXml = Get-Content $exportPath

# Verifier les politiques existantes
Write-Host "`n=== Politiques reseau actuelles ==="
$npsXml.SelectNodes("//RadiusProfiles/Members") | ForEach-Object {
    Write-Host "  Politique: $($_.Name)"
}

# Creer le XML des nouvelles politiques
$newPoliciesXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<Root>
  <NetworkPolicies>
    <Members>
      <msNPAllowDialin>FALSE</msNPAllowDialin>
      <Name>NP-Acces-Utilisateurs-Domaine</Name>
      <msNPSequence>4</msNPSequence>
    </Members>
    <Members>
      <msNPAllowDialin>TRUE</msNPAllowDialin>
      <Name>NP-Acces-Ordinateurs-Domaine</Name>
      <msNPSequence>5</msNPSequence>
    </Members>
  </NetworkPolicies>
</Root>
"@

# Utiliser New-NpsNetworkPolicy via PowerShell si disponible
$cmd = Get-Command New-NpsNetworkPolicy -ErrorAction SilentlyContinue
if ($cmd) {
    Write-Host "Utilisation de New-NpsNetworkPolicy..."
    try {
        New-NpsNetworkPolicy -Name "NP-Acces-Utilisateurs-Domaine" `
            -ProcessingOrder 4 -PolicyState "Enabled" `
            -GrantAccess "Allow" `
            -AuthType @("MS_CHAP_v2") `
            -Condition @("NAS-Port-Type", "0") 2>&1 | Out-Null
        Write-Host "OK: NP-Acces-Utilisateurs-Domaine"
    } catch { Write-Host "ERR NP1: $_" }

    try {
        New-NpsNetworkPolicy -Name "NP-Acces-Ordinateurs-Domaine" `
            -ProcessingOrder 5 -PolicyState "Enabled" `
            -GrantAccess "Allow" `
            -AuthType @("MS_CHAP_v2") 2>&1 | Out-Null
        Write-Host "OK: NP-Acces-Ordinateurs-Domaine"
    } catch { Write-Host "ERR NP2: $_" }
} else {
    Write-Host "New-NpsNetworkPolicy non disponible - utilisation de netsh sans accesstype..."
    
    $conditionTime = "0x1006"
    $conditionData = "0 00:00-24:00; 1 00:00-24:00; 2 00:00-24:00; 3 00:00-24:00; 4 00:00-24:00; 5 00:00-24:00; 6 00:00-24:00"
    
    # Politique 1 : acces utilisateurs domaine
    $r = & netsh nps add np name="NP-Acces-Utilisateurs-Domaine" state=ENABLE processingorder=4 policysource=0 conditionid="$conditionTime" conditiondata="$conditionData" profileid=0x100f profiledata=TRUE 2>&1
    Write-Host "NP1: $r"
    
    # Politique 2 : acces ordinateurs domaine
    $r = & netsh nps add np name="NP-Acces-Ordinateurs-Domaine" state=ENABLE processingorder=5 policysource=0 conditionid="$conditionTime" conditiondata="$conditionData" profileid=0x100f profiledata=TRUE 2>&1
    Write-Host "NP2: $r"
    
    # Politique 3 : refus comptes desactives
    $r = & netsh nps add np name="NP-Refus-Desactive" state=ENABLE processingorder=10 policysource=0 conditionid="$conditionTime" conditiondata="$conditionData" profileid=0x100f profiledata=FALSE 2>&1
    Write-Host "NP3: $r"
    
    # CRP
    $r = & netsh nps add crp name="CRP-SATOM-Local" state=ENABLE processingorder=1 policysource=0 conditionid="$conditionTime" conditiondata="$conditionData" profileid=0x1025 profiledata=0x1 2>&1
    Write-Host "CRP: $r"
}

Write-Host "`n=== Verification finale ==="
netsh nps show np 2>&1 | Select-String "Nom|Name" | Where-Object {$_ -match 'NP-|CRP-'}
netsh nps show crp 2>&1 | Select-String "Nom|Name"
Write-Host "DONE"
