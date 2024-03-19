#Run as administrator
Clear-Host
Write-Output "+---------------------------+"
Write-Output "|         Bitlocker         |"
Write-Output "+---------------------------+"
Write-Output ""
Write-Output "What do you want to do?"
Write-Output ""
Write-Output "(1). Check status on remote host"
Write-Output "(2). Enable bitlocker on remote host"
Write-Output "(3). Disable bitlocker on remote host"
Write-Output "(4). Enable bitlocker on local host"
Write-Output ""
$chosenpath = Read-Host "choose"

if ($chosenpath -eq 1)
{
    Clear-Host
    Write-Output "Who is the target?"
    $target = Read-Host -Prompt 'Input hostname'
    Clear-Host
    manage-bde -status C: -cn $target
    pause
    exit
}
if ($chosenpath -eq 2)
{
    Clear-Host
    Write-Output "Who is the target?"
    $target = Read-Host -Prompt 'Input hostname'
    Clear-Host
    Write-Output "Who is the user? (username)"
    $user = Read-Host -Prompt 'Input username'
    Clear-Host
    Write-Output "Target host: " $target
    Write-Output ""
    Write-Output "Target user: " $user
    Write-Output ""
    Write-Output "----------------"
    Write-Output "Is this correct?"
    Write-Output ""
    $confirm = Read-Host "(Y)es / (N)o"
    if ($confirm -eq 'y' -or $confirm -eq 'yes')
    {
        Clear-Host
        Write-Output "Enabling bitlocker on remote computer"
        Start-Sleep (1)
        Write-Output "waiting 5 seconds"
        Start-Sleep (1)
        Write-Output "."
        Start-Sleep (1)
        Write-Output "."
        Start-Sleep (1)
        Write-Output "."
        Start-Sleep (1)
        Write-Output "."
        Start-Sleep (1)
        Write-Output "Enabling!"
        Start-Sleep (1)
        Clear-Host
        #-----------------------------------------------
        Write-Output "Adding key protectors ..."
        Start-Sleep (1)
        Write-Output "."
        Start-Sleep (1)
        Write-Output "."
        Start-Sleep (1)
        manage-bde -protectors -add C: -tpm -sid $user
        Start-Sleep (1)
        Write-Output "."
        Start-Sleep (1)
        Write-Output "."
        Write-Output ""
        Write-Output "Identity and TPM protector have been added."
        Write-Output "Pausing to let you verify if it succeeded or failed"
        pause
        Clear-Host
        #-----------------------------------------------
        Write-Output "Enabling bitlocker on C: ..."
        Start-Sleep (1)
        Write-Output "."
        Start-Sleep (1)
        Write-Output "."
        Start-Sleep (1)
        manage-bde -on C: -RecoveryKey C:\ -s -cn $target
        Start-Sleep (1)
        Write-Output "."
        Start-Sleep (1)
        Write-Output "."
        Write-Output ""
        Write-Output "Encryption and protection have been enabled."
        Write-Output "-----------------------"
        manage-bde -status C: -cn $target
        Write-Output "-----------------------"
        Write-Output "Pausing to let you verify if it succeeded or failed"
        pause
        Clear-Host
        Write-Output "DONE!"
    }
    if ($confirm -eq 'n' -or $confirm -eq 'no')
    {
        Clear-Host
        Write-Output "Understood, goodbye."
        pause
        exit
    }
}
if ($chosenpath -eq 3)
{
    Clear-Host
    Write-Output "Who is the target?"
    $target = Read-Host -Prompt 'Input hostname'
    Clear-Host
    Write-Output "Who is the user? (username)"
    $user = Read-Host -Prompt 'Input username'
    Clear-Host
    Write-Output "Target host: " $target
    Write-Output ""
    Write-Output "Target user: " $user
    Write-Output ""
    Write-Output "----------------"
    Write-Output "Is this correct?"
    Write-Output ""
    $confirm = Read-Host "(Y)es / (N)o"
    if ($confirm -eq 'y' -or $confirm -eq 'yes')
    {
        Clear-Host
        Write-Output "Disabling bitlocker on remote computer"
        Start-Sleep (1)
        Write-Output "waiting 5 seconds"
        Start-Sleep (1)
        Write-Output "."
        Start-Sleep (1)
        Write-Output "."
        Start-Sleep (1)
        Write-Output "."
        Start-Sleep (1)
        Write-Output "."
        Start-Sleep (1)
        Write-Output "Disabling!"
        Start-Sleep (1)
        Clear-Host
        #-----------------------------------------------
        Write-Output "Disabling bitlocker on C: ..."
        Start-Sleep (1)
        Write-Output "."
        Start-Sleep (1)
        Write-Output "."
        Start-Sleep (1)
        manage-bde -off C: -cn $target
        Start-Sleep (1)
        Write-Output "."
        Start-Sleep (1)
        Write-Output "."
        Write-Output ""
        Write-Output "Should have disabled encryption and protection"
        Write-Output "-----------------------"
        manage-bde -status C: -cn $target
        Write-Output "-----------------------"
        Write-Output "Pausing to let you verify if it succeeded or failed"
        pause
        Clear-Host
        Write-Output "DONE!"
    }
    if ($confirm -eq 'n' -or $confirm -eq 'no')
    {
        Clear-Host
        Write-Output "Goodbye."
        pause
        exit
    }
}
if ($chosenpath -eq 4)
{
    #Checking if bitlocker is already enabled
    $BitlockerStatus = Get-BitlockerVolume C:
    if($BitlockerStatus.ProtectionStatus -eq 'On' -and $BitlockerStatus.EncryptionPercentage -eq '100')
    {
        Write-Output "Bitlocker is already enabled, exiting"
        Start-Sleep(1)
        exit
    }

    #Checking if bitlocker is already in progress
    $BitlockerInprogressStatus = Get-BitlockerVolume C:
    if($BitlockerInprogressStatus.EncryptionPercentage -gt '0' -and $BitlockerInprogressStatus.EncryptionPercentage -lt '100' -and $BitlockerInprogressStatus.VolumeStatus -eq 'EncryptioninProgress')
    {
        Write-Output "Bitlocker is already in progress, exiting"
        Start-Sleep(1)
        exit
    }
    
    #At this point only remaining scenarios are either 0% or 100% encrypted with protection off
    #which means bitlocker is either not enabled at all, or drive is encrypted but missing protectors.
    
    #Adding the TPM chip as keyprotector
    manage-bde -protectors -add C: -tpm
    Start-Sleep(1)
    #Enabling bitlocker on C:
    #If drive is already encrypted, bitlocker is instantly enabled and encryption is skipped
    manage-bde -on C: -RecoveryKey C:\ -s -used
    exit   
}
Clear-Host
Write-Output "Invalid input."
Start-Sleep (1)
exit