$ErrorActionPreference = 'Stop'

try {
    Unregister-ScheduledTask -TaskName 'PromoteDC02' -Confirm:$false -ErrorAction SilentlyContinue
} catch {}

$domainName = 'satom.local'
$domainUser = 'SATOM\Administrateur'
$domainPassword = ConvertTo-SecureString 'formation123.' -AsPlainText -Force
$domainCred = New-Object System.Management.Automation.PSCredential($domainUser, $domainPassword)
$dsrmPassword = ConvertTo-SecureString 'P@ssw0rd2025!' -AsPlainText -Force

Install-ADDSDomainController `
    -DomainName $domainName `
    -Credential $domainCred `
    -InstallDns:$true `
    -NoGlobalCatalog:$false `
    -SafeModeAdministratorPassword $dsrmPassword `
    -Force:$true
