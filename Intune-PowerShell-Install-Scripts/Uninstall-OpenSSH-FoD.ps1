<# 
.SYNOPSIS
   Uninstall OpenSSH Client & Server 

.DESCRIPTION
   Uninstalls the Application & removes the associated txt file from the logfiles directory.

.EXAMPLE
   PS C:\> .\uninstall-OpenSSH-FoD.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.NOTES
   None.

.FUNCTIONALITY
   PowerShell v3+
#>

# Uninstall the OpenSSH Client
Remove-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

# Uninstall the OpenSSH Server
Remove-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

Remove-Item -ItemType "file" -Path "c:\logfiles\OpenSSH.txt"