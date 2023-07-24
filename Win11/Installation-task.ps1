###># CREATE SCHEDULED TASK -------------------------------------------------------->

    $STExecutable = "$dirfiles\ISO\Setup.exe"
    $STArguments = "/Auto Upgrade /EULA accept /NoReboot"
    $STTaskName = "Win11Upgrade"
    $STTriggerTime = (Get-Date).AddSeconds(15)
    $STPriority = 4

    $STTrigger = New-ScheduledTaskTrigger -Once -At $STTriggerTime
    $STSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable -Priority $STPriority -RunOnlyIfNetworkAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

    # Create a new scheduled task action
    $STAction = New-ScheduledTaskAction -Execute $STExecutable -Argument $STArguments -WorkingDirectory (Split-Path $STExecutable)

    # Create a new scheduled task principal for the SYSTEM account
    $STPrincipal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    # Create and register the new scheduled task
    $STTask = New-ScheduledTask -Action $STAction -Trigger $STTrigger -Settings $STSettings -Principal $STPrincipal
    Register-ScheduledTask -TaskName $STTaskName -InputObject $STTask


    #### KICK OFF SCHEDULED TASK ------------------------------------------------------>
    Start-Sleep 10
    Start-ScheduledTask -TaskName "Win11Upgrade"

    #### MONITOR SCHEDULED TASK ------------------------------------------------------->
    $STTaskName = "Win11Upgrade"

    # Loop until the task is no longer running
    while ((Get-ScheduledTask -TaskName $STTaskName).State -eq "Running")
    {
        # Get task information
        $taskInfo = Get-ScheduledTaskInfo -TaskName $STTaskName

        # Verify if the task is being run by SYSTEM
        if ((Get-ScheduledTask -TaskName $STTaskName).Principal.UserId -eq "SYSTEM")
        {
            # Write to the output
            Write-Output "$STTaskName is still running as SYSTEM"
        }
        else
        {
            Write-Output "$STTaskName is still running, but not as SYSTEM"
        }

        # Wait for 10 seconds before checking again
        Start-Sleep -Seconds 10
    }

    Write-Output "$STTaskName has finished running"