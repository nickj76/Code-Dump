$Trigger= New-ScheduledTaskTrigger -At 3:00pm –weekly -DaysOfWeek Monday, Friday # Specify the trigger settings
$User= "NT AUTHORITY\SYSTEM" # Specify the account to run the script
$Action= New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "C:\PS\name-of-script-here.ps1" # Specify what program to run and with its parameters
Register-ScheduledTask -TaskName "give task a name here" -Trigger $Trigger -User $User -Action $Action -RunLevel Highest –Force # Specify the name of the task