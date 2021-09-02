if ($(Get-ScheduledTask -TaskName "Updating-Office-Toast-Message" -ErrorAction SilentlyContinue).TaskName -eq "Updating-Office-Toast-Message") {
    Unregister-ScheduledTask -TaskName "Updating-Office-Toast-Message" -Confirm:$False
}