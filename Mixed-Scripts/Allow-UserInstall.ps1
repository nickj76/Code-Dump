<#
.SYNOPSIS
Enables users to install printer drivers on Azure AD joined devices

.DESCRIPTION
This powershell script was created to be uploaded as an Intunewin application in Intune.
Packaged with Microsoft Win32 Content Prep Tool and used with the parameters shown in the example below.
This is a translation of a well known GPO ("Allow non-administrators to install drivers for these device setup classes") under 
"Computer Configuration -> Policies -> Administrative Templates -> System -> Driver Installation" to be used with intune.
AFAIK this is the only way to set this policy as no Configuration profile is availble, not even a custom OMA-URI.

.EXAMPLE
Via intune Win32App
    Install command: powershell -ex bypass -file AllowNon-AdministratorsToInstallPrinterDrivers.ps1
    Uninstall command: powershell -ex bypass -file AllowNon-AdministratorsToInstallPrinterDrivers.ps1 -uninstall
Manually configure detection rules
    Detection rules: 
        - Rule type: Registery
        - Key path: HKLM:\Software\Policies\Microsoft\Windows\DriverInstall\Restrictions\AllowUserDeviceClasses\
        - Value name: printer
        - Detection method: Key exists

        .NOTES
NAME: AllowNon-AdministratorsToInstallPrinterDrivers.ps1
VERSION: 1.1
DATE: 04.02.2020
AUTHOR: Jelle Revyn (jelle.revyn.xyz)
COAUTHOR: Bart Haevermaet
RELEASE NOTES:
    Version 1.0: Initial release
    Version 1.1: If path doesn't exist, create it, use of destinctive names.
LINKS:
https://theitbros.com/allow-non-admins-install-printer-drivers-via-gpo/
https://docs.microsoft.com/en-us/windows-hardware/drivers/install/system-defined-device-setup-classes-available-to-vendors
DISCLAIMER
    The script is provided "AS IS" with no warranties
#> 

PARAM(
    [Parameter(Mandatory=$false)]
        [switch]$uninstall
)

#Set the path
$newPath = "HKLM:\Software\Policies\Microsoft\Windows\DriverInstall\Restrictions\AllowUserDeviceClasses"
$allowPath = "HKLM:\Software\Policies\Microsoft\Windows\DriverInstall\Restrictions"
#Property name
#Class = Printer
$name1 = "printer"
$value1 = "{4658ee7e-f050-11d1-b6bd-00c04fa372a7}"
#Class = PNPPrinters
$name2 = "PNPprinter"
$value2 ="{4d36e979-e325-11ce-bfc1-08002be10318}"
#AllowUserDeviceClasses
$name3="AllowUserDeviceClasses"
$value3 = 1

#Check if its an uninstall or install
if($uninstall){
    Remove-ItemProperty -Path $newPath -Name $name1 -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $newPath -Name $name2 -Force -ErrorAction SilentlyContinue 
    Remove-ItemProperty -Path $allowPath -Name $name3 -Force -ErrorAction SilentlyContinue 
} 
else{
    #check if the property exists
    $item1 = Get-ItemProperty -Path $newPath -Name $name1 -ErrorAction SilentlyContinue
    $item2 = Get-ItemProperty -Path $newPath -Name $name2 -ErrorAction SilentlyContinue
    if($item1 -And $item2){
        #DO NOTHING
    }
    Else{
        #check if path exits, if not create it
        if(!(test-Path $newPath)){
            New-Item -Path $newPath -force | Out-Null
        }
        #create a new property
        New-ItemProperty -Path $newPath -Name $name1 -Value $value1 -PropertyType String | Out-Null 
        New-ItemProperty -Path $newPath -Name $name2 -Value $value2 -PropertyType String | Out-Null 
        New-ItemProperty -Path $allowPath -Name $name3 -Value $value3 -PropertyType DWord | Out-Null 
    }
}