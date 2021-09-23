New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint' -force | Out-Null
New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PackagePointAndPrint' -force | Out-Null
New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\ListofServers' -force | Out-Null
New-Item -Path 'HKLM:\Software\Policies\Microsoft\Windows\DriverInstall\Restrictions' -force | Out-Null
New-Item -Path 'HKLM:\Software\Policies\Microsoft\Windows\DriverInstall\Restrictions\AllowUserDeviceClasses' -force | Out-Null

new-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint' -Name RestrictDriverInstallationToAdministrators -Value 0 -force
new-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint' -Name TrustedServers -Value 1 -force
new-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint' -Name Restricted -Value 0 -force
new-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint' -Name NoWarningNoElevationOnInstall -Value 1 -force
new-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint' -Name TrustedServers -Value 1 -force
new-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint' -Name UpdatePromptSettings -Value 2 -force
new-itemproperty -path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint' -Name Serverlist -type string -value winprint.surrey.ac.uk -force

new-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PackagePointAndPrint' -Name PackagePointAndPrintServerList -Value 1 -force
new-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\ListofServers' -Name winprint.surrey.ac.uk -Value winprint.surrey.ac.uk -force

$name1 = “printer”
$value1 = “{4658ee7e-f050-11d1-b6bd-00c04fa372a7}”
$name2 = “PNPprinter”
$value2 =”{4d36e979-e325-11ce-bfc1-08002be10318}”
$name3=”AllowUserDeviceClasses”
$value3 = 1
$name4 = “LocalPrintQueue”
$value4 = “{1ed2bbf9-11f0-4084-b21f-ad83a8e6dcdc}”

New-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\DriverInstall\Restrictions\AllowUserDeviceClasses' -Name $name3 -Value $value3 -PropertyType Dword | Out-Null
New-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\DriverInstall\Restrictions' -Name $name1 -Value $value1 -PropertyType String | Out-Null
New-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\DriverInstall\Restrictions' -Name $name2 -Value $value2 -PropertyType String | Out-Null
New-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\DriverInstall\Restrictions' -Name $name4 -Value $value4 -PropertyType String | Out-Null