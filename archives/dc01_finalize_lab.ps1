$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
Import-Module DhcpServer

# Associer le vrai sous-reseau au site Paris
try {
    New-ADReplicationSubnet -Name '192.168.122.0/24' -Site 'Site-Paris' -ErrorAction Stop
    Write-Host '[DC01] Subnet 192.168.122.0/24 associe a Site-Paris'
} catch {
    Write-Host '[DC01] Subnet 192.168.122.0/24 deja present ou non modifie'
}

# Mettre a jour les DNS client du DC01
$ifAlias = (Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1 -ExpandProperty Name)
if ($ifAlias) {
    Set-DnsClientServerAddress -InterfaceAlias $ifAlias -ServerAddresses @('192.168.122.20','127.0.0.1')
    Write-Host '[DC01] DNS client configure: 192.168.122.20 puis 127.0.0.1'
}

# Autoriser DHCP sur DC02
try {
    Add-DhcpServerInDC -DnsName 'DC02.satom.local' -IPAddress '192.168.122.20' -ErrorAction Stop
    Write-Host '[DC01] DHCP DC02 autorise dans AD'
} catch {
    Write-Host '[DC01] DHCP DC02 deja autorise ou indisponible'
}

# Configurer le failover DHCP si possible
try {
    if (-not (Get-DhcpServerv4Failover -Name 'FO-DC01-DC02' -ErrorAction SilentlyContinue)) {
        Add-DhcpServerv4Failover -ComputerName 'DC01' -Name 'FO-DC01-DC02' -PartnerServer 'DC02' -ScopeId 192.168.122.0 -LoadBalancePercent 50 -MaxClientLeadTime 01:00:00 -AutoStateTransition $true -SharedSecret 'formation123.'
        Write-Host '[DC01] Failover DHCP configure avec DC02'
    } else {
        Write-Host '[DC01] Failover DHCP deja present'
    }
} catch {
    Write-Host "[DC01] Failover DHCP non configure: $($_.Exception.Message)"
}

# DNS conditionnel si besoin
Write-Host '[DC01] Finalisation terminee'
