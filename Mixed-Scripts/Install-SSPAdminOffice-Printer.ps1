<# 
.SYNOPSIS
   Install Script to add the SSP Printer Queues to the local machine.

.DESCRIPTION
   Add the SSP Printer Queues and make avaliable for use. 

.EXAMPLE
   PS C:\> .\SSPPrintQueues.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v1+
#>

Start-Transcript -Path c:\temp\SSPAdminOffice.txt

$printServer = "Winprint.surrey.ac.uk"
$printer = "SSPAdminOffice"
$printer1 = "SSPDutyOffice"
$printer2 = "Q_SSP_10"

Invoke-Command -ScriptBlock { rundll32 printui.dll, PrintUIEntry /in /n\\$printServer\$printer }

Invoke-Command -ScriptBlock { rundll32 printui.dll, PrintUIEntry /in /n\\$printServer\$printer1 }

Invoke-Command -ScriptBlock { rundll32 printui.dll, PrintUIEntry /in /n\\$printServer\$printer2 }

# Create Detection Method.
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\SSPAdminOffice.txt"
Stop-Transcript