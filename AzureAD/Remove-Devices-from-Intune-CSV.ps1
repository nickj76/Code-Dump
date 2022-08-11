<#
Remove Devices from intune

the CSV content example:

Name,Id
DeviceID1,9d5aa283-07a9-48a7-bb8c-75beaa88862c

#>

$DeviceID = Import-Csv "C:\temp\testremove.csv"

foreach ($DevID in $DeviceID){

Invoke-DeviceAction -DeviceID $DevID.id -Retire
Invoke-DeviceAction -DeviceID $DevID.id -Delete

}