$ErrorActionPreference = 'Stop'
$domainCred = New-Object pscredential('SATOM\Administrateur', (ConvertTo-SecureString 'formation123.' -AsPlainText -Force))

# Assure le DNS voulu sans toucher l'IP si elle est déjà correcte
$ifAlias = (Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1 -ExpandProperty Name)
if ($ifAlias) {
    Set-DnsClientServerAddress -InterfaceAlias $ifAlias -ServerAddresses @('192.168.122.10','192.168.122.20')
}

Rename-Computer -NewName 'PC01' -Force -ErrorAction SilentlyContinue
Add-Computer -DomainName 'satom.local' -Credential $domainCred -Force
shutdown /r /t 5 /c Join_Domain_PC01
