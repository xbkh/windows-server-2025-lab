$ErrorActionPreference = 'Continue'

Remove-DhcpServerInDC -DnsName 'dc01.satom.local' -IPAddress '192.168.100.10' -Confirm:$false -ErrorAction SilentlyContinue

if (-not (Get-DhcpServerv4Failover -Name 'FO-DC01-DC02' -ErrorAction SilentlyContinue)) {
    Add-DhcpServerv4Failover -ComputerName 'DC01' -Name 'FO-DC01-DC02' -PartnerServer 'DC02' -ScopeId 192.168.122.0 -LoadBalancePercent 50 -MaxClientLeadTime 01:00:00 -AutoStateTransition $true -SharedSecret 'formation123.' -Force
}

Write-Host '=== DHCP autorises ==='
Get-DhcpServerInDC | Select-Object DnsName,IPAddress | Format-Table -AutoSize

Write-Host '=== DHCP failover ==='
Get-DhcpServerv4Failover -ErrorAction SilentlyContinue | Select-Object Name,PartnerServer,Mode,State | Format-Table -AutoSize
