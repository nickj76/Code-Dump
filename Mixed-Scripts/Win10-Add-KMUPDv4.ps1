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

&"C:\Program Files\7-Zip\7z.exe" x -oc:\temp\ -y *.7z

## Add printer drivers to driverstore
pnputil.exe -i -a  C:\temp\X64-UniversalKonicaPCL\*.inf

Create Detection Method.
$path = "C:\logfiles"
   If(!(test-path $path))
 {
      New-Item -ItemType Directory -Force -Path $path
 }

New-Item -ItemType "file" -Path "c:\logfiles\Konica-Minolta-UPD.txt"