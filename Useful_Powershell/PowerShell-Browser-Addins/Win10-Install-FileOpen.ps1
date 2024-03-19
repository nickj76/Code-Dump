<# 
.SYNOPSIS
   Install Script for FileOpen Plug-in

.DESCRIPTION
   Downloads & Installs FileOpen Plug-in for Adobe Acrobat.

.EXAMPLE
   PS C:\> .\Win10-Install-FileOpen.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v1+
#>

Clear-Host
Write-Verbose "Setting Arguments" -Verbose
$StartDTM = (Get-Date)
$LogPS = "${env:SystemRoot}" + "\Temp\FileOpen PS Wrapper.log"

Start-Transcript $LogPS

# Download the FileOpenInstaller
Write-Verbose "Downloading FileOpenInstaller" -Verbose
Invoke-WebRequest https://plugin.fileopen.com/current/FileOpenInstaller.exe -OutFile C:\temp\FileOpenInstaller.exe

# Install FileOpen Add-in
Write-Verbose "Starting Installation of FileOpen" -Verbose
$params = @{
             FilePath     = "C:\temp\FileOpenInstaller.exe"
             ArgumentList = "/VERYSILENT"
             WindowStyle  = "Hidden"
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

New-Item -ItemType "file" -Path "c:\logfiles\FileOpenClient-B996.txt"

## Pause for 20 seconds to allow install to completed.
Start-Sleep -Seconds 20

## Cleanup installer files.

Remove-Item C:\temp\FileOpen* -force -recurse -ErrorAction SilentlyContinue -Verbose

$EndDTM = (Get-Date)
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalSeconds) Seconds" -Verbose
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalMinutes) Minutes" -Verbose
Stop-Transcript