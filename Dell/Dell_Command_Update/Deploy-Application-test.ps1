<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall','Repair')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Bios','Display','Network','Drivers','All')]
	[string]$UpdateType = 'All',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'Dell'
	[string]$appName = 'Dell Command Update'
	[string]$appRegName = 'Dell Command | Update'
	[string]$appVersion = '4.6.0'
	[string]$appArch = ''
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.14.0'
	[string]$appScriptDate = '17/11/2022'
	[string]$appScriptAuthor = 'Nick Jenkins'
	[string]$appFile = 'Dell-Command-Update-Application_W4HP2_WIN_4.5.0_A00_02.EXE'
	[string]$appUpdateFile = ''
	[string]$appDefaultDeviceCategory = 'audio,video,network,storage,input,chipset,others'
	[string]$appDefaultTypeCategory = 'firmware,driver,application,others,utility'
	[string]$appLicense = ""
	[array]$appIcons = @( )
	[string]$appRuns = "DellCommandUpdate,dcu-cli"
	##*===============================================
	
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''

	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.8.4'
	[string]$deployAppScriptDate = '26/01/2021'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
		Show-InstallationWelcome -CloseApps "$appRuns" -CheckDiskSpace -PersistPrompt

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Installation tasks here>
		
		# Check if running 32bit OS and EXIT if True (This package doesn't support 32bit OS)
		if ($psArchitecture -eq "x86") {
			Show-InstallationPrompt -Message "This APP Package Does Not Include 32bit OS Support... Please Contact The Service Desk About a Computer Upgrade...." -ButtonRightText 'EXIT' -Icon Information -NoWait
			Exit $mainExitCode
		}

		# Check for non Windows 10 (This package doesn't support older OSes)
		if ([int]$envOSVersionMajor -lt 10) {
			Show-InstallationPrompt -Message "Application Is Not Supported On This Version of Windows ( $envOSName [$envOSVersion] )." -ButtonRightText 'EXIT' -Icon Information -NoWait
			Exit $mainExitCode
		}
		
		# Check machine Vendor (This package only works on Dell Machines)
		$Manufacturer = (Get-ComputerInfo).CsManufacturer
		If (!($Manufacturer -like "Dell*")){
			Show-InstallationPrompt -Message "Application Is Not Supported By This Computer Manufacturer ( $Manufacturer )." -ButtonRightText 'EXIT' -Icon Information -NoWait
			Exit $mainExitCode
		}

		# Check the Dell Model (only OptiPlex, Latitude, Venue, XPS, and Precision are supported)
		$Model = (Get-ComputerInfo).CsModel
		If (!(($Model -like "OptiPlex*") -OR ($Model -like "Latitude*") -OR ($Model -like "Venue*") -OR ($Model -like "XPS*") -OR ($Model -like "Precision*"))){
			Show-InstallationPrompt -Message "Application Is Not Supported On This Dell Model ( $Model )." -ButtonRightText 'EXIT' -Icon Information -NoWait
			Exit $mainExitCode
		}

		# Check for laptop 
		If ((Test-Battery -PassThru).IsLaptop){
			Show-InstallationPrompt -Message "Laptop System Detected... Please Ensure Power Adapter is Connected..." -ButtonRightText 'OK' -Icon Information
		}
		
		Show-InstallationProgress "Searching For Old $appName Installation....  Please Wait..."
		
		#<Pre-Installation Code here>
		
		# Refresh the desktop 
		Update-Desktop -ContinueOnError $true
		
		Show-InstallationProgress "Moving to Installation Phase....  Please Wait..."

		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}

		## <Perform Installation tasks here>
		
		# Verify that the dcu-cli exists ( Exit code if missing )
		If (!(Test-Path "$envProgramFiles\$appVendor\CommandUpdate\dcu-cli.exe")){
			Show-InstallationPrompt -Message "ERROR: $appRegName not Detected After Installation... Please Restart Computer and Relaunch..." -ButtonRightText 'EXIT' -Icon Information -NoWait
			Exit $mainExitCode
		}
		
		Show-InstallationProgress "Configuring $appRegName Default Settings... Please Wait..." 

		# Set some basic settings under dcu-cli (I.e. BIOS Password , auto Bitlocker suspend, default Update Types, etc.)
		start-process -FilePath "$envProgramFiles\$appVendor\CommandUpdate\dcu-cli.exe" -ArgumentList "/configure -silent -biosPassword=`"SecretPassword`" -autoSuspendBitLocker=enable -userConsent=disable" -Wait -WindowStyle Hidden
		start-process -FilePath "$envProgramFiles\$appVendor\CommandUpdate\dcu-cli.exe" -ArgumentList "/configure -silent -scheduleManual -advancedDriverRestore=disable" -Wait -WindowStyle Hidden
		
		#Reset to the Default Update Type Settings
		start-process -FilePath "$envProgramFiles\$appVendor\CommandUpdate\dcu-cli.exe" -ArgumentList "/configure -silent -updateType=`"$appDefaultTypeCategory`"" -Wait -WindowStyle Hidden
		
		#Reset to the Default Update Device Settings
		start-process -FilePath "$envProgramFiles\$appVendor\CommandUpdate\dcu-cli.exe" -ArgumentList "/configure -silent -updateDeviceCategory=`"$appDefaultDeviceCategory`"" -Wait -WindowStyle Hidden

		#Run a Report (Removing due to issue with latest DCU /scan not running silent)
		#Show-InstallationProgress "Running $appRegName Update Report... Please Wait..." 
		#start-process -FilePath "$envProgramFiles\$appVendor\CommandUpdate\dcu-cli.exe" -ArgumentList "/scan -silent -report=`"$envSystemDrive\temp\$appVendor Update`"" -Wait -WindowStyle Hidden

		#Kill DellCommandUpdate if it was started (Latest DCU has an issue )
		Get-Process -Name "DellCommandUpdate" | Stop-Process -Force

		# Refresh the desktop 
		Update-Desktop -ContinueOnError $true

		Write-Log -Message "Using Update Type: $UpdateType" 

		# Note: This swtich is used for telling DCU-CLI to only install a specific type (Used with MECM deployments) (Default is All)
		switch ($UpdateType)
		{
			"All"
			{
				# Set the Update Type (Reset the update Type filter back to everything... )
				start-process -FilePath "$envProgramFiles\$appVendor\CommandUpdate\dcu-cli.exe" -ArgumentList "/configure -silent -updateType=`"$appDefaultTypeCategory`"" -Wait -WindowStyle Hidden

				# Install all available updates ( Includes all categories ) 
				show-installationprogress -statusmessage "Installing Avaliable Driver Updates ( $UpdateType )... WARNING: Screen May Flicker During Install..."
				start-process -FilePath "$envProgramFiles\$appVendor\CommandUpdate\dcu-cli.exe" -ArgumentList "/applyUpdates -silent -outputLog=`"$envSystemDrive\temp\$appVendor Update\dell_update.log`" -reboot=disable" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
			}
			"Drivers"
			{
				# Set the Update Type (Set the Update Type to driver,application,others,utility ... Basically excluding the BIOS and Firmware updates)
				start-process -FilePath "$envProgramFiles\$appVendor\CommandUpdate\dcu-cli.exe" -ArgumentList "/configure -silent -updateType=driver,application,others,utility" -Wait -WindowStyle Hidden

				# Install driver available updates ( Includes only driver update type ) 
				show-installationprogress -statusmessage "Installing Avaliable Updates ( $UpdateType )... WARNING: Screen May Flicker During Install..."
				start-process -FilePath "$envProgramFiles\$appVendor\CommandUpdate\dcu-cli.exe" -ArgumentList "/applyUpdates -silent -outputLog=`"$envSystemDrive\temp\$appVendor Update\dell_update.log`" -reboot=disable" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
			}	
			"Bios"
			{
				# Set the Update Type (Set the Update Type to BIOS and Firmware only...)
				start-process -FilePath "$envProgramFiles\$appVendor\CommandUpdate\dcu-cli.exe" -ArgumentList "/configure -silent -updateType=bios,firmware" -Wait -WindowStyle Hidden

				# Install driver available updates ( Includes only driver update type ) 
				show-installationprogress -statusmessage "Installing Avaliable Updates ( $UpdateType )..."
				start-process -FilePath "$envProgramFiles\$appVendor\CommandUpdate\dcu-cli.exe" -ArgumentList "/applyUpdates -silent -outputLog=`"$envSystemDrive\temp\$appVendor Update\dell_update.log`" -reboot=disable" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
			}
			"Network"
			{
				# Set the Update Type (Set the Update Type to driver and set device category to network only ...)
				start-process -FilePath "$envProgramFiles\$appVendor\CommandUpdate\dcu-cli.exe" -ArgumentList "/configure -silent -updateType=driver" -Wait -WindowStyle Hidden
				start-process -FilePath "$envProgramFiles\$appVendor\CommandUpdate\dcu-cli.exe" -ArgumentList "/configure -silent -updateDeviceCategory=network" -Wait -WindowStyle Hidden

				# Install driver available updates ( Includes only driver update type ) 
				show-installationprogress -statusmessage "Installing Avaliable Updates ( $UpdateType )..."
				start-process -FilePath "$envProgramFiles\$appVendor\CommandUpdate\dcu-cli.exe" -ArgumentList "/applyUpdates -silent -outputLog=`"$envSystemDrive\temp\$appVendor Update\dell_update.log`" -reboot=disable" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
			}
			"Display"
			{
				# Set the Update Type (Set the Update Type to driver and set device category to display only ...)
				start-process -FilePath "$envProgramFiles\$appVendor\CommandUpdate\dcu-cli.exe" -ArgumentList "/configure -silent -updateType=driver" -Wait -WindowStyle Hidden
				start-process -FilePath "$envProgramFiles\$appVendor\CommandUpdate\dcu-cli.exe" -ArgumentList "/configure -silent -updateDeviceCategory=video" -Wait -WindowStyle Hidden
				
				# Install driver available updates ( Includes only driver update type ) 
				show-installationprogress -statusmessage "Installing Avaliable Updates ( $UpdateType )... WARNING: Screen May Flicker During Install..."
				start-process -FilePath "$envProgramFiles\$appVendor\CommandUpdate\dcu-cli.exe" -ArgumentList "/applyUpdates -silent -outputLog=`"$envSystemDrive\temp\$appVendor Update\dell_update.log`" -reboot=disable" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
			}
		}

		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>
		
		#Use ForEach loop to remove all icons from any User (Public, Users, etc. Desktop) declared in Variable Declaration...
		ForEach ($appIcon in $appIcons)
		{
			$RemoveDesktopShortcuts = Get-ChildItem "$envSystemDrive\Users\*\Desktop\$appIcon.lnk"
			ForEach ($RemoveDesktopShortcut in $RemoveDesktopShortcuts) {
				If ($RemoveDesktopShortcut | Test-Path) {
					Show-InstallationProgress "Removing $appName Icons ($appIcon)... Please Wait..."
					Remove-File -Path "$RemoveDesktopShortcut" -ContinueOnError $true
				}
			}
		}
		
		#<Post-Installation Code here>

		#wait for dcu-cli to finish (If still running)
		Wait-Process -Name dcu-cli -Timeout 30
		
		#Reset to the Default Update Type Settings
		start-process -FilePath "$envProgramFiles\$appVendor\CommandUpdate\dcu-cli.exe" -ArgumentList "/configure -silent -updateType=`"$appDefaultTypeCategory`"" -Wait -WindowStyle Hidden

		#Reset to the Default Update Device Settings
		start-process -FilePath "$envProgramFiles\$appVendor\CommandUpdate\dcu-cli.exe" -ArgumentList "/configure -silent -updateDeviceCategory=`"$appDefaultDeviceCategory`"" -Wait -WindowStyle Hidden

		# Change the Startup Type and stop Dell Management Service
		Set-Service -Name DellClientManagementService -StartupType Manual
		Stop-Service -Name "DellClientManagementService" -Force
		
		# Close any stuck InstallationProgress windows 
		Close-InstallationProgress

		# Refresh the desktop 
		Update-Desktop -ContinueOnError $true

		# Quick check to see if the log found no avaliable updates
		$dateCheck = Get-Date -Format "yyyy-MM-dd"
		
		If (get-content -path "$envSystemDrive\temp\$appVendor Update\dell_update.log" | select-string -pattern "$dateCheck \w{2}:\w{2}:\w{2}] : The program exited with return code: 500"){
			If (-not $useDefaultMsi) { Show-InstallationPrompt -Message "$installTitle Detected System is Already Fully Patched... If you have any Questions Please Contact IT Service Desk." -ButtonRightText 'OK' -Icon Information -NoWait }
		}
		ElseIf (get-content -path "$envSystemDrive\temp\$appVendor Update\dell_update.log" | select-string -pattern "$dateCheck \w{2}:\w{2}:\w{2}] : The program exited with return code: 1"){
			If (-not $useDefaultMsi) { Show-InstallationPrompt -Message "$installTitle Has Updated System Drivers... Please Restart Your Computer to Finish Installation" -ButtonRightText 'OK' -Icon Information -NoWait }
		}
		Else { 
			## Display a message at the end of the install
			If (-not $useDefaultMsi) { Show-InstallationPrompt -Message "$installTitle Has Updated System Drivers... If you have any Questions Please Contact IT Service Desk." -ButtonRightText 'OK' -Icon Information -NoWait }
		}
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		## Show Welcome Message, close app with a 60 second countdown before automatically closing
		Show-InstallationWelcome -CloseApps "$appRuns" -CloseAppsCountdown 60

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Uninstallation tasks here>


		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'

		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}

		## <Perform Uninstallation tasks here>

		#Show-InstallationProgress "Searching For Old $appName Installation....  Please Wait..."
		
		#<Uninstallation Code here>
		
		#Not Including uninstall code 

		# Close any stuck InstallationProgress windows 
		Close-InstallationProgress
		
		# Refresh the desktop 
		Update-Desktop -ContinueOnError $true
		
		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>


	}
	ElseIf ($deploymentType -ieq 'Repair')
	{
		##*===============================================
		##* PRE-REPAIR
		##*===============================================
		[string]$installPhase = 'Pre-Repair'

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Repair tasks here>

		##*===============================================
		##* REPAIR
		##*===============================================
		[string]$installPhase = 'Repair'

		## Handle Zero-Config MSI Repairs
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}
		# <Perform Repair tasks here>

		##*===============================================
		##* POST-REPAIR
		##*===============================================
		[string]$installPhase = 'Post-Repair'

		## <Perform Post-Repair tasks here>


    }
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}
