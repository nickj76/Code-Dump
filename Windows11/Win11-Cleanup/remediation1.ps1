#Windows.old path 
$path = $env:HOMEDRIVE+"\windows.old"
If(Test-Path -Path $path)
{
    #create registry value
    $regpath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Previous Installations"
    New-ItemProperty -Path $regpath -Name "StateFlags1221" -PropertyType DWORD  -Value 2 -Force  | Out-Null
    #start clean application
    cleanmgr /SAGERUN:1221
}
Else
{
	Write-Host "There is no 'Windows.old' folder in system driver" 
}