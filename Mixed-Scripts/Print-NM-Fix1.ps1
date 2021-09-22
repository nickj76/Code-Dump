$Regpath = "HKLM:\Software\Policies\Microsoft\Windows\DriverInstall\Restrictions\AllowUserDeviceClasses"
$RegAllowPath = "HKLM:\Software\Policies\Microsoft\Windows\DriverInstall\Restrictions"

$name1 = "printer"
$value1 = "{4658ee7e-f050-11d1-b6bd-00c04fa372a7}"
$name2 = "PNPprinter"
$value2 ="{4d36e979-e325-11ce-bfc1-08002be10318}"
$name3="AllowUserDeviceClasses"
$value3 = 1

New-ItemProperty -Path $RegPath -Name $name1 -Value $value1 -PropertyType String | Out-Null
New-ItemProperty -Path $RegPath -Name $name2 -Value $value2 -PropertyType String | Out-Null
New-ItemProperty -Path $RegallowPath -Name $name3 -Value $value3 -PropertyType DWord | Out-Null

## Create Detection Method.
$path = "C:\logfiles"
   If(!(test-path $path))
 {
      New-Item -ItemType Directory -Force -Path $path
 }

New-Item -ItemType "file" -Path "c:\logfiles\Printfix1.txt"