$id = "9F1CFF02-A68D-405C-B714-4F7EF2C3D2FB"
$path = "C:\Windows\SYSVOL\sysvol\satom.local\Policies\{$id}"
Write-Host "Chemin GPO: $path"
Write-Host "Existe: $(Test-Path $path)"
Get-ChildItem -Recurse $path | Select FullName
