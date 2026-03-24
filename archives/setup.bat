@echo off
echo ============================================
echo  Formation Windows Server 2025 - Setup DC01
echo ============================================
echo.

:: Verifier les droits admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERREUR: Relancez ce script en tant qu'Administrateur
    pause
    exit /b 1
)

echo [1/5] Configuration IP statique (192.168.122.10)...
powershell -NoProfile -Command "Remove-NetIPAddress -InterfaceAlias 'Ethernet' -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue; Remove-NetRoute -InterfaceAlias 'Ethernet' -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue; New-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress '192.168.122.10' -PrefixLength 24 -DefaultGateway '192.168.122.1' | Out-Null; Set-DnsClientServerAddress -InterfaceAlias 'Ethernet' -ServerAddresses '127.0.0.1','192.168.122.10'; Write-Host 'IP OK'"
echo.

echo [2/5] Renommage du serveur en DC01...
powershell -NoProfile -Command "if ($env:COMPUTERNAME -ne 'DC01') { Rename-Computer -NewName 'DC01' -Force; Write-Host 'Renomme en DC01' } else { Write-Host 'Deja nomme DC01' }"
echo.

echo [3/5] Activation RDP et regle SSH...
powershell -NoProfile -Command "Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 0; Enable-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction SilentlyContinue; netsh advfirewall firewall add rule name='OpenSSH-In' dir=in action=allow protocol=TCP localport=22 | Out-Null; Write-Host 'RDP et SSH OK'"
echo.

echo [4/5] Installation du role AD DS (peut prendre 2-3 minutes)...
powershell -NoProfile -Command "Install-WindowsFeature -Name AD-Domain-Services,RSAT-AD-Tools,GPMC,RSAT-DNS-Server,RSAT-DHCP -IncludeManagementTools | Out-Null; Write-Host 'AD DS installe'"
echo.

echo [5/5] Promotion en controleur de domaine satom.local...
echo       Le serveur va REDEMARRER automatiquement apres cette etape.
echo.
powershell -NoProfile -Command "$pwd = ConvertTo-SecureString 'P@ssw0rd2025!' -AsPlainText -Force; Import-Module ADDSDeployment; Install-ADDSForest -DomainName 'satom.local' -DomainMode WinThreshold -ForestMode WinThreshold -InstallDns:$true -SafeModeAdministratorPassword $pwd -CreateDnsDelegation:$false -DatabasePath 'C:\Windows\NTDS' -SysvolPath 'C:\Windows\SYSVOL' -LogPath 'C:\Windows\NTDS' -NoRebootOnCompletion:$false -Force:$true"

echo.
echo Si le serveur ne redemmarre pas automatiquement, tapez: shutdown /r /t 5
pause
