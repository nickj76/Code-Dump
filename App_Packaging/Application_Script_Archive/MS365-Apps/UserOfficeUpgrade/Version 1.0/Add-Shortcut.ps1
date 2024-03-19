$SourceFilePath = "C:\Temp\MS365Apps\Office-Update.bat"
$ShortcutPath = "C:\Users\Public\Desktop\Upgrade to Microsoft 365 Apps.lnk"
$WScriptObj = New-Object -ComObject ("WScript.Shell")
$shortcut = $WscriptObj.CreateShortcut($ShortcutPath)
$shortcut.TargetPath = $SourceFilePath
$shortcut.IconLocation = "C:\Temp\MS365Apps\microsoft_office_icon.ico"
$shortcut.Save()

# Create detection method. 
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\OfficeUpgradeShortcut.txt"