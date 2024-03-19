$OfficeUninstallStrings = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "*Microsoft Office 365*"} | Select-Object UninstallString).UninstallString
    ForEach ($UninstallString in $OfficeUninstallStrings) {
        $UninstallEXE = ($UninstallString -split '"')[1]
        $UninstallArg = ($UninstallString -split '"')[2] + " DisplayLevel=False"
        Start-Process -FilePath $UninstallEXE -ArgumentList $UninstallArg -Wait
    }    