$Action = New-ScheduledTaskAction -Execute 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -Argument C:\it\Toast-Messages\Toast-Message.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Principle = New-ScheduledTaskPrincipal -UserId System -RunLevel Highest
$NewTask = New-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principle
Register-ScheduledTask "Updating-Office-Toast-Message" -InputObject $NewTask