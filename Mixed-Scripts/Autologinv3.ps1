### Store Credentials
$Username = "insert code here"
$DecUsername = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($Username))
$Pass = "insert code here"
$DecPass = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($Pass))

### The code below configures Auto-Login on Windows computers ###

$RegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty $RegistryPath 'AutoAdminLogon' -Value "1" -Type String 
Set-ItemProperty $RegistryPath 'ForceAutoLogon' -Value "1" -type String
Set-ItemProperty $RegistryPath 'DefaultUsername' -Value "$DecUsername" -type String 
Set-ItemProperty $RegistryPath 'DefaultDomainName' -Value "Surrey" -type String
Set-ItemProperty $RegistryPath 'DefaultPassword' -Value "$DecPass" -type String
 
Write-Warning "Auto-Login for $username configured. Please restart computer."
 
$restart = Read-Host 'Do you want to restart your computer now for testing auto-logon? (Y/N)'
 
If ($restart -eq 'Y') {
 
    Restart-Computer -Force
 
}