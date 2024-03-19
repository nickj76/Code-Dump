<# 
.SYNOPSIS
   Script to find & download the latest version of PostgreSQL x64 for windows

.DESCRIPTION
   Downloads and installs the latest version of PostgreSQL x64 for windows.

.EXAMPLE
   PS C:\> .\Evergreen-Win-Install-PostgreSQL.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v1+
#>

Clear-Host
Write-Verbose "Setting Arguments" -Verbose
$StartDTM = (Get-Date)

## Find the latest version of postgresql and create download url

$postgres = Invoke-WebRequest -UseBasicParsing -uri https://www.postgresql.org/versions.json | ConvertFrom-Json 
$LatestVersion =  $postgres | Where-Object current -eq "True"
$releaseversion = "$($LatestVersion.major).$($LatestVersion.latestMinor)-1-windows-x64"
$url = "https://get.enterprisedb.com/postgresql/postgresql-$($LatestVersion.major).$($LatestVersion.latestMinor)-1-windows-x64.exe"

## Download & install Application.

$Path = $env:TEMP;
$Vendor = "Postgresql"
$Product = "Postgresql"
$PackageName = "postgresql-win"
$Version = $releaseversion
$InstallerType = "exe"
$Source = "$PackageName" + "." + "$InstallerType"
$DownloadURL = $url
$LogPS = "${env:SystemRoot}" + "\Temp\$Vendor $Product $Version PS Wrapper.log"
$UnattendedArgs = '--mode unattended --unattendedmodeui none'
$ProgressPreference = 'SilentlyContinue'

Start-Transcript $LogPS

if( -Not (Test-Path -Path $PackageName ) )
{
    New-Item -ItemType directory -Path $PackageName
}

Set-Location $Path

Write-Verbose "Downloading $Vendor $Product $Version" -Verbose
If (!(Test-Path -Path $Source)) {
    Invoke-WebRequest -Uri $Downloadurl -OutFile $Source
         }
        Else {
            Write-Verbose "File exists. Skipping Download." -Verbose
         }

Write-Verbose "Starting Installation of $Vendor $Product $Version" -Verbose
(Start-Process "$PackageName.$InstallerType" $UnattendedArgs -Wait -Passthru).ExitCode

Write-Verbose "Customization" -Verbose

## Pause for 45 seconds to allow install to completed, This can be adjusted as needed.
Start-Sleep -Seconds 45

## Cleanup Downloads
Remove-Item $Path\$Source

## Create Detection Method. 
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