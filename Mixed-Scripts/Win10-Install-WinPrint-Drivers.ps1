<# 
.SYNOPSIS
   Install WinPrint Drivers.

.DESCRIPTION
   Script to add device drivers to the driverstore.

.EXAMPLE
   PS C:\> .\Win10-Install-WinPrint-Drivers.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt. 

.FUNCTIONALITY
   PowerShell v1+
#>

&"C:\Program Files\7-Zip\7z.exe" x -oc:\temp\ -y *.7z

## Add printer drivers to driverstore
pnputil.exe -a C:\temp\winprint\*.inf /subdirs

# Create Detection Method.
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\WinPrint-Drivers.txt"