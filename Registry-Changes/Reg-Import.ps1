#Grab current directory
$oInvocation = (Get-Variable MyInvocation).Value
$sCurrentDirectory = Split-Path $oInvocation.MyCommand.Path

#Grab all .reg and pipe it into a reg import command
Get-ChildItem $sCurrentDirectory -Filter "install.exe" -Recurse | 
ForEach-Object{
 Start-Process -FilePath "C:\windows\system32\cmd.exe" -WindowStyle Minimized `
 -ArgumentList @('/C REG IMPORT "' + $_.FullName + '"') -Wait
}