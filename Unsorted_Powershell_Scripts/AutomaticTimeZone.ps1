<# Run this script in a 64 bit PowerShell Host 
#>

#Turn on device location and time zone auto update
New-ItemProperty -force -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Allow" -erroraction ignore
New-ItemProperty -force -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Allow" -erroraction ignore 
New-ItemProperty -force -Path "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate" -Name "Start" -Value 3 -erroraction ignore

#Set the NTP server
New-ItemProperty -force -Path  "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "Type" -Value "NTP"  -erroraction ignore
New-ItemProperty -force -Path  "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "NtpServer" -Value "time.windows.com,0x1" -erroraction ignore

#Configure the w32tm service
Invoke-Expression -Command "cd C:\Windows\System32" -erroraction ignore
Invoke-Expression -Command "net stop w32time" -erroraction ignore
Invoke-Expression -Command "w32tm /unregister" -erroraction ignore
Invoke-Expression -Command "w32tm /register" -erroraction ignore
Invoke-Expression -Command ".\sc config w32time type= own" -erroraction ignore
Invoke-Expression -Command "net start w32time" -erroraction ignore
Invoke-Expression -Command "w32tm /config /update /manualpeerlist:time.windows.com /syncfromflags:MANUAL /reliable:yes" -erroraction ignore
Invoke-Expression -Command "w32tm /resync" -erroraction ignore
Invoke-Expression -Command "popd" -erroraction ignore

#Configure the time sync scheduled task trigger
Invoke-Expression -Command ".\sc triggerinfo w32time delete" -erroraction ignore
Invoke-Expression -Command ".\sc triggerinfo w32time start/networkon stop/networkoff"-erroraction ignore

#Return code  for success
if($?) {
	# True, last operation succeeded
}

if (!$?) {
	# Not True, last operation failed
}