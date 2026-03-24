Write-Host "=== Partages SMB ==="
Get-SmbShare | Where-Object {$_.Name -notmatch '\$'} | Select-Object Name,Path | Format-Table -AutoSize

Write-Host "=== Service Server ==="
Get-Service LanmanServer | Select-Object Name,Status

Write-Host "=== DFS Namespace ==="
Get-DfsnRoot -ErrorAction SilentlyContinue | Select-Object Path,State | Format-Table -AutoSize
Get-DfsnFolder -Path "\\satom.local\data\*" -ErrorAction SilentlyContinue | Select-Object Path,State | Format-Table -AutoSize

Write-Host "=== Test acces partage Commun ==="
Test-Path "\\DC01\Commun"
Test-Path "\\satom.local\data\Commun"

Write-Host "=== Dossiers physiques ==="
Get-Item "C:\Partages\*" -ErrorAction SilentlyContinue | Select-Object FullName

Write-Host "=== Firewall SMB ==="
Get-NetFirewallRule | Where-Object {$_.DisplayName -match 'SMB|File|445'} | Select-Object DisplayName,Enabled,Direction,Action | Format-Table -AutoSize
