Add-BitLockerKeyProtector -MountPoint c -TpmProtector
Restart-Computer -Force 

## Create Detection Method. 
$logfilespath = "C:\logfiles"
If(!(test-path $logfilespath))
{
      New-Item -ItemType Directory -Force -Path $logfilespath
}

New-Item -ItemType "file" -Path "c:\logfiles\undo-Missing-Device.txt"