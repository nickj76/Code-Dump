#Writing log to root of C:\ when TLS changes were applied to the server
$Title = "Enabling TLS 1.2 on this servername:"
$Eof = "Completed!"
$startdate = Get-Date -Format "HH:mm:ss.fff"
$enddate = Get-Date -Format "HH:mm:ss.fff"
$logfile = "C:\TLS1.2.log"
$serv = "$env:COMPUTERNAME"
New-Item $logfile -Type "File" -Force | out-null
Get-Date | Out-file $logfile -append
"[$startdate][Startup]  $Title $serv" | Out-file $logfile -append  


Write-Host -ForegroundColor Yellow "Creating the Protocol Server and Client registry keys"

# These keys do not exist so they need to be created prior to setting values.
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client"


# Enable TLS 1.2 for client and server SCHANNEL communications
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" -name "Enabled" -value 1 -PropertyType "DWord"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" -name "DisabledByDefault" -value 0 -PropertyType "DWord"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" -name "Enabled" -value 1 -PropertyType "DWord"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" -name "DisabledByDefault" -value 0 -PropertyType "DWord"
Write-Host -ForegroundColor Yellow "Enabled TLS 1.2 registry keys for client and server SCHANNEL communications"

# Disable TLS 1.1 (TLS 1.1 Server should be disabled by default in Windows Server 2008 R2, but setting it here just in case)
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server" -name Enabled -value 0 -PropertyType "DWord"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server" -name "DisabledByDefault" -value 0 -PropertyType "DWord"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client" -name Enabled -value 0 -PropertyType "DWord"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client" -name "DisabledByDefault" -value 1 -PropertyType "DWord"
Write-Host -ForegroundColor Yellow "Disabled TLS 1.1 registry keys for client and server SCHANNEL communications"

# Disable TLS 1.0
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server" -name Enabled -value 0 -PropertyType "DWord"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server" -name "DisabledByDefault" -value 0 -PropertyType "DWord"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client" -name Enabled -value 0 -PropertyType "DWord"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client" -name "DisabledByDefault" -value 0 -PropertyType "DWord"
Write-Host -ForegroundColor Yellow "Disabled TLS 1.0 registry keys for client and server SCHANNEL communications"

# Disable SSL 3.0
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server" -name Enabled -value 0 -PropertyType "DWord"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server" -name "DisabledByDefault" -value 1 -PropertyType "DWord"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client" -name Enabled -value 0 -PropertyType "DWord"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client" -name "DisabledByDefault" -value 1 -PropertyType "DWord"
Write-Host -ForegroundColor Yellow "Disabled SSL 3.0 registry keys for client and server SCHANNEL communications"

# Disable SSL 2.0 (SSL 2.0 client should be disabled by default in Windows Server 2008 R2 but adding this just in case)
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server" -name Enabled -value 0 -PropertyType "DWord"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server" -name "DisabledByDefault" -value 1 -PropertyType "DWord"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client" -name "DisabledByDefault" -value 1 -PropertyType "DWord"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client" -name Enabled -value 0 -PropertyType "DWord"
Write-Host -ForegroundColor Yellow "Disabled SSL 2.0 registry keys for client and server SCHANNEL communications"

# Registering the organization who owns the system in the registry to show up in %WINVER% and to be searched by SCCM or CI Management
Set-itemproperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -name "RegisteredOrganization" -value $projown
Set-itemproperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -name "RegisteredOwner" -value $proj

#Disable Weak Cyphers
Write-Host -ForegroundColor Yellow "Disabling weak Cyphers now" 

mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\Null"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\Null" -name "Enabled" -value 0 -PropertyType "Dword"

mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\DES 56"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\DES 56/56"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\DES 56/56" -name "Enabled" -value 0 -PropertyType "Dword"

mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC2 40"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC2 40/128"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC2 40/128" -name "Enabled" -value 0 -PropertyType "Dword"

mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC2 56"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC2 56/128"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC2 40/128" -name "Enabled" -value 0 -PropertyType "Dword"

mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC2 128"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC2 128/128"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC2 128/128" -name "Enabled" -value 0 -PropertyType "Dword"

mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 40"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 40/128"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 40/128" -name "Enabled" -value 0 -PropertyType "Dword"

mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 56"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 56/128"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 56/128" -name "Enabled" -value 0 -PropertyType "Dword"

mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 64"
mkdir "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 64/128"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 64/128" -name "Enabled" -value 0 -PropertyType "Dword"

Write-Host -ForegroundColor Green "Finished disabling weak Cyphers now"

#Setting the system to use the strong Crypto for x64 .Net (For 32-bit applications on 32-bit systems and 64-bit applications on x64-based systems)
new-itemproperty -path "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" -name "SchUseStrongCrypto" -value 1 -PropertyType "Dword"

#Setting the system to use the strong Crypto for x64 .Net (For 64-bit applications on x64-based systems:)
new-itemproperty -path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319" -name "SchUseStrongCrypto" -value 1 -PropertyType "Dword"

#Setting the recommended cipher order
Write-Host -ForegroundColor Yellow "Adding Cipher Order to the System!"
Set-ItemProperty -path "HKLM:\SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010002" -name "Functions" -value "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA_P256,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA_P384,TLS_RSA_WITH_AES_256_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA,TLS_RSA_WITH_RC4_128_SHA,TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_128_CBC_SHA,TLS_RSA_WITH_3DES_EDE_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256_P256,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256_P384,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA_P256,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA_P384,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256_P256,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256_P256,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384_P384,TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384_P384,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA_P256,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA_P384,TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA_P256,TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA_P384,TLS_DHE_DSS_WITH_AES_128_CBC_SHA256,TLS_DHE_DSS_WITH_AES_128_CBC_SHA,TLS_DHE_DSS_WITH_AES_256_CBC_SHA256,TLS_DHE_DSS_WITH_AES_256_CBC_SHA,TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA,TLS_RSA_WITH_RC4_128_MD5,SSL_CK_RC4_128_WITH_MD5,SSL_CK_DES_192_EDE3_CBC_WITH_MD"

# Closing to the log file when the process completed
"[$enddate][End]  $Eof" | Out-file $logfile -append

Write-Host -ForegroundColor Green "Completed! Please check registry keys and TLS compliance after the reboot to complete the process.`r`n"
Write-Host -ForegroundColor Green "The system will reboot in ten seconds. `r`n"

Start-Sleep -Seconds 10

# Rebooting Server for shanges to take effect
Restart-Computer -ComputerName $serv -force