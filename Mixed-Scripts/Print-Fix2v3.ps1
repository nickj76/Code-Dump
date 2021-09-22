$keypath = “HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint”
$keypath2 = “HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PackagePointAndPrint”
$keypath3= “HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\ListofServers”
$keypath4 = “HKLM:\Software\Policies\Microsoft\Windows\DriverInstall\Restrictions\AllowUserDeviceClasses”
$keypath5 = “HKLM:\Software\Policies\Microsoft\Windows\DriverInstall\Restrictions”

New-Item -Path $keyPath -force | Out-Null
New-Item -Path $keyPath2 -force | Out-Null
New-Item -Path $keyPath3 -force | Out-Null
New-Item -Path $keypath5 -force | Out-Null
New-Item -Path $keypath4 -force | Out-Null

new-ItemProperty -Path $keypath -Name RestrictDriverInstallationToAdministrators -Value 0 -force
new-ItemProperty -Path $keypath -Name TrustedServers -Value 1 -force
new-ItemProperty -Path $keypath -Name Restricted -Value 0 -force
new-ItemProperty -Path $keypath -Name NoWarningNoElevationOnInstall -Value 1 -force
new-ItemProperty -Path $keypath -Name TrustedServers -Value 1 -force
new-ItemProperty -Path $keypath -Name UpdatePromptSettings -Value 2 -force
new-itemproperty -path $keyPath -Name Serverlist -type string -value winprint.surrey.ac.uk -force

new-ItemProperty -Path $keypath2 -Name PackagePointAndPrintServerList -Value 1 -force
new-ItemProperty -Path $keypath3 -Name winprint.surrey.ac.uk -Value winprint.surrey.ac.uk -force

$name1 = “printer”
$value1 = “{4658ee7e-f050-11d1-b6bd-00c04fa372a7}”
$name2 = “PNPprinter”
$value2 =”{4d36e979-e325-11ce-bfc1-08002be10318}”
$name3=”AllowUserDeviceClasses”
$value3 = 1
$name4 = “LocalPrintQueue”
$value4 = “{1ed2bbf9-11f0-4084-b21f-ad83a8e6dcdc}”

New-ItemProperty -Path $keypath4 -Name $name3 -Value $value3 -PropertyType Dword | Out-Null
New-ItemProperty -Path $keypath5 -Name $name1 -Value $value1 -PropertyType String | Out-Null
New-ItemProperty -Path $keypath5 -Name $name2 -Value $value2 -PropertyType String | Out-Null
New-ItemProperty -Path $keypath5 -Name $name4 -Value $value4 -PropertyType String | Out-Null