<# 
.SYNOPSIS
   Install Python

.DESCRIPTION
   Script to install latest stable version of Python.

.EXAMPLE
   PS C:\> .\Evergreen-Win-Install-Python.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v1+

.NOTES
   Large Parts of this script from Trond Eirik Haavarstein
#>
function Get-PythonVersion {
    [cmdletbinding()]
    [outputtype([string])]
    $uri = "https://www.python.org/downloads/windows/"
    $web = Invoke-WebRequest -UseBasicParsing -Uri $uri
    $m = $web.ToString() -split "[`r`n]" | Select-String "Latest Python 3 Release" | Select-Object -First 1
    $m = $m -replace "<((?!@).)*?>"
    $m = $m.Replace('Latest Python 3 Release - Python','')
    $m = $m.Replace(')','')
    $m = $m.Replace(' ','')
    $Version = $m
    Write-Output $Version 
}

Clear-Host
Write-Verbose "Setting Arguments" -Verbose
$StartDTM = (Get-Date)

Write-Verbose "Installing Modules" -Verbose
if (!(Test-Path -Path "C:\Program Files\PackageManagement\ProviderAssemblies\nuget")) {Find-PackageProvider -Name 'Nuget' -ForceBootstrap -IncludeDependencies}
if (!(Get-Module -ListAvailable -Name Evergreen)) {Install-Module Evergreen -Force | Import-Module Evergreen}
Update-Module Evergreen

$Vendor = "Misc"
$Product = "Python"
$PackageName = "Python-win64"
$Version = $(Get-PythonVersion)
$URL = "https://www.python.org/ftp/python/$Version/python-$Version-amd64.exe"
$InstallerType = "exe"
$Source = "$PackageName" + "." + "$InstallerType"
$LogPS = "${env:SystemRoot}" + "\Temp\$Vendor $Product $Version PS Wrapper.log"
$ProgressPreference = 'SilentlyContinue'
$UnattendedArgs = "/quiet InstallAllUsers=1"

Start-Transcript $LogPS | Out-Null
 
If (!(Test-Path -Path $Version)) {New-Item -ItemType directory -Path $Version | Out-Null}
 
Set-Location $Version
 
Write-Verbose "Downloading $Vendor $Product $Version" -Verbose
If (!(Test-Path -Path $Source)) {Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $Source}
        
Write-Verbose "Starting Installation of $Vendor $Product $Version" -Verbose
(Start-Process "$PackageName.$InstallerType" $UnattendedArgs -Wait -Passthru).ExitCode

Write-Verbose "Customization" -Verbose

## Create detection method. 
$logfilespath = "C:\logfiles"
If(!(test-path $logfilespath))
{
      New-Item -ItemType Directory -Force -Path $logfilespath
}

New-Item -ItemType "file" -Path "c:\logfiles\$Product-LSR.txt"

Write-Verbose "Stop logging" -Verbose
$EndDTM = (Get-Date)
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalSeconds) Seconds" -Verbose
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalMinutes) Minutes" -Verbose
Stop-Transcript