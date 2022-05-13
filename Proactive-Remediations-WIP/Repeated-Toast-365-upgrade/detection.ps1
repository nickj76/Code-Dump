If (Test-Path -Path c:\logfiles\365AppsUpgrade-Reboot.txt ) {
    
    Write-Host "Office already upgraded"
    }
    Else {
    Write-Host "Office still needs upgrading"
    }