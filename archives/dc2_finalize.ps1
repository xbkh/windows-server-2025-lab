$ErrorActionPreference = 'Stop'
$ifAlias = (Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1 -ExpandProperty Name)
if ($ifAlias) {
    Set-DnsClientServerAddress -InterfaceAlias $ifAlias -ServerAddresses @('127.0.0.1','192.168.122.10')
    Write-Host '[DC02] DNS client configure: 127.0.0.1 puis 192.168.122.10'
}

try {
    Add-DhcpServerInDC -DnsName 'DC02.satom.local' -IPAddress '192.168.122.20' -ErrorAction Stop
    Write-Host '[DC02] DHCP autorise dans AD'
} catch {
    Write-Host '[DC02] DHCP deja autorise ou erreur non bloquante'
}

Write-Host '[DC02] Finalisation terminee'
