<# 
.SYNOPSIS
   Install Script for Microsoft 365 Apps.

.DESCRIPTION
   Script that installs Microsoft 365 Apps using parameters that you specify in the xml file e.g. Install-MS-Apps-365.xml.

.EXAMPLE
   PS C:\> .\Install-MSApps365.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v1+
#>

$ConfigurationXMLFile = "C:\Temp\MSApps365\Install-MS-Apps-365.xml"

#Run the O365 install
try {
    Write-Verbose 'Downloading and installing Microsoft 365'
    Start-Process "C:\Temp\MSApps365\Setup.exe" -ArgumentList "/configure $ConfigurationXMLFile" -Wait -PassThru
  }
  catch {
    Write-Warning 'Error running the Office install. The error is below:'
    Write-Warning $_
  }

# Remove Registry Keys
Set-Location -Path 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run\'
Remove-ItemProperty -Path . -Name "TeamsMachineUninstallerLocalAppData"
Remove-ItemProperty -Path . -Name "TeamsMachineUninstallerProgramData"

# Create detection method. 
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\InstallMS365.txt"