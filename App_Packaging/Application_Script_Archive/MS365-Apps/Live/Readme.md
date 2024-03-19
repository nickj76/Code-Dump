## Scripts to Remove Office C2R and Install Microsoft Apps 365 for Enterprise
## Updates

7/12/21
* Simplified script removing the download of ODT and included it in the file ODT-Config-Files.7z.

1/12/21
* Created script to stop running office applications gracefully, users are now prompted to save work before the application will close.
* Created script to run toast notification warning user of incoming upgrade.

30/11/21
* Pointed to specific xml config file.

29/11/21
* Cleaned up styling and reduced function complexity.
* Fixed bug that would cause false reporting on if Office was installed correctly or not.
* Added `-CleanUpInstallFiles` parameter.

## A little overview as to why I had deploy office this way 
I needed a way to upgrade office click to run from the 32 bit version to the 64 bit Monthly Enterprise Channel 365 Apps, using intune & the Microsoft CDN was causing Teams to be removed after a reboot or a few days. Microsoft could not figure out why, so I worked to automate an upgrade using Powershell scripts & the ODT, for reference the ODT appears to ignore Teams & OneDrive.

## Description
A collection of PowerShell scripts that remove office C2R and install Office 365 using parameters specified in the XML files (Install-MS-Apps-365.xml & Remove-Office.xml). 

## Features
These scripts will remove office click to run and install Microsoft Apps 365 for Enterprise using the Office Deployment Tool from Microsoft's website first. The XML file location and name is set on line 16 of Install-Office365 & Remove-Office PS1 files. you will need to build each Powershell script into an intune package.

`.\Install-Office365.ps1` - run in system context \
  `.\Office-Upgrade-Toast.ps1` - run in user context \
  `.\Remove-OfficeC2R.ps1` - run in system context \
    `.\Stop-Running-Office-Apps.ps1` - run in user context 

## Additional Info
By default, the script will use the ODT tool located in "C:\Temp\MSApps365" folder. 

 `ODT-Config-Files.7z` - 7Zip File containing the xml files & the ODT, use install.bat as the installer.