

$Printer = "\\printservice.surrey.ac.uk\SurreyPrint"

try {
  Add-Printer -ConnectionName $Printer
  Write-Host "Printer added: $($Printer)"
}
Catch [System.Exception] {
  Write-Host "Error adding printer $($Printer) with error $($_.Exception.Message)"
}