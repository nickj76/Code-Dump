<# .SYNOPSIS 
    Check for presence of application
 
.DESCRIPTION 
	This is for use with SCCM as an Application custom script "Detection Method".
    This script will check the install status of an application utilizing the system registry.
	If application is found and the version is greater than or equal to, will report back as "Installed".
	
	NOTE: This has an additional check that scans dell_update.log for installation status
    
.EXAMPLE 
    .\Detect_App.ps1
     
.NOTES 

	 Change the Global Variables as needed for each application.
		$InstallerVersion = is the version of the application you are deploying with SCCM. 
			- This is compared with the detected Registry value "DisplayVersion" 
			- Ex. [version]$InstallerVersion = "21.011.20039"
			
		$AppName = this is the "DisplayName" value that the application uses in Registry
			- Ex. $AppName = "Adobe Acrobat Reader DC"
			
		$AppVendor = this is the "Publisher" value that the application uses in Registry
			- Ex. $AppVendor = "Adobe Systems Incorporated"

.NOTES 
    FileName:  Detect_App.ps1
    Author:    Payton C
    Created:   4/15/2022
    Updated:   4/15/2022
    Version: 1.0.0 
#>

Set-ExecutionPolicy -ExecutionPolicy Bypass

##Global Variable Declaration

[version]$InstallerVersion = "4.5.0"
$AppName = "Dell Command | Update"
$AppVendor = "Dell Inc."
$AppFileName = 'dell_update.log'
$appUpdateCheck = 0
$dateCheck = Get-Date -Format "yyyy-MM-dd"

#Check if the dell_update.log exists before running
If (!(Test-Path "C:\temp\dell update\$AppFileName")){
	Exit
}

#Check for successful installation of updates 
If (get-content -path "C:\temp\dell update\$AppFileName" | select-string -pattern "$dateCheck \w{2}:\w{2}:\w{2}] : Finished installing the updates."){
	$appUpdateCheck = 1
}
#Check if the scan detected no avaliable updates
If (get-content -path "C:\temp\dell update\$AppFileName" | select-string -pattern "$dateCheck \w{2}:\w{2}:\w{2}] : The program exited with return code: 500"){
	$appUpdateCheck = 1
}

##32-Bit Detection
$32BitApps = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | where {($_.displayname -like "*$AppName*") -AND ($_.publisher -like "*$AppVendor*")}
Foreach ($32BitApp in $32BitApps){
	[version]$InstalledVersion = $32BitApp.DisplayVersion
	If (($InstalledVersion -ge $InstallerVersion) -AND ($appUpdateCheck -eq 1)){
		Write-Host "Installed"
    }
    Else{
    }
}

##64-Bit Detection
$64BitApps = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | where {($_.displayname -like "*$AppName*") -AND ($_.publisher -like "*$AppVendor*")}
Foreach ($64BitApp in $64BitApps){
	[version]$InstalledVersion = $64BitApp.DisplayVersion
	If (($InstalledVersion -ge $InstallerVersion) -AND ($appUpdateCheck -eq 1)){
		Write-Host "Installed"
    }
	Else{
	}
}