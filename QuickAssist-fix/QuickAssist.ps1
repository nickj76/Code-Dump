Add-AppxProvisionedPackage -online -SkipLicense -PackagePath '.\QuickAssist.AppxBundle'

## Create Detection Method. 
$logfilespath = "C:\logfiles"
If(!(test-path $logfilespath))
{
      New-Item -ItemType Directory -Force -Path $logfilespath
}

New-Item -ItemType "file" -Path "c:\logfiles\store-quickassist.txt"