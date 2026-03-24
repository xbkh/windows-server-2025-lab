$ErrorActionPreference = 'Stop'

$domainCred = New-Object pscredential('SATOM\Administrateur', (ConvertTo-SecureString 'formation123.' -AsPlainText -Force))

$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-ExecutionPolicy Bypass -File C:\Formation\dc2_promote_startup.ps1'
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest -LogonType ServiceAccount
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
Register-ScheduledTask -TaskName 'PromoteDC02' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

Add-Computer -DomainName 'satom.local' -Credential $domainCred -Force -Restart
