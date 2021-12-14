msg * /SERVER:$system /TIME:300 "Computer will be restarted in 5 minutes."
restart-computer -computername $system -Force -Wait -For PowerShell -Delay 2