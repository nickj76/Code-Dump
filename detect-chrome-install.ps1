# Version to detect, only works with semantic versioning (up to four number components)
$detVersion = "117.0.5938.149"
# Path to EXE
$path64 = ${Env:ProgramFiles} + "\Google\Chrome\Application\chrome.exe"
$path86 = ${Env:ProgramFiles(x86)} + "\Google\Chrome\Application\chrome.exe"

if (Test-Path $path64) {
     $path = $path64
} elseif (Test-Path $path86) {
     $path = $path86
} else {
     # App doesn't exist
     Write-Host "Not Installed"
     exit 0
}

$appVersion = (Get-Item $path).VersionInfo.FileVersion

if ([version]$appVersion -ge [version]$detVersion) {
     Write-Host "Installed"
}
else {
     # App exists but is outdated
     exit 0
}