<# 
.SYNOPSIS
   Install Putty

.DESCRIPTION
   Script to install latest stable version of Putty.

.EXAMPLE
   PS C:\> .\Evergreen-Win-Install-Putty.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v1+
   
.NOTES
   Large Parts of this script from Trond Eirik Haavarstein
#>

Function Get-PuttyVersion {    

    [CmdletBinding()]
    [Outputtype([string])]
    param()
    $url = "https://www.chiark.greenend.org.uk/~sgtatham/putty/releases/"

    try {
        $web = Invoke-WebRequest -UseBasicParsing -Uri $url -ErrorAction SilentlyContinue
    }
    catch {
        Throw "Failed to connect to URL: $url with error $_."
        Break
    }
    finally {
        $str1 = $web.links | Select-Object -Last 1
        $str2 = $str1.href
        $Version = $str2.trim(".html") 
        Write-Output $Version
    }
}

Write-Verbose "Setting Arguments" -Verbose
$StartDTM = (Get-Date)

$Vendor = "Misc"
$Product = "Putty"
$PackageName = "putty-64bit"
$Version = "$(Get-PuttyVersion)"
$InstallerType = "msi"
$Source = "$PackageName" + "." + "$InstallerType"
$LogPS = "${env:SystemRoot}" + "\Temp\$Vendor $Product $Version PS Wrapper.log"
$LogApp = "${env:SystemRoot}" + "\Temp\$PackageName.log"
$UnattendedArgs = "/i $PackageName.$InstallerType ALLUSERS=1 /qn /liewa $LogApp"
$url = "https://the.earth.li/~sgtatham/putty/$Version/w64/putty-64bit-$Version-installer.msi"
$ProgressPreference = 'SilentlyContinue'

Start-Transcript $LogPS

if( -Not (Test-Path -Path $Version ) )
{
    New-Item -ItemType directory -Path $Version | Out-Null
}

Set-Location $Version

Write-Verbose "Downloading $Vendor $Product $Version" -Verbose
If (!(Test-Path -Path $Source)) {
    Invoke-WebRequest -Uri $url -OutFile $Source
         }
        Else {
            Write-Verbose "File exists. Skipping Download." -Verbose
         }

Write-Verbose "Starting Installation of $Vendor $Product $Version" -Verbose
(Start-Process msiexec.exe -ArgumentList $UnattendedArgs -Wait -Passthru).ExitCode

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