$TpmProtectorID = ((Get-BitLockerVolume -MountPoint c).KeyProtector | Where-Object KeyProtectorType -EQ 'Tpm').KeyProtectorID
Remove-BitLockerKeyProtector -MountPoint c -KeyProtectorId $TpmProtectorID
Stop-Computer -Force

## Create Detection Method. 
$logfilespath = "C:\logfiles"
If(!(test-path $logfilespath))
{
      New-Item -ItemType Directory -Force -Path $logfilespath
}

New-Item -ItemType "file" -Path "c:\logfiles\Missing-Device.txt"
