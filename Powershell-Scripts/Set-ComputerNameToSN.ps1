<#
.SYNOPSIS
Set Computername to serial number
.DESCRIPTION
This script uses WMI to retrieve the serial number from Win32_Bios and renames the computer
.EXAMPLE
.\Set-ComputerNameToSN.ps1
#>

Begin {
    $SerialNumber = $null;
    $ComputerName = $null;
}

Process
{
    $SerialNumber = (Get-WmiObject Win32_BIOS -Property SerialNumber).SerialNumber

    if ($SerialNumber) {
        Write-Host "BIOS S/N $($SerialNumber)."
        $ComputerName = $SerialNumber.Replace("\","").Replace("/","").Replace(":","").Replace("*","").Replace("?","").Replace("`"","").Replace("<","").Replace(">","").Replace("|","")
    
        if ($ComputerName.Length -gt 15) {
            $ComputerName = $SerialNumber.SubString(0,15)
        }
        Write-Host "S/N trimmed to $($ComputerName)."
    }
}

End {
    if ($ComputerName) {
        Rename-Computer -NewName $ComputerName | Out-Null
        Write-Host "Computer name changed, you need to restart"
    }
}