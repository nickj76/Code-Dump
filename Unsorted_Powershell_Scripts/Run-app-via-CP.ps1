start-process companyportal:ApplicationId=YourAppID
Start-Sleep 10
[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
[System.Windows.Forms.SendKeys]::SendWait("^{i}")