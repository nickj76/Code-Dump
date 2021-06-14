<# 
.SYNOPSIS
   Stop all running adobe processes. 

.DESCRIPTION
   Stop all running adobe processes in order to allow adobe to update and get around ABR

.EXAMPLE
   PS C:\> .\Adobe-update.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.NOTES
   This script will typically clean up anywhere from 1GB up to 15GB of space from a C: drive.

.FUNCTIONALITY
   PowerShell v3+
#>

Get-Process -Name Adobe* | Stop-Process -Force
Get-Process -Name CCLibrary | Stop-Process -Force
Get-Process -Name CCXProcess | Stop-Process -Force
Get-Process -Name CoreSync | Stop-Process -Force
Get-Process -Name AdobeIPCBroker | Stop-Process -Force
Get-Process -Name Adobe CEF Helper | Stop-Process -Force
