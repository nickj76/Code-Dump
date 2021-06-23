<# 
.SYNOPSIS
   Install Script for Matlab2021a

.DESCRIPTION
   Downloads matlab installer media and unpacks it to c:\temp\matlab then installs Matlab2021a, upon completion of install c:\temp\matlab is deleted.

.EXAMPLE
   PS C:\> .\Install-Matlab.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v3+
#>

## Installs Command for Matlab2021a.
&c:\temp\matlab\bin\win64\setup.exe -inputFile c:\temp\matlab\installer_input.txt | Out-Null
del "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\MATLAB R2021a\Activate MATLAB R2021a.lnk"
del "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\MATLAB R2021a\Deactivate MATLAB R2021a.lnk"

## Check to see if logfiles directory exists, if it is does not creates it and places 0k txt file of application name here for use as detection method. 
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\matlab.txt"

## Removes c:\temp\matlab.
if (test-path c:\temp\matlab){
	remove-item -Path c:\temp\matlab -force -recurse -Verbose -ErrorAction SilentlyContinue
	} 