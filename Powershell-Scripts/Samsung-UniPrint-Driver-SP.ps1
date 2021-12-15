<# 
.SYNOPSIS
   Install Script to add the Surrey Print Driver to Windows.

.DESCRIPTION
   Add the Samsung Universal Print Driver for SurreyPrint to the Windows Driver store and make avaliable for use. 

.EXAMPLE
   PS C:\> .\Samsung-UniPrint-Driver.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v1+
#>

Start-Transcript -Path c:\temp\SamsungDriver.txt

&"C:\Program Files\7-Zip\7z.exe" x -oc:\temp\ -y *.7z

Get-ChildItem "C:\temp\printer" -Recurse -Filter "*.inf" | 
ForEach-Object { C:\Windows\Sysnative\PNPUtil.exe /add-driver $_.FullName /install }

add-printerdriver -name 'Samsung Universal Print Driver 2 PCL6'

Add-Printer -ConnectionName \\printservice\SSP_DUTY-00_X4250LX

# Create Detection Method.
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\SamsungUniPrintDriver.txt"
Stop-Transcript
















