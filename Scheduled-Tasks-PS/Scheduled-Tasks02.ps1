$Trigger= New-ScheduledTaskTrigger -At 3:00pm –weekly -DaysOfWeek Monday, Friday # Specify the trigger settings
$User= "NT AUTHORITY\SYSTEM" # Specify the account to run the script
$Action= New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "C:\PS\toast.ps1" # Specify what program to run and with its parameters
Register-ScheduledTask -TaskName "GP-Reminder" -Trigger $Trigger -User $User -Action $Action -RunLevel Highest –Force # Specify the name of the task
New-ScheduledTaskSettingsSet -Compatibility V1 -AllowStartIfOnBatteries -DeleteExpiredTaskAfter (New-TimeSpan -Seconds 6000)