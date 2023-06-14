<# 
.SYNOPSIS
   Disable News & Interest Feed on Taskbar

.DESCRIPTION
   Disables News & Interest Feed on Taskbar

.EXAMPLE
   PS C:\> .\Windows-10-Disable-News-Interests-Taskbar.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v4+
#>

$registryPath = "HKLM:\\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"

$Name = "EnableFeeds"

$value = "0"

 IF(!(Test-Path $registryPath))

{

New-Item -Path $registryPath -Force | Out-Null

New-ItemProperty -Path $registryPath -Name $name -Value $value -Type DWORD -Force | Out-Null}

ELSE {

New-ItemProperty -Path $registryPath -Name $name -Value $value -Type DWORD -Force | Out-Null}