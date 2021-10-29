<# 
.SYNOPSIS
   Install Script to add the WinPrint Printer Drivers to Windows.

.DESCRIPTION
   Add the various printer drivers installed on WinPrint to the Windows Driver store and make avaliable for use. 

.EXAMPLE
   PS C:\> .\WinPrint-Print-Drivers.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v1+
#>

Start-Transcript -Path c:\temp\WinPrintDrivers.txt

&"C:\Program Files\7-Zip\7z.exe" x -oc:\temp\ -y *.7z

Get-ChildItem "C:\temp\Winprint\" -Recurse -Filter "*.inf" | 
ForEach-Object { C:\Windows\Sysnative\PNPUtil.exe /add-driver $_.FullName /install /Subdirs }

# Create Detection Method.
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\WinPrint-Print-Driver.txt"
Stop-Transcript


















