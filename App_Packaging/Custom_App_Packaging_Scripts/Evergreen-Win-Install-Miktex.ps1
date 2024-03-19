<# 
.SYNOPSIS
   Install Latest 64bit Version of Miktex.

.DESCRIPTION
   Script to download and install the latest 64bit version of Miktex.

.EXAMPLE
   PS C:\> .\Evergreen-Win-Install-Miktex.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt. 

.FUNCTIONALITY
   PowerShell v1+
#>

$Product = "MikTex"
$LogPS = "${env:SystemRoot}" + "\Temp\MikTex-PS-Wrapper.log"
$ProgressPreference = 'SilentlyContinue'
Start-Transcript $LogPS

# Download the bootstrapper
Write-Verbose "Downloading $Product" -Verbose
Invoke-WebRequest https://miktex.org/download/win/miktexsetup-x64.zip -OutFile C:\temp\miktexsetup-x64.zip
Expand-Archive C:\temp\miktexsetup-x64.zip -DestinationPath C:\temp\miktex

# Call the bootstrapper to download the remaining source packages

$params = @{
             FilePath     = "C:\temp\miktex\miktexsetup_standalone.exe"
             ArgumentList = "--package-set=essential --local-package-repository=C:\temp\miktex download"
             WindowStyle  = "Hidden"
             Wait         = $True
             PassThru     = $True
             Verbose      = $True
          }
$process = Start-Process @params   

# Install MiKTeX
Write-Verbose "Starting Installation of $Product" -Verbose
$params = @{
             FilePath     = "C:\temp\miktex\miktexsetup_standalone.exe"
             ArgumentList = "--package-set=essential --local-package-repository=C:\temp\miktex --shared=yes install"
             WindowStyle  = "Hidden"
             Wait         = $True
             PassThru     = $True
             Verbose      = $True
          }
$process = Start-Process @params   

# update the PATH so we can find the newly installed MiKTeX console executable

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# check for updates to suppress the error "the administrator hasn't yet checked for updates"

$params = @{
             FilePath     = "mpm.exe"
             ArgumentList = "--admin --find-updates"
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

New-Item -ItemType "file" -Path "c:\logfiles\Miktex-LSR.txt"

## Cleanup installer files.

Remove-Item C:\temp\miktex* -force -recurse -ErrorAction SilentlyContinue -Verbose
Stop-Transcript