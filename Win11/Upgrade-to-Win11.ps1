$workingdir = “c:\temp”
$url = “https://go.microsoft.com/fwlink/?linkid=2171764”
$file = “$($workingdir)\Win11Upgrade.exe”

If(!(test-path $workingdir))
{
New-Item -ItemType Directory -Force -Path $workingdir
}

Invoke-WebRequest -Uri $url -OutFile $file

Start-Process -FilePath $file -ArgumentList “/Install /MinimizeToTaskBar /QuietInstall /SkipEULA /copylogs $workingdir”