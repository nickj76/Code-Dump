# Download Mozilla Firefox Latest

if (Test-Path firefox-latest.exe -PathType leaf) {
    Write-Host "Mozilla Firefox Latest Exists In Folder: firefox-latest.exe"
}
else {
    Write-Host ">> Downloading Latest Version of Mozilla Firefox"
    Invoke-WebRequest 'https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-GB' -OutFile firefox-latest.exe
    Write-Host ">> Download Complete"
}

Write-Host "++ Executing Firefox Installer..."
& .\firefox-latest.exe