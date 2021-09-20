#Remove Printer
Remove-Printer -Name "PrinterName"

#Uninstall Printerport with check if the port already exist
$portName = "IP_192.168.100.1"
$checkPortExists = Get-Printerport -Name $portname -ErrorAction SilentlyContinue
if (-not $checkPortExists) {
Remove-PrinterPort -name $portName -PrinterHostAddress "192.168.100.1"
}

#Remove PrinterDrivers
Remove-Item -Recurse -Force C:\PrinterDrivers