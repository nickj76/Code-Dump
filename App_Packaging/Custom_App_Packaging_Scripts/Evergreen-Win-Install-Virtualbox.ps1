<# 
.SYNOPSIS
   Install Script for latest version of Virtualbox and Virtualbox extensions

.DESCRIPTION
   Downloads and installs Virtualbox & Virtualbox Extenstions pack.

.EXAMPLE
   PS C:\> .\Evergreen-Win-Install-virtualbox.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v3+
#>
Function Get-VirtualBoxVersion {
    
    $url = "https://download.virtualbox.org/virtualbox/LATEST.TXT"

    try {
        $temp = New-TemporaryFile
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $temp -ErrorAction SilentlyContinue
        $Version = get-content $temp
        Write-Output $Version
    }
    catch {
        Throw "Failed to connect to URL: $url with error $_."
    }
}

Function Get-VirtualBoxUri {

$Platform = "Win"
$Version = "$(Get-VirtualBoxVersion)"
$dir = "https://download.virtualbox.org/virtualbox/$Version/"
$file = (Invoke-Webrequest $dir -UseBasicParsing).links.href | Select-String -Pattern "$Platform"
$url = "$dir" + "$file"

Write-Output $url

}

Clear-Host
Write-Verbose "Setting Arguments" -Verbose
$StartDTM = (Get-Date)

$Vendor = "Oracle"
$Product = "VirtualBox"
$PackageName = "VirtualBox"
$Version = "$(Get-VirtualBoxVersion)"
$InstallerType = "exe"
$Source = "$PackageName" + "." + "$InstallerType"
$LogPS = "${env:SystemRoot}" + "\Temp\$Vendor $Product $Version PS Wrapper.log"
$UnattendedArgs = '--silent'
$url = "$(Get-VirtualBoxUri)"
$ProgressPreference = 'SilentlyContinue'

Start-Transcript $LogPS

if( -Not (Test-Path -Path $Version ) )
{
    New-Item -ItemType directory -Path $Version
}

Set-Location $Version

Write-Verbose "Downloading $Vendor $Product $Version" -Verbose
If (!(Test-Path -Path $Source)) {
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $Source
         }
        Else {
            Write-Verbose "File exists. Skipping Download." -Verbose
         }

Write-Verbose "Starting Installation of $Vendor $Product $Version" -Verbose
(Start-Process "$PackageName.$InstallerType" $UnattendedArgs -Wait -Passthru).ExitCode

Write-Verbose "Starting Installation of $Vendor $Product $Version Extension Pack" -Verbose
$ExtPack = "vbox-extpack"
$dir = "https://download.virtualbox.org/virtualbox/$Version/"
$extpackfile = (Invoke-Webrequest $dir -UseBasicParsing).links.href | Select-String -Pattern "$Version.$ExtPack"
$extpackurl = "$dir" + "$extpackfile"
Invoke-WebRequest -UseBasicParsing -Uri $extpackurl -OutFile $extpackfile
Set-Alias vboxmanage "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
"y" | vboxmanage extpack install --replace $extpackfile

Write-Verbose "Stop logging" -Verbose
$EndDTM = (Get-Date)
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalSeconds) Seconds" -Verbose
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalMinutes) Minutes" -Verbose
Stop-Transcript

## Create detection method. 
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\Virtualbox-LSR.txt"