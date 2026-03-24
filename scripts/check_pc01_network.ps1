Write-Host "=== Test DNS ==="
Resolve-DnsName "satom.local" -ErrorAction SilentlyContinue | Select-Object Name,IPAddress
Resolve-DnsName "DC01.satom.local" -ErrorAction SilentlyContinue | Select-Object Name,IPAddress

Write-Host "=== Test ping DC01 ==="
Test-Connection -ComputerName 192.168.122.10 -Count 1 -ErrorAction SilentlyContinue | Select-Object Address,ResponseTime

Write-Host "=== Test acces partages ==="
Test-Path "\\DC01\Commun"
Test-Path "\\satom.local\data\Commun"

Write-Host "=== Service DFS Client ==="
Get-Service DfsC -ErrorAction SilentlyContinue | Select-Object Name,Status

Write-Host "=== Lecteurs mappes ==="
Get-PSDrive -PSProvider FileSystem | Where-Object {$_.DisplayRoot} | Select-Object Name,DisplayRoot

Write-Host "=== Registre Network ==="
Get-ChildItem "HKCU:\Network" -ErrorAction SilentlyContinue | ForEach-Object {
    $name = $_.PSChildName
    $path = (Get-ItemProperty $_.PSPath -Name RemotePath -ErrorAction SilentlyContinue).RemotePath
    Write-Host "  Lecteur $name -> $path"
}

Write-Host "=== DNS serveur configure ==="
Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object {$_.ServerAddresses} | Select-Object InterfaceAlias,ServerAddresses
