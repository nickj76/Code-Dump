<# 
.SYNOPSIS
   Install SSP Duty Printer.

.DESCRIPTION
   Script to add device drivers to the driverstore and install the SSP Duty Office printer.

.EXAMPLE
   PS C:\> .\Win10-Install-SSP-Printers.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt. 

.FUNCTIONALITY
   PowerShell v1+
#>

## Add printer drivers to driverstore
pnputil.exe -i -a  C:\Temp\Print\*.inf

Add-PrinterDriver -Name "KONICA MINOLTA C3851SeriesPCL" 
Add-PrinterPort -Name "\\winprint.surrey.ac.uk\SSPDutyOffice" -PrinterHostAddress "\\winprint.surrey.ac.uk\SSPDutyOffice"
Add-Printer -DriverName "KONICA MINOLTA C3851SeriesPCL" -Name "SSPDutyOffice" -PortName "SSPDutyOfficeprinter"

# Create Detection Method.
# $path = "C:\logfiles"
# If(!(test-path $path))
# {
#      New-Item -ItemType Directory -Force -Path $path
# }

# New-Item -ItemType "file" -Path "c:\logfiles\SSPDutyOfficePrinter.txt"