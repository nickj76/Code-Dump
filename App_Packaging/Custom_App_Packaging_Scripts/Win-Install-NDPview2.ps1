<# 
.SYNOPSIS
   Install Script for NDP.View2.

.DESCRIPTION
   Downloads & Installs NDP.View2.

.EXAMPLE
   PS C:\> .\Win-Install-NDP.View2.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v1+
#>

Clear-Host
Write-Verbose "Setting Arguments" -Verbose
$StartDTM = (Get-Date)
$LogPS = "${env:SystemRoot}" + "\Temp\NDP.View2.log"

Start-Transcript $LogPS

# Download the NDP.View2
Write-Verbose "Downloading NDP.View2" -Verbose
Invoke-WebRequest https://www.hamamatsu.com/content/dam/hamamatsu-photonics/sites/static/sys/en/download/NDP.view%202.9.25%20RUO%20Setup.zip -OutFile C:\temp\NDP-view2-Setup.zip
Expand-Archive -Path C:\temp\NDP-view2-Setup.zip -DestinationPath C:\temp\NDPview\ -Verbose

# Install NDP.View2
Write-Verbose "Starting Installation of NDP.View2" -Verbose
$params = @{
             FilePath     = "C:\temp\NDPview\NDP.view 2.9.25 RUO Setup.exe"
             ArgumentList = "/qn"
             WindowStyle  = "Hidden"
             Wait         = $True
             PassThru     = $True
             Verbose      = $True
          }
$process = Start-Process @params

## Create Detection Method. 
$logfilespath = "C:\logfiles"
If(!(test-path $logfilespath))
{
      New-Item -ItemType Directory -Force -Path $logfilespath
}

New-Item -ItemType "file" -Path "c:\logfiles\NDP.View2.txt"

$EndDTM = (Get-Date)
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalSeconds) Seconds" -Verbose
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalMinutes) Minutes" -Verbose
Stop-Transcript