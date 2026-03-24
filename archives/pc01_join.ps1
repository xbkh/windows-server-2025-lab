$ErrorActionPreference = 'Stop'

$ifAlias = (Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1 -ExpandProperty Name)
if (-not $ifAlias) { throw 'Aucune interface reseau active trouvee' }

Write-Host "[PC01] Interface active: $ifAlias"

# Reconfig reseau
Get-NetIPAddress -InterfaceAlias $ifAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -ne '127.0.0.1' } |
    ForEach-Object {
        Remove-NetIPAddress -InterfaceAlias $ifAlias -IPAddress $_.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
    }

New-NetIPAddress -InterfaceAlias $ifAlias -IPAddress '192.168.122.30' -PrefixLength 24 -DefaultGateway '192.168.122.1' -AddressFamily IPv4 | Out-Null
Set-DnsClientServerAddress -InterfaceAlias $ifAlias -ServerAddresses @('192.168.122.10','192.168.122.20')
Write-Host '[PC01] IP fixee en 192.168.122.30/24, DNS=192.168.122.10,192.168.122.20'

$domainCred = New-Object pscredential('SATOM\Administrateur', (ConvertTo-SecureString 'formation123.' -AsPlainText -Force))

Add-Computer -DomainName 'satom.local' -Credential $domainCred -NewName 'PC01' -Force -Restart
