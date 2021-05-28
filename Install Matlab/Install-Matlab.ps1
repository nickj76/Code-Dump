<# 
.SYNOPSIS
   Install Script for Matlab2021a

.DESCRIPTION
   Installs Matlab2021a and cleansup after it has completed the install.

.EXAMPLE
   PS C:\> .\Install-Matlab.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v3+
#>

## Installs Command for Matlab2021a
&c:\temp\matlab\bin\win64\setup.exe -inputFile c:\temp\matlab\installer_input.txt | Out-Null
del "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\MATLAB R2021a\Activate MATLAB R2021a.lnk"
del "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\MATLAB R2021a\Deactivate MATLAB R2021a.lnk"

## Removes c:\temp\matlab
if (test-path c:\temp\matlab){
	remove-item -Path c:\temp\matlab -force -recurse -Verbose -ErrorAction SilentlyContinue
	} 