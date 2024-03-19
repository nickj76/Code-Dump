<# 
.SYNOPSIS
   Install Script for Microsoft 365 Apps for Enterprise (Excluding Teams).

.DESCRIPTION
   Install Microsoft 365 Apps for Enterprise x64 (Excluding Teams) Monthly Enterprise Channel.

.EXAMPLE
   PS C:\> .\Install-MS365Apps-x64.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v1+
#>

# Decode xml config file and write output to c:\temp
$XMLConfigurationFile = 'PABDAG8AbgBmAGkAZwB1AHIAYQB0AGkAbwBuACAASQBEAD0AIgAyADAAMABlAGIANQBmADIALQA2ADIAOQBhAC0ANABhADAANQAtADgANAAyAGMALQBlAGIAYwAxAGIAMQA5ADAAMAA5ADcANwAiAD4ADQAKADwASQBuAGYAbwAgAC8APgANAAoAPABBAGQAZAAgAE8AZgBmAGkAYwBlAEMAbABpAGUAbgB0AEUAZABpAHQAaQBvAG4APQAiADYANAAiACAAQwBoAGEAbgBuAGUAbAA9ACIATQBvAG4AdABoAGwAeQBFAG4AdABlAHIAcAByAGkAcwBlACIAIABNAGkAZwByAGEAdABlAEEAcgBjAGgAPQAiAFQAUgBVAEUAIgA+AA0ACgAgACAAPABQAHIAbwBkAHUAYwB0ACAASQBEAD0AIgBPADMANgA1AFAAcgBvAFAAbAB1AHMAUgBlAHQAYQBpAGwAIgA+AA0ACgAgACAAIAAgADwATABhAG4AZwB1AGEAZwBlACAASQBEAD0AIgBlAG4ALQB1AHMAIgAgAC8APgANAAoAIAAgACAAIAA8AEUAeABjAGwAdQBkAGUAQQBwAHAAIABJAEQAPQAiAEcAcgBvAG8AdgBlACIAIAAvAD4ADQAKACAAIAAgACAAPABFAHgAYwBsAHUAZABlAEEAcABwACAASQBEAD0AIgBMAHkAbgBjACIAIAAvAD4ADQAKACAAIAAgACAAPABFAHgAYwBsAHUAZABlAEEAcABwACAASQBEAD0AIgBPAG4AZQBEAHIAaQB2AGUAIgAgAC8APgANAAoAIAAgACAAIAA8AEUAeABjAGwAdQBkAGUAQQBwAHAAIABJAEQAPQAiAEIAaQBuAGcAIgAgAC8APgANAAoAIAAgACAAIAA8AEUAeABjAGwAdQBkAGUAQQBwAHAAIABJAEQAPQAiAEIAaQBuAGcAIgAgAC8APgANAAoAIAAgADwALwBQAHIAbwBkAHUAYwB0AD4ADQAKACAAIAA8AFAAcgBvAGQAdQBjAHQAIABJAEQAPQAiAFYAaQBzAGkAbwBQAHIAbwBSAGUAdABhAGkAbAAiAD4ADQAKACAAIAAgACAAPABMAGEAbgBnAHUAYQBnAGUAIABJAEQAPQAiAGUAbgAtAHUAcwAiACAALwA+AA0ACgAgACAAIAAgADwARQB4AGMAbAB1AGQAZQBBAHAAcAAgAEkARAA9ACIARwByAG8AbwB2AGUAIgAgAC8APgANAAoAIAAgACAAIAA8AEUAeABjAGwAdQBkAGUAQQBwAHAAIABJAEQAPQAiAEwAeQBuAGMAIgAgAC8APgANAAoAIAAgACAAIAA8AEUAeABjAGwAdQBkAGUAQQBwAHAAIABJAEQAPQAiAE8AbgBlAEQAcgBpAHYAZQAiACAALwA+AA0ACgAgACAAIAAgADwARQB4AGMAbAB1AGQAZQBBAHAAcAAgAEkARAA9ACIAQgBpAG4AZwAiACAALwA+AA0ACgAgACAAIAAgADwARQB4AGMAbAB1AGQAZQBBAHAAcAAgAEkARAA9ACIAQgBpAG4AZwAiACAALwA+AA0ACgAgACAAPAAvAFAAcgBvAGQAdQBjAHQAPgANAAoAPAAvAEEAZABkAD4ADQAKADwAVQBwAGQAYQB0AGUAcwAgAEUAbgBhAGIAbABlAGQAPQAiAFQAUgBVAEUAIgAgAC8APgANAAoAPABMAG8AZwBnAGkAbgBnACAATABlAHYAZQBsAD0AIgBTAHQAYQBuAGQAYQByAGQAIgAgAFAAYQB0AGgAPQAiACUAdABlAG0AcAAlACIAIAAvAD4ADQAKADwAUgBlAG0AbwB2AGUATQBTAEkAIAAvAD4ADQAKADwAQQBwAHAAUwBlAHQAdABpAG4AZwBzAD4ADQAKACAAIAA8AFMAZQB0AHUAcAAgAE4AYQBtAGUAPQAiAEMAbwBtAHAAYQBuAHkAIgAgAFYAYQBsAHUAZQA9ACIAVQBuAGkAdgBlAHIAcwBpAHQAeQAgAG8AZgAgAFMAdQByAHIAZQB5ACIAIAAvAD4ADQAKACAAIAA8AFUAcwBlAHIAIABLAGUAeQA9ACIAcwBvAGYAdAB3AGEAcgBlAFwAbQBpAGMAcgBvAHMAbwBmAHQAXABvAGYAZgBpAGMAZQBcADEANgAuADAAXABlAHgAYwBlAGwAXABvAHAAdABpAG8AbgBzACIAIABOAGEAbQBlAD0AIgBkAGUAZgBhAHUAbAB0AGYAbwByAG0AYQB0ACIAIABWAGEAbAB1AGUAPQAiADUAMQAiACAAVAB5AHAAZQA9ACIAUgBFAEcAXwBEAFcATwBSAEQAIgAgAEEAcABwAD0AIgBlAHgAYwBlAGwAMQA2ACIAIABJAGQAPQAiAEwAXwBTAGEAdgBlAEUAeABjAGUAbABmAGkAbABlAHMAYQBzACIAIAAvAD4ADQAKACAAIAA8AFUAcwBlAHIAIABLAGUAeQA9ACIAcwBvAGYAdAB3AGEAcgBlAFwAbQBpAGMAcgBvAHMAbwBmAHQAXABvAGYAZgBpAGMAZQBcADEANgAuADAAXABwAG8AdwBlAHIAcABvAGkAbgB0AFwAbwBwAHQAaQBvAG4AcwAiACAATgBhAG0AZQA9ACIAZABlAGYAYQB1AGwAdABmAG8AcgBtAGEAdAAiACAAVgBhAGwAdQBlAD0AIgAyADcAIgAgAFQAeQBwAGUAPQAiAFIARQBHAF8ARABXAE8AUgBEACIAIABBAHAAcAA9ACIAcABwAHQAMQA2ACIAIABJAGQAPQAiAEwAXwBTAGEAdgBlAFAAbwB3AGUAcgBQAG8AaQBuAHQAZgBpAGwAZQBzAGEAcwAiACAALwA+AA0ACgAgACAAPABVAHMAZQByACAASwBlAHkAPQAiAHMAbwBmAHQAdwBhAHIAZQBcAG0AaQBjAHIAbwBzAG8AZgB0AFwAbwBmAGYAaQBjAGUAXAAxADYALgAwAFwAdwBvAHIAZABcAG8AcAB0AGkAbwBuAHMAIgAgAE4AYQBtAGUAPQAiAGQAZQBmAGEAdQBsAHQAZgBvAHIAbQBhAHQAIgAgAFYAYQBsAHUAZQA9ACIAIgAgAFQAeQBwAGUAPQAiAFIARQBHAF8AUwBaACIAIABBAHAAcAA9ACIAdwBvAHIAZAAxADYAIgAgAEkAZAA9ACIATABfAFMAYQB2AGUAVwBvAHIAZABmAGkAbABlAHMAYQBzACIAIAAvAD4ADQAKADwALwBBAHAAcABTAGUAdAB0AGkAbgBnAHMAPgANAAoAPABEAGkAcwBwAGwAYQB5ACAATABlAHYAZQBsAD0AIgBOAG8AbgBlACIAIABBAGMAYwBlAHAAdABFAFUATABBAD0AIgBUAFIAVQBFACIAIAAvAD4ADQAKADwAUAByAG8AcABlAHIAdAB5ACAATgBhAG0AZQA9ACIARgBPAFIAQwBFAEEAUABQAFMASABVAFQARABPAFcATgAiACAAVgBhAGwAdQBlAD0AIgBUAFIAVQBFACIALwA+AA0ACgA8AC8AQwBvAG4AZgBpAGcAdQByAGEAdABpAG8AbgA+AA=='
$DECODED = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($XMLConfigurationFile)) 
Write-Output $DECODED | Out-File "C:\temp\Install365-x64.xml" -NoClobber

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

