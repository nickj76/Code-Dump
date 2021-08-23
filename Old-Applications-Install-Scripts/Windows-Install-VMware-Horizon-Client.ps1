<# 
.SYNOPSIS
   Install Script for VMware Horizon Client 2106-8.3.0-18287501

.DESCRIPTION
   Downloads and installs the VMware Horizon Client version 2106-8.3.0-18287501, will also upgrade existing versions already installed

.EXAMPLE
   PS C:\> .\Windows-Install-VMware-Horizon-Client.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v4+
#>

$Path = $env:TEMP; $Installer = "VMware-Horizon-Client-2106-8.3.0-18287501.exe"; 
Invoke-WebRequest "https://download3.vmware.com/software/view/viewclients/CART22FQ2/VMware-Horizon-Client-2106-8.3.0-18287501.exe" -OutFile $Path\$Installer;
Start-Process -FilePath $Path\$Installer -Args "/silent /norestart" -Verb RunAs -Wait;
Remove-Item $Path\$Installer