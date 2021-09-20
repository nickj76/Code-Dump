#Copy PrinterDrivers to Device
xcopy /Y ".\PrinterDrivers\Ricoh Universal Print v4.30\*.*" "C:\PrinterDrivers\Ricoh Universal Print v4.30\*.*"

#Install Ricoh Universal Print driver v4.30
cscript "C:\Windows\System32\Printing_Admin_Scripts\en-US\prndrvr.vbs" -a -m "RICOH PCL6 UniversalDriver V4.30" -i "C:\PrinterDrivers\Ricoh Universal Print v4.30\oemsetup.inf"

#Install Printerport with check if the port already exist
$portName = "IP_192.168.100.1"
$checkPortExists = Get-Printerport -Name $portname -ErrorAction SilentlyContinue
if (-not $checkPortExists) {
Add-PrinterPort -name $portName -PrinterHostAddress "192.168.100.1"
}

#Install Printer
Add-Printer -Name "PrinterName" -DriverName "RICOH PCL6 UniversalDriver V4.30" -PortName $portName