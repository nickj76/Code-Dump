#Start Logging
Start-Transcript "$($env:ProgramData)\ExampleApp\ExampleInstall.log"
 
#Create a mount directory and attempt to mount the .wim file
#Mount and Dismount code inspired by https://adminsccm.com/2020/07/20/use-a-wim-to-deploy-large-apps-via-configmgr-app-model/
try {
    $Mount = "$PSScriptRoot\Temp"
    [void](New-Item -Path $Mount -ItemType Directory -ErrorAction SilentlyContinue)
    Write-Host "Mounting the .wim to Temp directory"
    Mount-WindowsImage -ImagePath .\Estimate.wim -Index 1 -Path $Mount
}
catch {
    Write-Host "ERROR: Encountered an issue mounting the .wim. Exiting Script now."
    Write-Host "Error Message: $_"
    Exit 1
}
 
try {
    #Installing Application
    Write-Host "Installing Example App"
    Start-Process -FilePath "$Mount\ExampleInstall.exe" -Wait
}
catch {
    Write-Host "ERROR: Error installing application. Exiting Now"
    Write-Host "Error Message: $_"
    #Set Return Code 1 = Error
    $returnCode = 1
}
finally {
    try {
        Write-Host "Attempting to Dismount the image"
        Dismount-WindowsImage -Path $Mount -Discard
    }
    catch {
        #Failed to Dismount normally. Setting up a scheduled task to unmount after next reboot (exit code 3010)
        Write-Host "ERROR: Attempting to create scheduled task CleanupWIM to dismount image at next startup"
        Write-Host "Error Message: $_"
        #Set Return Code = 3010 to trigger a soft reboot
        $returnCode = 3010
 
        $STAction = New-ScheduledTaskAction `
            -Execute 'Powershell.exe' `
            -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -command "& {Get-WindowsImage -Mounted | Where-Object {$_.MountStatus -eq ''Invalid''} | ForEach-Object {$_ | Dismount-WindowsImage -Discard -ErrorVariable wimerr; if ([bool]$wimerr) {$errflag = $true}}; If (-not $errflag) {Clear-WindowsCorruptMountPoint; Unregister-ScheduledTask -TaskName ''CleanupWIM'' -Confirm:$false}}"'
 
        $STTrigger = New-ScheduledTaskTrigger -AtStartup
 
        Register-ScheduledTask `
            -Action $STAction `
            -Trigger $STTrigger `
            -TaskName "CleanupWIM" `
            -Description "Clean up WIM Mount points that failed to dismount" `
            -User "NT AUTHORITY\SYSTEM" `
            -RunLevel Highest `
            -Force
    }
 
    #Stop Logging and Return Exit Code
    Stop-Transcript
    exit $returnCode
}