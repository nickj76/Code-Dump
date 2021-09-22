.SYNOPSIS
Automatically install shared printer from a Windows print server
.DESCRIPTION
This script will add a shared printer
.EXAMPLE
#>


$Printer = "\\winprint.surrey.ac.uk\SSPDutyOffice"

try {
  Add-Printer -ConnectionName $Printer
  Write-Host "Printer added: $($Printer)"
}
Catch [System.Exception] {
  Write-Host "Error adding printer $($Printer) with error $($_.Exception.Message)"
}

## Create Detection Method.
$path = "C:\logfiles"
   If(!(test-path $path))
 {
      New-Item -ItemType Directory -Force -Path $path
 }

New-Item -ItemType "file" -Path "c:\logfiles\winprinttest.txt"