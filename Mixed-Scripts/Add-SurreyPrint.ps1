<# 
.SYNOPSIS
   Install Script to add the SurreyPrint Printer Queue to the local machine.

.DESCRIPTION
   Add the SurreyPrint Printer Queue and make avaliable for use. 

.EXAMPLE
   PS C:\> .\SurreyPrintQueue.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v1+
#>

Start-Transcript -Path c:\temp\SurreyPrintQ.txt

$Printer = "\\printservice.surrey.ac.uk\SurreyPrint"

try {
  Add-Printer -ConnectionName $Printer
  Write-Host "Printer added: $($Printer)"
}
Catch [System.Exception] {
  Write-Host "Error adding printer $($Printer) with error $($_.Exception.Message)"
}

# Create Detection Method.
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\SurreyPrintQ.txt"
Stop-Transcript