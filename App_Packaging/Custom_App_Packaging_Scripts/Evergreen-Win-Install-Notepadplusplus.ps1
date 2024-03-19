<# 
.SYNOPSIS
   Install Script for Notepad ++

.DESCRIPTION
   Installs Current version of Notepad++.

.EXAMPLE
   PS C:\> .\Evergreen-Win-Install-Notepadplusplus.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v3+
#>

# Modern websites require TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 
#requires -RunAsAdministrator
 
# Go to the website and see what it lists as the current version
$BaseUri = "https://notepad-plus-plus.org"
$BasePage = Invoke-WebRequest -Uri $BaseUri -UseBasicParsing
$ChildPath = $BasePage.Links | Where-Object { $_.outerHTML -like '*Current Version*' } | Select-Object -ExpandProperty href

# Go to the latest version's page and find the installer
$DownloadPageUri = $BaseUri + $ChildPath
$DownloadPage = Invoke-WebRequest -Uri $DownloadPageUri -UseBasicParsing

# Determine bit-ness of O/S and download accordingly
if ( [System.Environment]::Is64BitOperatingSystem ) {
    $DownloadUrl = $DownloadPage.Links | Where-Object { $_.outerHTML -like '*npp.*.Installer.x64.exe"*' } | Select-Object -ExpandProperty href
} else {
    $DownloadUrl = $DownloadPage.Links | Where-Object { $_.outerHTML -like '*npp.*.Installer.exe"*' } | Select-Object -ExpandProperty href
}
Write-Host "Downloading the latest Notepad++ to the temp folder"
Invoke-WebRequest -Uri $DownloadUrl -OutFile "$env:TEMP\$( Split-Path -Path $DownloadUrl -Leaf )" | Out-Null
Write-Host "Installing the latest Notepad++"
Start-Process -FilePath "$env:TEMP\$( Split-Path -Path $DownloadUrl -Leaf )" -ArgumentList "/S" -Wait

## Create detection method. 
$logfilespath = "C:\logfiles"
If(!(test-path $logfilespath))
{
      New-Item -ItemType Directory -Force -Path $logfilespath
}

New-Item -ItemType "file" -Path "c:\logfiles\NotePadPlusPlus-LSR.txt"