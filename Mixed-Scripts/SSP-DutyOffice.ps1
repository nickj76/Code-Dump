pnputil.exe -i -a  C:\Temp\Printers\*.inf
Add-PrinterDriver -Name "KONICA MINOLTA C3851SeriesPCL" 
Add-PrinterPort -Name "SSPDutyOfficeprinter" -PrinterHostAddress "\\winprint.surrey.ac.uk\SSPDutyOffice"
Add-Printer -DriverName "KONICA MINOLTA C3851SeriesPCL" -Name "SSPDutyOffice" -PortName "SSPDutyOfficeprinter"

# Create Detection Method.
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\SSPDutyOfficePrinter.txt"