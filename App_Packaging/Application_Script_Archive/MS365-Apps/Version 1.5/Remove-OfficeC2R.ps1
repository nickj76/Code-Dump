<# 
.SYNOPSIS
   Script to remove currently installed version of MS Office C2R.

.DESCRIPTION
   Script that removes Microsoft Office C2R using parameters that you specify in the xml file e.g. Remove-Office.xml.
   
.EXAMPLE
   PS C:\> .\Remove-OfficeC2R.ps1
   PS C:\> .\Install-Office365.ps1 -ConfigurationXMLFile "C:\Scripts\OfficeConfig.xml"
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v1+
#>

$ConfigurationXMLFile = "C:\Temp\MSApps365\Remove-Office.xml"

#Run the O365 install
try {
    Write-Verbose 'Downloading and installing Microsoft 365'
    Start-Process "C:\Temp\MSApps365\Setup.exe" -ArgumentList "/configure $ConfigurationXMLFile" -Wait -PassThru
  }
  catch {
    Write-Warning 'Error running the Office install. The error is below:'
    Write-Warning $_
  }

if ($CleanUpInstallFiles) {
  Remove-Item -Path C:\temp\MSApps365 -Force -Recurse
}

# Create detection method. 
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\Remove-OfficeC2R.txt"