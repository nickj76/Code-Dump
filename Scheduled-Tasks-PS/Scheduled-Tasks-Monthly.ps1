$Trigger= New-ScheduledTaskTrigger -At 3:00pm -Weekly -WeeksInterval 4 -DaysOfWeek Thursday # Specify the trigger settings
$User= "NT AUTHORITY\SYSTEM" # Specify the account to run the script
$Action= New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "C:\PS\Windows-Install-Firefox-latest.ps1" # Specify what program/script to run and with its parameters
Register-ScheduledTask -TaskName "Firefox Updater" -Trigger $Trigger -User $User -Action $Action -RunLevel Highest –Force # Specify the name of the task
New-ScheduledTaskSettingsSet -Compatibility V1 -AllowStartIfOnBatteries 