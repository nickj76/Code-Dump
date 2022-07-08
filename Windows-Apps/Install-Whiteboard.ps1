Add-AppxProvisionedPackage -online -SkipLicense -PackagePath "C:\Temp\Microsoft.Whiteboard_52.10201.5809.0_neutral___8wekyb3d8bbwe.AppxBundle"

## Create Detection Method. 
$logfilespath = "C:\logfiles"
If(!(test-path $logfilespath))
{
      New-Item -ItemType Directory -Force -Path $logfilespath
}

New-Item -ItemType "file" -Path "c:\logfiles\store-whiteboard.txt"






