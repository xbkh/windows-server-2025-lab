$ErrorActionPreference = 'Stop'

$domainName = 'satom.local'
$domainUser = 'SATOM\Administrateur'
$domainPassword = ConvertTo-SecureString 'formation123.' -AsPlainText -Force
$domainCred = New-Object System.Management.Automation.PSCredential($domainUser, $domainPassword)
$dsrmPassword = ConvertTo-SecureString 'P@ssw0rd2025!' -AsPlainText -Force

Write-Host '[DC2] Installation des roles AD DS / DNS / DHCP...'
Install-WindowsFeature AD-Domain-Services,DNS,DHCP,RSAT-AD-Tools,RSAT-DNS-Server,RSAT-DHCP -IncludeManagementTools | Out-Null

Write-Host '[DC2] Promotion en controleur de domaine secondaire...'
Install-ADDSDomainController `
    -DomainName $domainName `
    -Credential $domainCred `
    -InstallDns:$true `
    -NoGlobalCatalog:$false `
    -SafeModeAdministratorPassword $dsrmPassword `
    -Force:$true
