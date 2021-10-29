<# 
.SYNOPSIS
   Add Global Protect Portal Name.

.DESCRIPTION
   Creates registry entry to add the portal name for Global Protect.

.EXAMPLE
   PS C:\> .\GP-Portal-Regkey.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v1+
#>

$Path = "HKLM:\SOFTWARE\Palo Alto Networks\GlobalProtect\PanSetup"
$Name = "Portal"
$Type = "String"
$Value = "vpn.surrey.ac.uk"

IF(!(Test-Path $Path))

{

New-Item -Path $Path -Force | Out-Null

Set-ItemProperty -Path $Path -Name $Name -Type $Type -Value $Value | Out-Null }

ELSE {

Set-ItemProperty -Path $Path -Name $Name -Type $Type -Value $Value | Out-Null }