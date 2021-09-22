<# 
.SYNOPSIS
   Add Konica Minolta Universal x64 PCL V4 Printer Driver to DriverStore.

.DESCRIPTION
   Script to unzip and add the Konica Minolta Universal x64 PCL V4 Printer Driver to DriverStore.

.EXAMPLE
   PS C:\> .\Win10-Add-KMUPDv4.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt. 

.FUNCTIONALITY
   PowerShell v1+
#>

## Add printer drivers to driverstore
pnputil.exe -i -a  C:\temp\Printer\*.inf

## Pause for 30 seconds to allow install to completed.
Start-Sleep -Seconds 30

## Add Printer Driver to windows
Add-PrinterDriver -Name "Samsung Universal Print Driver 2 PCL6"

## Create Detection Method.
$path = "C:\logfiles"
   If(!(test-path $path))
 {
      New-Item -ItemType Directory -Force -Path $path
 }

New-Item -ItemType "file" -Path "c:\logfiles\SamsungDriver.txt"