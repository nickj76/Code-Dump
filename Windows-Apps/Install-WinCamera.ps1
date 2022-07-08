Add-AppxProvisionedPackage -online -SkipLicense -PackagePath "C:\Temp\Microsoft.WindowsCamera_2022.2205.8.0_neutral___8wekyb3d8bbwe.Msixbundle"

## Create Detection Method. 
$logfilespath = "C:\logfiles"
If(!(test-path $logfilespath))
{
      New-Item -ItemType Directory -Force -Path $logfilespath
}

New-Item -ItemType "file" -Path "c:\logfiles\store-Camera.txt"






