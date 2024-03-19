#Install Microsoft 365 Apps.

$ConfigurationXMLFile = "C:\Temp\MSApps365\Install-MS-Apps-365.xml"

#Run the O365 install
try {
    Write-Verbose 'Downloading and installing Microsoft 365'
    Start-Process "C:\Temp\MSApps365\Setup.exe" -ArgumentList "/configure $ConfigurationXMLFile" -Wait -PassThru
  }
  catch {
    Write-Warning 'Error running the Office install. The error is below:'
    Write-Warning $_
  }

# Create detection method. 
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\InstallMS365.txt"