<#
.SYNOPSIS
   Script to Remove Office C2R.

.DESCRIPTION
   Script that removes Office C2R.

.EXAMPLE
   PS C:\> .\Remove-OfficeC2R.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v1+
#>

#Remove Office c2r.

# xml config file
$XMLConfigurationFile = 'PABDAG8AbgBmAGkAZwB1AHIAYQB0AGkAbwBuAD4ADQAKADwAIQAtAC0AVQBuAGkAbgBzAHQAYQBsAGwAIABjAG8AbQBwAGwAZQB0AGUAIABPAGYAZgBpAGMAZQAgADMANgA1AC0ALQA+AA0ACgA8AEQAaQBzAHAAbABhAHkAIABMAGUAdgBlAGwAPQAiAE4AbwBuAGUAIgAgAEEAYwBjAGUAcAB0AEUAVQBMAEEAPQAiAFQAUgBVAEUAIgAgAC8APgANAAoAPABMAG8AZwBnAGkAbgBnACAATABlAHYAZQBsAD0AIgBTAHQAYQBuAGQAYQByAGQAIgAgAFAAYQB0AGgAPQAiACUAdABlAG0AcAAlACIAIAAvAD4ADQAKADwAUgBlAG0AbwB2AGUAIABBAGwAbAA9ACIAVABSAFUARQAiACAALwA+AA0ACgA8AC8AQwBvAG4AZgBpAGcAdQByAGEAdABpAG8AbgA+AA=='
$DECODED = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($XMLConfigurationFile)) 
Write-Output $DECODED | Out-File "C:\temp\RemoveOffice.xml" -NoClobber

$OfficeInstallDownloadPath = 'C:\temp\Office365Install'
function Get-ODTURL {

  [String]$MSWebPage = Invoke-RestMethod 'https://www.microsoft.com/en-us/download/confirmation.aspx?id=49117'

  $MSWebPage | ForEach-Object {
    if ($_ -match 'url=(https://.*officedeploymenttool.*\.exe)') {
      $matches[1]
    }
  }

}

$VerbosePreference = 'Continue'
$ErrorActionPreference = 'Stop'

$CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (!($CurrentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
  Write-Warning 'Script is not running as Administrator'
  Write-Warning 'Please rerun this script as Administrator.'
  exit
}

if (-Not(Test-Path $OfficeInstallDownloadPath )) {
  New-Item -Path $OfficeInstallDownloadPath -ItemType Directory | Out-Null
}

$ConfigurationXMLFile = "C:\Temp\RemoveOffice.xml"
$ODTInstallLink = Get-ODTURL

#Download the Office Deployment Tool
Write-Verbose 'Downloading the Office Deployment Tool...'
try {
  Invoke-WebRequest -Uri $ODTInstallLink -OutFile "$OfficeInstallDownloadPath\ODTSetup.exe"
}
catch {
  Write-Warning 'There was an error downloading the Office Deployment Tool.'
  Write-Warning 'Please verify the below link is valid:'
  Write-Warning $ODTInstallLink
  exit
}

#Run the Office Deployment Tool setup
try {
  Write-Verbose 'Running the Office Deployment Tool...'
  Start-Process "$OfficeInstallDownloadPath\ODTSetup.exe" -ArgumentList "/quiet /extract:$OfficeInstallDownloadPath" -Wait
}
catch {
  Write-Warning 'Error running the Office Deployment Tool. The error is below:'
  Write-Warning $_
}

#Remove Office C2R
try {
  Write-Verbose 'Downloading and installing Microsoft 365'
  Start-Process "$OfficeInstallDownloadPath\Setup.exe" -ArgumentList "/configure $ConfigurationXMLFile" -Wait -PassThru
}
catch {
  Write-Warning 'Error running the Office install. The error is below:'
  Write-Warning $_
}

if ($CleanUpInstallFiles) {
  Remove-Item -Path $OfficeInstallDownloadPath -Force -Recurse
}

## Create Detection Method that Toast has run. 
$logfilespath = "C:\logfiles"
If(!(test-path $logfilespath))
{
      New-Item -ItemType Directory -Force -Path $logfilespath
}

New-Item -ItemType "file" -Path "c:\logfiles\Remove-OfficeC2R.txt"