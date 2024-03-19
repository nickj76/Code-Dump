<# 
.SYNOPSIS
   Gracefuly stop running Office Applications.

.DESCRIPTION
   Script that will gracefully stop running Office Applications and prompt user to save any open work.
  
.EXAMPLE
   PS C:\> .\Stop-Running-Office-Apps.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v1+
#>

## Close Excel
$isExcelOpen = Get-Process excel*
while ($null -ne $isExcelOpen) {
       Get-Process excel* | ForEach-Object { $_.CloseMainWindow() | Out-Null }
       Start-Sleep 5
       If ($null -ne ($isExcelOpen = Get-Process excel*)) {
              Write-Host "Excel is Open.......Closing Excel"
              $wshell = new-object -com wscript.shell
              $wshell.AppActivate("Microsoft Excel")
              $wshell.Sendkeys("%(S)")
              $isExcelOpen = Get-Process excel*
       }
}

## Close Outlook
$isOutlookOpen = Get-Process Outlook*
while ($null -ne $isOutlookOpen) {
       Get-Process outlook* | ForEach-Object { $_.CloseMainWindow() | Out-Null }
       Start-Sleep 5
       If ($null -ne ($isOutlookOpen = Get-Process outlook*)) {
              Write-Host "Outlook is Open.......Closing Outlook"
              $wshell = new-object -com wscript.shell
              $wshell.AppActivate("Microsoft Outlook")
              $wshell.Sendkeys("%(S)")
              $isOutlookOpen = Get-Process Outlook*
       }
}

## Close Word
$isWordOpen = Get-Process winword*
while ($null -ne $isWordOpen) {
       Get-Process winword* | ForEach-Object { $_.CloseMainWindow() | Out-Null }
       Start-Sleep 5
       If ($null -ne ($isWordOpen = Get-Process winword*)) {
              Write-Host "Word is Open.......Closing Word"
              $wshell = new-object -com wscript.shell
              $wshell.AppActivate("Microsoft Word")
              $wshell.Sendkeys("%(S)")
              $isWordOpen = Get-Process winword*
       }
}

## Close PowerPoint
$isPowerPointOpen = Get-Process powerpnt*
while ($null -ne $isPowerPointOpen) {
       Get-Process powerpnt* | ForEach-Object { $_.CloseMainWindow() | Out-Null }
       Start-Sleep 5
       If ($null -ne ($isPowerPointOpen = Get-Process powerpnt*)) {
              Write-Host "PowerPoint is Open.......Closing PowerPoint"
              $wshell = new-object -com wscript.shell
              $wshell.AppActivate("Microsoft PowerPoint")
              $wshell.Sendkeys("%(S)")
              $isPowerPointOpen = Get-Process powerpnt*
       }
}

## Close Access
$isAccessOpen = Get-Process msaccess*
while ($null -ne $isAccessOpen) {
       Get-Process msaccess* | ForEach-Object { $_.CloseMainWindow() | Out-Null }
       Start-Sleep 5
       If ($null -ne ($isAccessOpen = Get-Process msaccess*)) {
              Write-Host "Access is Open.......Closing Access"
              $wshell = new-object -com wscript.shell
              $wshell.AppActivate("Microsoft Access")
              $wshell.Sendkeys("%(S)")
              $isAccessOpen = Get-Process powerpnt*
       }
}

## Close OneNote
$isOneNoteOpen = Get-Process OneNote
while ($null -ne $isOneNoteOpen) {
       Get-Process OneNote | ForEach-Object { $_.CloseMainWindow() | Out-Null }
       Start-Sleep 5
       If ($null -ne ($isOneNoteOpen = Get-Process OneNote)) {
              Write-Host "OneNote is Open.......Closing OneNote"
              $wshell = new-object -com wscript.shell
              $wshell.AppActivate("Microsoft OneNote")
              $wshell.Sendkeys("%(S)")
              $isOneNoteOpen = Get-Process OneNote
       }
}

## Close Publisher
$isPublisherOpen = Get-Process MSPUB*
while ($null -ne $isPublisherOpen) {
       Get-Process MSPUB* | ForEach-Object { $_.CloseMainWindow() | Out-Null }
       Start-Sleep 5
       If ($null -ne ($isPublisherOpen = Get-Process MSPUB*)) {
              Write-Host "Publisher is Open.......Closing Publisher"
              $wshell = new-object -com wscript.shell
              $wshell.AppActivate("Microsoft Publisher")
              $wshell.Sendkeys("%(S)")
              $isPublisherOpen = Get-Process MSPUB*
       }
}

# Create detection method. 
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\StoppedOfficeApps.txt"