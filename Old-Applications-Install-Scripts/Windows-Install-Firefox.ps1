<# 
.SYNOPSIS
   Download & Install Latest Version of Mozilla Firefox(x64).

.DESCRIPTION
   Downloads & Installs Latest Version of Mozilla Firefox(x64), will also update any installed x64 version
   
.EXAMPLE
   PS C:\> .\Windows-Install-Firefox-latest.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v4+
#>

# Path for the workdir
$workdir = "c:\temp\"

# Check if work directory exists if not create it

If (Test-Path -Path $workdir -PathType Container)
{ Write-Host "$workdir already exists" -ForegroundColor Red}
ELSE
{ New-Item -Path $workdir  -ItemType directory }

# Download the installer

$source = "https://download.mozilla.org/?product=firefox-latest&os=win64&lang=en-GB"
$destination = "$workdir\firefox.exe"

# Check if Invoke-Webrequest exists otherwise execute WebClient

if (Get-Command 'Invoke-Webrequest')
{
     Invoke-WebRequest $source -OutFile $destination
}
else
{
    $WebClient = New-Object System.Net.WebClient
    $webclient.DownloadFile($source, $destination)
}

# Start the installation

Start-Process -FilePath "$workdir\firefox.exe" -ArgumentList "/S"

# Wait XX Seconds for the installation to finish

Start-Sleep -s 35

# Remove the installer

Remove-Item -Force $workdir\firefox*
Remove-Item -Force 'C:\Users\Public\Desktop\firefox.lnk'