$ConfigurationXMLFile = "C:\Temp\Install365-x64.xml"
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

#Run the Microsoft 365 Apps install
try {
  Write-Verbose 'Downloading and installing Microsoft 365'
  Start-Process "$OfficeInstallDownloadPath\Setup.exe" -ArgumentList "/configure $ConfigurationXMLFile" -Wait -PassThru
}
catch {
  Write-Warning 'Error running the Office install. The error is below:'
  Write-Warning $_
}

#Check if Microsoft 365 suite was installed correctly.
$RegLocations = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

$OfficeInstalled = $False
foreach ($Key in (Get-ChildItem $RegLocations) ) {
  if ($Key.GetValue('DisplayName') -like '*Microsoft 365*') {
    $OfficeVersionInstalled = $Key.GetValue('DisplayName')
    $OfficeInstalled = $True
  }
}

if ($OfficeInstalled) {
  Write-Verbose "$($OfficeVersionInstalled) installed successfully!"
}
else {
  Write-Warning 'Microsoft 365 was not detected after the install ran'
}

if ($CleanUpInstallFiles) {
  Remove-Item -Path $OfficeInstallDownloadPath -Force -Recurse -Verbose -ErrorAction SilentlyContinue
}

# Create detection method. 
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\365AppsUpgrade.txt"