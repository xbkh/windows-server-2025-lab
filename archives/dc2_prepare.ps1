$ErrorActionPreference = 'Stop'

$ifAlias = (Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1 -ExpandProperty Name)
if (-not $ifAlias) { throw 'Aucune interface reseau active trouvee' }

Write-Host "[DC2] Interface active: $ifAlias"

# Reconfig reseau
Get-NetIPAddress -InterfaceAlias $ifAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -ne '127.0.0.1' } |
    ForEach-Object {
        Remove-NetIPAddress -InterfaceAlias $ifAlias -IPAddress $_.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
    }

Get-DnsClientServerAddress -InterfaceAlias $ifAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Set-DnsClientServerAddress -ServerAddresses @('192.168.122.10')

New-NetIPAddress -InterfaceAlias $ifAlias -IPAddress '192.168.122.20' -PrefixLength 24 -DefaultGateway '192.168.122.1' -AddressFamily IPv4 | Out-Null
Set-DnsClientServerAddress -InterfaceAlias $ifAlias -ServerAddresses @('192.168.122.10')

Write-Host '[DC2] IP fixee en 192.168.122.20/24, DNS=192.168.122.10'

if ($env:COMPUTERNAME -ne 'DC02') {
    Rename-Computer -NewName 'DC02' -Force
    Write-Host '[DC2] Renomme en DC02 - redemarrage requis'
    Restart-Computer -Force
} else {
    Write-Host '[DC2] Nom deja correct'
}
