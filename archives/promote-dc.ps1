$pwd = ConvertTo-SecureString 'P@ssw0rd2025!' -AsPlainText -Force
Import-Module ADDSDeployment
Install-ADDSForest `
    -DomainName 'satom.local' `
    -DomainMode WinThreshold `
    -ForestMode WinThreshold `
    -InstallDns:$true `
    -SafeModeAdministratorPassword $pwd `
    -CreateDnsDelegation:$false `
    -DatabasePath 'C:\Windows\NTDS' `
    -SysvolPath 'C:\Windows\SYSVOL' `
    -LogPath 'C:\Windows\NTDS' `
    -NoRebootOnCompletion:$false `
    -Force:$true
