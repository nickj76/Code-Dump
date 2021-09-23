## Run this in the user context..
#region functions
Function Set-LocalPrinters {
    <#
    .SYNOPSIS
        Installs network printer to local machine.
    .PARAMETER Server
        FQDN or IP Address of print server
    .PARAMETER printerName
        Name of printer to be installed
    #>
    param (
        [string]$server,

        [string]$printerName
    )
    $printerPath = $null
    $PrinterPath = "\\$($server)\$($printerName)"
    $netConn = Test-NetConnection -ComputerName $Server | select-object PingSucceeded, NameResolutionSucceeded
    if (($netconn.PingSucceeded) -and ($netConn.NameResolutionSucceeded)) {
        write-host "Installing $printerName.." -ForegroundColor Green
        if (Get-Printer -Name "$printerPath" -ErrorAction SilentlyContinue) {
            Write-Host "Printer $printerPath already installed" -ForegroundColor Green
        }
        else {
            Write-Host "Installing $printerPath" -ForegroundColor Green
            & cscript /noLogo C:\windows\System32\Printing_Admin_Scripts\en-US\prnmngr.vbs -ac -p $printerPath
            if (Get-Printer -Name "$printerPath" -ErrorAction SilentlyContinue) {
                Write-Host "$printerPath successfully installed.."
            }
            else {
                Write-Warning "$printerPath not successfully installed"
            }
        }
    }
    else {
        Write-Host "Print server not pingable. $printerPath will not be installed" -ForegroundColor Red
    }
}
#endregion
#region Printers to install
$printers = @(
    [PSCustomObject]@{
        Printer = "SSPDutyOffice"
        Server = "Winprint.surrey.ac.uk"
    }
    [PSCustomObject]@{
        Printer = "Q_SSP_10"
        Server = "Winprint.surrey.ac.uk"
    }
    [PSCustomObject]@{
        Printer = "SSPTillPrinter"
        Server = "Winprint.surrey.ac.uk"
    }
)
#endregion
#region Install printers
foreach ($p in $printers) {
    Set-LocalPrinters -server $p.Server -printerName $p.Printer
}
#endregion