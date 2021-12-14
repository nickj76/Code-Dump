$wshell = New-Object -ComObject Wscript.Shell

$xwshell = New-Object -ComObject Wscript.Shell

#Display pop-up box and if the user does not press "ok" button
#Box will automatically close after 5 seconds

$wshell.Popup("This computer is scheduled for shutdown",5,"Save your data..",0x0)

#Display pop-up box and if the user does not press "ok" button
#Box will automatically close after 3 seconds

$xwshell.Popup("30 seconds to shutdown",3,"Please save, you got 30 seconds..",0x0)

#wait for 30 seconds before shutting down

$xCmdString = {Start-Sleep 30}

Invoke-Command $xCmdString

Restart-Computer -ComputerName Server01