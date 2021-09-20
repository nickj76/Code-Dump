<# 
.SYNOPSIS
   Install SSP Printers.

.DESCRIPTION
   Script to add device drivers to the driverstore and install the SSP printers.

.EXAMPLE
   PS C:\> .\Win10-Install-SSP-Printers.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt. 

.FUNCTIONALITY
   PowerShell v1+
#>

## Add printer drivers to driverstore
pnputil.exe -i -a  C:\Temp\Printers\*.inf

Add-PrinterDriver -Name "KONICA MINOLTA C3851SeriesPCL" 
Add-PrinterPort -Name "SSPDutyOfficeprinter" -PrinterHostAddress "\\winprint.surrey.ac.uk\SSPDutyOffice"
Add-Printer -DriverName "KONICA MINOLTA C3851SeriesPCL" -Name "SSPDutyOffice" -PortName "SSPDutyOfficeprinter"

Add-PrinterPort -Name "SSPAdminOfficeprinter" -PrinterHostAddress "\\winprint.surrey.ac.uk\SSPAdminOffice"
Add-Printer -DriverName "KONICA MINOLTA C3851SeriesPCL" -Name "SSPDutyOffice" -PortName "SSPAdminOfficeprinter"

Add-PrinterDriver -Name "KONICA MINOLTA C3100P PCL6" 
Add-PrinterPort -Name "Q_SSP_10-Printer" -PrinterHostAddress "\\winprint.surrey.ac.uk\Q_SSP_10"
Add-Printer -DriverName "KONICA MINOLTA C3100P PCL6" -Name "SSPDutyOffice" -PortName "Q_SSP_10-Printer"

# Create Detection Method.
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\SSPDutyOfficePrinter.txt"