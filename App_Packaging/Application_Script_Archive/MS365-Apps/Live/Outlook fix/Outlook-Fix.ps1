<#
.SYNOPSIS
   Fix Missing or Failing Outlook Shortcut on Windows Start Menu.

.DESCRIPTION
   Script to Fix Missing or Failing Outlook Shortcut on Windows Start Menu.

.EXAMPLE
   PS C:\> .\Outlook-Fix.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v1+
#>

# Remove outlook shortcut from start menu
Remove-Item -path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Outlook.lnk" -Force
Remove-Item -Path "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Outlook.lnk" -Force

# Add Shortcut to outlook.exe to start menu
$SourceFilePath = "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE"
$ShortcutPath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Outlook.lnk"
$WScriptObj = New-Object -ComObject ("WScript.Shell")
$shortcut = $WscriptObj.CreateShortcut($ShortcutPath)
$shortcut.TargetPath = $SourceFilePath
$shortcut.IconLocation = "%ProgramFiles%\Microsoft Office\Root\VFS\Windows\Installer\{90160000-000F-0000-1000-0000000FF1CE}\outicon.exe"
$shortcut.Save()

# Create Detection Method that script has run. 
$logfilespath = "C:\logfiles"
If(!(test-path $logfilespath))
{
      New-Item -ItemType Directory -Force -Path $logfilespath
}

New-Item -ItemType "file" -Path "c:\logfiles\Outlook-Fix.txt"