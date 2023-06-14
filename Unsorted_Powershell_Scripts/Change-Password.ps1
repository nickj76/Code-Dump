Start-Process "https://account.activedirectory.windowsazure.com/ChangePassword.aspx"

## Create Detection Method. 
$logfilespath = "C:\logfiles"
If(!(test-path $logfilespath))
{
      New-Item -ItemType Directory -Force -Path $logfilespath
}

New-Item -ItemType "file" -Path "c:\logfiles\Password-Change.txt"