##################################################
# Flash Player uninstaller #
# Removes all signs of flash from Win 10 machines#
# Updated: 12/24/2020      #
##################################################

#Requires -RunAsAdministrator
#Set Execution Policy Bypass
Set-executionpolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force

# Variables
$fluninstaller = "https://fpdownload.macromedia.com/get/flashplayer/current/support/uninstall_flash_player.exe"
$flashloc1 = "C:\Windows\system32\Macromed\Flash"
$flashloc2 = "C:\Windows\SysWOW64\Macromed\Flash"
$flashloc3 = "%appdata%\Adobe\Flash Player"
$flashloc4 = "%appdata%\Macromedia\Flash Player"
$flashloc5 = "C:\Windows\SysWOW64\FlashPlayerApp.exe"
$flashloc6 = "C:\Windows\SysWOW64\FlashPlayerCPLApp.cpl"

$Flashutil = (Get-Childitem C:\Windows\system32\Macromed\Flash\FlashUtil*ActiveX.exe -name -ErrorAction SilentlyContinue)
$FlashTest = (Test-Path C:\Windows\system32\Macromed\Flash\FlashUtil*ActiveX.exe)
$Flashutil1 = (Get-Childitem C:\Windows\system32\Macromed\Flash\FlashUtil*Plugin.exe -name -ErrorAction SilentlyContinue)
$FlashTest1 = (Test-Path C:\Windows\system32\Macromed\Flash\FlashUtil*Plugin.exe)
$Flashutil2 = (Get-Childitem C:\Windows\SysWOW64\Macromed\Flash\FlashUtil*ActiveX.exe -name -ErrorAction SilentlyContinue)
$Flashtest2 = (Test-Path C:\Windows\SysWOW64\Macromed\Flash\FlashUtil*ActiveX.exe)

#Download Uninstaller and run silently
$ProgressPreference = 'SilentlyContinue'
Write-Host "`n`nDownloading Adobe uninstaller ... "
Invoke-WebRequest "$fluninstaller" -OutFile (New-Item -Path "C:\temp\uninstall_flash_player.exe" -Force)
Write-Host "`n`nDownload completed .. Running Installer "
Start-Process "C:\temp\uninstall_flash_player.exe" -Argumentlist "-uninstall" -Wait -PassThru -ErrorAction SilentlyContinue
Write-Host "`nFinished Running Adobe Uninstaller" -ForegroundColor Green -BackgroundColor Black


Write-Host "`n`nMoving on... Uninstalling any ActiveX Plugins " -ForegroundColor Yellow -BackgroundColor Black
Write-Host "---------------------------------------------"

# Run Flash uninstallers from System32\Macromed\Flash folder
If ($FlashTest -eq $True){
    Start-Process -FilePath "C:\Windows\system32\Macromed\Flash\$Flashutil" -Argumentlist "-uninstall" -ErrorAction SilentlyContinue
    Write-host "Successfully ran ActiveX Uninstaller" -ForegroundColor Green -BackgroundColor Black
}
else{
    Write-Host "No ActiveX Plugin foundd" -ForegroundColor Green
}

If ($FlashTest1 -eq $True){
    Start-Process -FilePath "C:\Windows\system32\Macromed\Flash\$Flashutil1" -Argumentlist "-uninstall" -ErrorAction SilentlyContinue
    Write-host "Successfully ran NPAPI Uninstaller" -ForegroundColor Green -BackgroundColor Black
}
else{
    Write-Host "No NPAPI plugin found" -ForegroundColor Green
}

If ($FlashTest2 -eq $True){
    Start-Process -FilePath "C:\Windows\SysWOW64\Macromed\Flash\$Flashutil2" -Argumentlist "-uninstall" -ErrorAction SilentlyContinue
    Write-host "Successfully ran ActiveX [SysWOW64] Uninstaller" -ForegroundColor Green -BackgroundColor Black
}
else{
    Write-Host "ActiveX Plugin [SysWOW64] not found" -ForegroundColor Green
}

# Take Ownershp and Force delete Flash Sysytem folders 
# Folder 1 in System32
if (Test-Path $flashloc1){
    takeown /a /r /d Y /f $flashloc1
    cmd.exe /c "cacls C:\Windows\System32\Macromed\Flash /E /T /G %UserDomain%\%UserName%:F"
    if ($LASTEXITCODE -eq "0" ){
        Write-Host "`n`nDeleting: $flashloc1" -Foregroundcolor Yellow
        Remove-Item -path "$flashloc1" -Force -Recurse -ErrorAction SilentlyContinue
    }
}
else 
{
    Write-Host "`n`n $flashloc1 not found" -ForegroundColor Green
}

# Folder 2 in SysWoW64
if (Test-Path $flashloc2){
    takeown /a /r /d Y /f $flashloc2
    cmd.exe /c "cacls C:\Windows\SysWOW64\Macromed\Flash /E /T /G %UserDomain%\%UserName%:F"
    if ($LASTEXITCODE -eq "0" ){
        Write-Host "`n`nDeleting: $flashloc2" -Foregroundcolor Yellow
        Remove-Item -path "$flashloc2" -Force -Recurse -ErrorAction SilentlyContinue
    }
}
else {
    Write-Host "`n`n $flashloc2 not found" -ForegroundColor Green
}

# Delete AppData Flash folders
if (Test-Path $flashloc3){
    Write-Host "`n`nDeleting folder: $flashloc3" -Foregroundcolor Yellow
    Remove-Item -path "$flashloc3" -Force -Recurse
}
else {
    Write-Host "`n`n $flashloc3 not found" -ForegroundColor Green
}

if (Test-Path $flashloc4){
    Write-Host "`n`nDeleting folder: $flashloc4" -Foregroundcolor Yellow
    Remove-Item -path "$flashloc4" -Force -Recurse
}
else {
    Write-Host "`n`n $flashloc4 not found" -ForegroundColor Green
}

# Delete FlashPlayerApp and FlashPlayerCPLApp.cpl file in SysWow64 folder
if (Test-Path $flashloc5){
    cmd.exe /c "icacls C:\Windows\SysWOW64\FlashPlayerApp.exe /grant %UserDomain%\%UserName%:F"
    if ($LASTEXITCODE -eq "0" ){
        Write-Host "`n`nDeleting: $flashloc5" -Foregroundcolor Yellow
        Remove-Item -path "$flashloc5"
    }
}
else {
    Write-Host "`n`n $flashloc5 not found" -ForegroundColor Green
}

if (Test-Path $flashloc6){
    cmd.exe /c "icacls C:\Windows\SysWOW64\FlashPlayerCPLApp.cpl /grant %UserDomain%\%UserName%:F"
    if ($LASTEXITCODE -eq "0" ){
        Write-Host "`n`nDeleting: $flashloc6" -Foregroundcolor Yellow
        Remove-Item -path "$flashloc6"
   }
}
else {
    Write-Host "`n`n $flashloc6 not found" -ForegroundColor Green
}

Write-Host "`n`nFlash Player Removed! Please reboot you machine.`n`n" -Foregroundcolor Green -BackgroundColor Black
