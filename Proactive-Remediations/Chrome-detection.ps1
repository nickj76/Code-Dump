<#
.SYNOPSIS
    Detect Google Chrome Proactive Remediation Script.

.DESCRIPTION
    Script to detect if Google Chrome installed on the computer.
    
.NOTES
    Filename: Chrome-detection.ps1
    Version: 1.3
     
    Version history:

    1.3   -   Update if / else 
    1.2   -   Add Detection for software version
    1.1   -   Production version
    1.0.1 -   Add Synopsis, Description, Paramenter, notes, and set minimum percentage of free space.
    1.0   -   Script created

#>

$software = "Google Chrome";
$version = "91.0.4472.114";
$installed = $null -ne (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -eq $software })
$installed = $null -ne (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayVersion -eq $version })


If(-Not $installed) {
	Write-Host "'$software $version' NOT is installed"
    exit 0
} else {
	Write-Host "'$software $version' is installed"
    exit 1
}
catch {
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}