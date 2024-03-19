<# 
.SYNOPSIS
   Install Script for Grammarly for office

.DESCRIPTION
   Install Grammarly for office.

.EXAMPLE
   PS C:\> .\Evergreen-Win-Install-GrammarlyAddin.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v1+
#>

Clear-Host
Write-Verbose "Setting Arguments" -Verbose
$StartDTM = (Get-Date)

$Path = $env:TEMP;
$Vendor = "Grammarly"
$Product = "Grammarly-Office-Addin"
$PackageName = "GrammarlyAddInSetup"
$Version = "LSR"
$InstallerType = "exe"
$Source = "$PackageName" + "." + "$InstallerType"
$URL = "https://download-office.grammarly.com/latest/GrammarlyAddInSetup.exe"
$LogPS = "${env:SystemRoot}" + "\Temp\$Vendor $Product $Version PS Wrapper.log"
$UnattendedArgs = 'GrammarlyAddInSetup.exe /fastforallmode /silent'
$ProgressPreference = 'SilentlyContinue'

Start-Transcript $LogPS

if( -Not (Test-Path -Path $PackageName ) )
{
    New-Item -ItemType directory -Path $PackageName
}

Set-Location $Path

Write-Verbose "Downloading $Vendor $Product" -Verbose
If (!(Test-Path -Path $Source)) {
    Invoke-WebRequest -Uri $url -OutFile $Source
         }
        Else {
            Write-Verbose "File exists. Skipping Download." -Verbose
         }

Write-Verbose "Starting Installation of $Vendor $Product" -Verbose
(Start-Process "$PackageName.$InstallerType" $UnattendedArgs -Wait -Passthru).ExitCode

Write-Verbose "Customization" -Verbose

## Pause for 45 seconds to allow install to completed.
Start-Sleep -Seconds 45

## Cleanup Downloads
Remove-Item $Path\$Source

## Create detection method. 
$logfilespath = "C:\logfiles"
If(!(test-path $logfilespath))
{
      New-Item -ItemType Directory -Force -Path $logfilespath
}

New-Item -ItemType "file" -Path "c:\logfiles\$PackageName-LSR.txt"

Write-Verbose "Stop logging" -Verbose
$EndDTM = (Get-Date)
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalSeconds) Seconds" -Verbose
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalMinutes) Minutes" -Verbose
Stop-Transcript