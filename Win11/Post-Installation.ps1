    #### (Post-Install) Delete Scheduled Task -------------------------------------------->

    $DELTaskName = "Win11Upgrade"

    # Check if the task exists
    $DELTaskExists = Get-ScheduledTask -TaskName $DELTaskName -ErrorAction SilentlyContinue

    if ($DELTaskExists) {
        # Delete the task
        Unregister-ScheduledTask -TaskName $DELTaskName -Confirm:$false
        Write-Output "(Post-Install) Task '$DELTaskName' has been deleted."
    } else {
        Write-Output "(Post-Install) Task '$DELTaskName' does not exist."
    }