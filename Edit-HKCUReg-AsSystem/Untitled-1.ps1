$Name = "DataSource"
$value = "https://agresso.surrey.ac.uk/Unit4ERP-reportengine/service.asmx"
$Name2 = "DataSources"
$Value2 = "https://agresso.surrey.ac.uk/Unit4ERP-reportengine/service.asmx"
$Auth = "Authenticator"
$AuthValue = "AgressoAuthenticator"

$Username = "UserName"
$Username2 = (Get-CimInstance Win32_Process -Filter 'name = "explorer.exe"' | Invoke-CimMethod -MethodName getowner).User
$Client = "Client"
$Client2 = "SY"

$userRegistryPath = "Registry::HKEY_CURRENT_USER\Software\UNIT4\ReportEngine\Login\WebService"
New-Item -Path $userRegistryPath -ItemType RegistryKey -Force | Out-Null
New-ItemProperty -Path $userRegistryPath -Name $name -Value $value -Type String -Force | Out-Null
New-ItemProperty -Path $userRegistryPath -Name $Name2 -Value $value2 -Type String -Force | Out-Null
New-ItemProperty -Path $userRegistryPath -Name $Auth -Value $AuthValue -Type String -Force | Out-Null

$userRegistryPath1 = "Registry::HKEY_CURRENT_USER\Software\UNIT4\ReportEngine\Login\WebService\AgressoAuthenticator"
New-Item -Path $userRegistryPath1 -ItemType RegistryKey -Force | Out-Null
New-ItemProperty -Path $userRegistryPath1 -Name $Username -Value $Username2 -Type String -Force | Out-Null
New-ItemProperty -Path $userRegistryPath1 -Name $Client -Value $Client2 -Type String -Force | Out-Null

# Create detection method. 
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\Agresso-Reg.txt"