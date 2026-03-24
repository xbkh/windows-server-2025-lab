$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host '[AzureArc] PSGallery + NuGet' -ForegroundColor Cyan
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null

Write-Host '[AzureArc] Az modules' -ForegroundColor Cyan
Install-Module Az.Accounts -Force -AllowClobber -Scope AllUsers
Install-Module Az.ConnectedMachine -Force -AllowClobber -Scope AllUsers

$msiPath = 'C:\Windows\Temp\AzureConnectedMachineAgent.msi'
Write-Host '[AzureArc] Download agent' -ForegroundColor Cyan
Invoke-WebRequest -Uri 'https://aka.ms/AzureConnectedMachineAgent' -OutFile $msiPath

Write-Host '[AzureArc] Install agent' -ForegroundColor Cyan
Start-Process -FilePath 'msiexec.exe' -ArgumentList '/i', $msiPath, '/quiet', '/norestart' -Wait

Write-Host '[AzureArc] Verify' -ForegroundColor Cyan
Import-Module Az.Accounts
Import-Module Az.ConnectedMachine
Write-Host ('AgentInstalled=' + (Test-Path 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe'))
Get-Module -ListAvailable Az.Accounts,Az.ConnectedMachine | Select-Object Name,Version | Format-Table -AutoSize
if (Test-Path 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe') {
    & 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe' version
}
