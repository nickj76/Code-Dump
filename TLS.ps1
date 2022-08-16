<# 
.SYNOPSIS
Disable the following;
TLS 1.0
TLS 1.1
SSL 3.0
SSL 2.0

Enable the following;
TLS 1.2   
TLS 1.3 

.DESCRIPTION
.\Secure-TLS.ps1
#>

# Disable TLS 1.1 (TLS 1.1 Server should be disabled by default in Windows Server 2008 R2, this is here just in case)
New-Itemproperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server' -name Enabled -value 0 -PropertyType "DWord"
New-Itemproperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server' -name "DisabledByDefault" -value 0 -PropertyType "DWord"
New-Itemproperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client' -name Enabled -value 0 -PropertyType "DWord"
New-Itemproperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client' -name "DisabledByDefault" -value 1 -PropertyType "DWord"
Write-Host -ForegroundColor Yellow 'Disabled TLS 1.1 registry keys for client and server SCHANNEL communications'

# Disable TLS 1.0
New-Itemproperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server' -name Enabled -value 0 -PropertyType "DWord"
New-Itemproperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server' -name "DisabledByDefault" -value 0 -PropertyType "DWord"
New-Itemproperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client' -name Enabled -value 0 -PropertyType "DWord"
New-Itemproperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client' -name "DisabledByDefault" -value 0 -PropertyType "DWord"
Write-Host -ForegroundColor Yellow 'Disabled TLS 1.0 registry keys for client and server SCHANNEL communications'

# Disable SSL 3.0
New-Itemproperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server' -name Enabled -value 0 -PropertyType "DWord"
New-Itemproperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server' -name "DisabledByDefault" -value 1 -PropertyType "DWord"
New-Itemproperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client' -name Enabled -value 0 -PropertyType "DWord"
New-Itemproperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client' -name "DisabledByDefault" -value 1 -PropertyType "DWord"
Write-Host -ForegroundColor Yellow 'Disabled SSL 3.0 registry keys for client and server SCHANNEL communications'

# Disable SSL 2.0 (SSL 2.0 client should be disabled by default in Windows Server 2008 R2 but adding this just in case)
New-Itemproperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server' -name Enabled -value 0 -PropertyType "DWord"
New-Itemproperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server' -name "DisabledByDefault" -value 1 -PropertyType "DWord"
New-Itemproperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client' -name "DisabledByDefault" -value 1 -PropertyType "DWord"
New-Itemproperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client' -name Enabled -value 0 -PropertyType "DWord"
Write-Host -ForegroundColor Yellow 'Disabled SSL 2.0 registry keys for client and server SCHANNEL communications'

# Enable TLS 1.2
New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -name 'Enabled' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -name 'DisabledByDefault' -value 0 -PropertyType 'DWord' -Force | Out-Null
New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -name 'Enabled' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -name 'DisabledByDefault' -value 0 -PropertyType 'DWord' -Force | Out-Null
Write-Host -ForegroundColor Yellow 'Enabled TLS 1.2 registry keys for client and server SCHANNEL communications'

# Set the system to use the strong Crypto for .Net on x86 & x64
New-Item 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319' -name 'SystemDefaultTlsVersions' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319' -name 'SchUseStrongCrypto' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-Item 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -name 'SystemDefaultTlsVersions' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -name 'SchUseStrongCrypto' -value '1' -PropertyType 'DWord' -Force | Out-Null
Write-Host -ForegroundColor Yellow 'Set the system to use the strong Crypto for .Net on x86 & x64'

# Enable TLS 1.3
New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server' -name 'Enabled' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server' -name 'DisabledByDefault' -value 0 -PropertyType 'DWord' -Force | Out-Null
New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client' -name 'Enabled' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client' -name 'DisabledByDefault' -value 0 -PropertyType 'DWord' -Force | Out-Null
Write-Host -ForegroundColor Yellow 'Enabled TLS 1.3 registry keys for client and server SCHANNEL communications'