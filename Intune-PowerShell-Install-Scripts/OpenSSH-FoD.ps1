<# 
.SYNOPSIS
   Install OpenSSH Client & Server 

.DESCRIPTION
   Installs the Application & checks to see if the logfiles directory exists if it does not it creates it.

.EXAMPLE
   PS C:\> .\OpenSSH-FoD.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.NOTES
   None.

.FUNCTIONALITY
   PowerShell v3+
#>

Get-WindowsCapability -Online -Name Open* | Add-WindowsCapability -Online

$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\OpenSSH.txt"