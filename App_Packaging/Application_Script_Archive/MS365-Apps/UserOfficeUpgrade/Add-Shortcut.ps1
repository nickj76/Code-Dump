$SourceFilePath = "https://qpulse.surrey.ac.uk/QPulse"
$ShortcutPath = "C:\Users\Public\Desktop\Q-Pulse Web.lnk"
$WScriptObj = New-Object -ComObject ("WScript.Shell")
$shortcut = $WscriptObj.CreateShortcut($ShortcutPath)
$shortcut.TargetPath = $SourceFilePath
$shortcut.IconLocation = "C:\Temp\favicon.ico"
$shortcut.Save()