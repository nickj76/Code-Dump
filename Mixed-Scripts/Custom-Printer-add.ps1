pnputil.exe /add-driver "C:\Temp\Printers\KOAXPJ__.INF" /install
Add-PrinterDriver -Name "KONICA MINOLTA C3851SeriesPCL" 
Add-PrinterPort -Name "\\winprint.surrey.ac.uk\SSPDutyOffice" -PrinterHostAddress "\\winprint.surrey.ac.uk\SSPDutyOffice"
Add-Printer -DriverName "KONICA MINOLTA C3851SeriesPCL" -Name "SSPDutyOffice" -PortName "SSPDutyOffice"

# Create Detection Method.
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\SSPDutyOfficePrinter.txt"