Write-Host "=== Service NPS ==="
Get-Service IAS -ErrorAction SilentlyContinue | Select-Object Name,Status

Write-Host "=== Clients RADIUS ==="
$npsConfig = [xml](netsh nps export filename="C:\Formation\nps_export.xml" exportPSK=YES 2>&1)
netsh nps show client 2>&1

Write-Host "=== Politiques reseau ==="
netsh nps show np 2>&1

Write-Host "=== Politiques connexion ==="
netsh nps show crp 2>&1
