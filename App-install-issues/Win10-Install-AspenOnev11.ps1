<# 
.SYNOPSIS
   Install Script for AspenOne

.DESCRIPTION
   Downloads AspenOnev11 installer media and unpacks it to c:\temp\aspen then installs AspenOnev11, upon completion of install c:\temp\aspen is deleted.

.EXAMPLE
   PS C:\> .\Win10-Install-AspenOnev11.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v3+
#>

## Installs Command for AspenONE.
## &c:\temp\aspen\AtRunUnattended.exe "aspenONE Engineering V11.xml" /S /noreboot /L logfile="%TEMP%\aspenONE Engineering V11.log" altsource="." | Out-Null

## Check to see if logfiles directory exists, if it is does not creates it and places 0k txt file of application name here for use as detection method. 
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\aspenOnev11-files.txt"

## Removes c:\temp\aspen.
## if (test-path c:\temp\aspen){
##	remove-item -Path c:\temp\aspen -force -recurse -Verbose -ErrorAction SilentlyContinue
##	} 