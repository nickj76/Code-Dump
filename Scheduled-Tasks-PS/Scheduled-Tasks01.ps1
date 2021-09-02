$Trigger= New-ScheduledTaskTrigger -Atlogin # Specify the trigger settings
$User= "NT AUTHORITY\SYSTEM" # Specify the account to run the script
$Action= New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "C:\PS\toast.ps1" # Specify what program to run and with its parameters
Register-ScheduledTask -TaskName "Office-Update-message" -Trigger $Trigger -User $User -Action $Action -RunLevel Highest –Force # Specify the name of the task