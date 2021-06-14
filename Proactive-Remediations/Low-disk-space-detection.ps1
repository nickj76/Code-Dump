$os = Get-CimInstance Win32_OperatingSystem
$systemDrive = Get-CimInstance Win32_LogicalDisk -Filter "deviceid='$($os.SystemDrive)'"
if (($systemDrive.FreeSpace/$systemDrive.Size) -le '0.10') {
     return $false
}
else { 
     return $true 
}