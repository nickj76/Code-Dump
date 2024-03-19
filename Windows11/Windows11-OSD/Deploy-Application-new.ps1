<#
.SYNOPSIS

PSApppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION

- The script is provided as a template to perform an install or uninstall of an application(s).
- The script either performs an "Install" deployment type or an "Uninstall" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.

PSApppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2023 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham and Muhammad Mashwani).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.PARAMETER DeploymentType

The type of deployment to perform. Default is: Install.

.PARAMETER DeployMode

Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.

.PARAMETER AllowRebootPassThru

Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode

Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

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

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
- 69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
- 70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1

.LINK

https://psappdeploytoolkit.com
#>


[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [String]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [String]$DeployMode = 'Interactive',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false,
    [Parameter(ParameterSetName = 'Default')]
    [ValidateSet(
        'Windows 11 23H2 x64',
        'Windows 11 23H2 ARM64',    
        'Windows 11 22H2 x64',
        'Windows 11 21H2 x64',
        'Windows 10 22H2 x64',
        'Windows 10 22H2 ARM64')]
    [System.String]
    $OSName = 'Windows 11 23H2 x64',

    [switch]
    $Silent,

    [switch]
    $SkipDriverPack,

    [switch]
    $NoReboot,

    [switch]
    $DownloadOnly,

    [switch]
    $DiagnosticPrompt
)

Try {
    ## Set the script execution policy for this process
    Try {
        Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop'
    }
    Catch {
    }

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [String]$appVendor = 'OSDCloud'
    [String]$appName = 'Upgrade to Windows 11'
    [String]$appVersion = '23H2'
    [String]$appArch = 'x64'
    [String]$appLang = 'EN'
    [String]$appRevision = '01'
    [String]$appScriptVersion = '1.0.0'
    [String]$appScriptDate = '29/02/2024'
    [String]$appScriptAuthor = 'Nick Jenkins'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [String]$installName = ''
    [String]$installTitle = ''

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [Int32]$mainExitCode = 0

    ## Variables: Script
    [String]$deployAppScriptFriendlyName = 'Deploy Application'
    [Version]$deployAppScriptVersion = [Version]'3.9.3'
    [String]$deployAppScriptDate = '02/05/2023'
    [Hashtable]$deployAppScriptParameters = $PsBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') {
        $InvocationInfo = $HostInvocation
    }
    Else {
        $InvocationInfo = $MyInvocation
    }
    [String]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [String]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) {
            Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]."
        }
        If ($DisableLogging) {
            . $moduleAppDeployToolkitMain -DisableLogging
        }
        Else {
            . $moduleAppDeployToolkitMain
        }
    }
    Catch {
        If ($mainExitCode -eq 0) {
            [Int32]$mainExitCode = 60008
        }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') {
            $script:ExitCode = $mainExitCode; Exit
        }
        Else {
            Exit $mainExitCode
        }
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
        [String]$installPhase = 'Pre-Installation'

        ## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
        # Show-InstallationWelcome -CloseApps 'iexplore' -AllowDefer -DeferTimes 3 -CheckDiskSpace -PersistPrompt
        # Show-InstallationWelcome -AllowDefer -DeferTimes 3 -CheckDiskSpace -PersistPrompt

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Installation tasks here>
        ## 

        #region Admin Elevation
        $whoiam = [system.security.principal.windowsidentity]::getcurrent().name
        $isElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        if ($isElevated) {
            Write-Log "[+] Running as $whoiam and IS Admin Elevated"
        }
        else {
            Write-Warning "[-] Running as $whoiam and is NOT Admin Elevated"
            Break
        }

        #============================================================================
        # Trust Powershell Gallery and install OSD modules
        #============================================================================
        # Trust PowerShell Gallery
        If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
            Install-PackageProvider -Name "NuGet" -MinimumVersion 2.8.5.208 -Force
            Set-PSRepository -Name "PSGallery" -InstallationPolicy "Trusted"
        }

        #Install or update OSD module
        $Installed = Get-Module -Name "OSD" -ListAvailable | `
            Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true } | `
            Select-Object -First 1
        $Published = Find-Module -Name "OSD"
            If ($Null -eq $Installed) {
                Install-Module -Name "OSD"
            }
            ElseIf ([System.Version]$Published.Version -gt [System.Version]$Installed.Version) {
                Update-Module -Name "OSD"
            }
        
        #Import OSD Module
            Import-Module OSD 
            Import-Module BitsTransfer

        #============================================================================
        #region Functions
        #============================================================================
        Function Get-TPMVer {
        $Manufacturer = (Get-WmiObject -Class:Win32_ComputerSystem).Manufacturer
        if ($Manufacturer -match "HP")
            {
            if ($((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).SpecVersion) -match "1.2")
                {
                $versionInfo = (Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).ManufacturerVersionInfo
                $verMaj      = [Convert]::ToInt32($versionInfo[0..1] -join '', 16)
                $verMin      = [Convert]::ToInt32($versionInfo[2..3] -join '', 16)
                $verBuild    = [Convert]::ToInt32($versionInfo[4..6] -join '', 16)
                $verRevision = 0
                [version]$ver = "$verMaj`.$verMin`.$verBuild`.$verRevision"
                Write-Output "TPM Verion: $ver | Spec: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).SpecVersion)"
                }
            else {Write-Output "TPM Verion: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).ManufacturerVersion) | Spec: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).SpecVersion)"}
            }

        else
            {
            if ($((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).SpecVersion) -match "1.2")
                {
                Write-Output "TPM Verion: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).ManufacturerVersion) | Spec: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).SpecVersion)"
                }
            else {Write-Output "TPM Verion: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).ManufacturerVersion) | Spec: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).SpecVersion)"}
            }
        }

        #endregion Functions

        #============================================================================
        #region Device Info
        #============================================================================
        Write-Log "========================================================================="
        Write-Log "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Starting Invoke-OSDCloudIPU"
        Write-Log "Looking of Details about this device...."

        $BIOSInfo = Get-WmiObject -Class 'Win32_Bios'

        # Get the current BIOS release date and format it to datetime
        $CurrentBIOSDate = [System.Management.ManagementDateTimeConverter]::ToDatetime($BIOSInfo.ReleaseDate).ToUniversalTime()

        $Manufacturer = (Get-WmiObject -Class:Win32_ComputerSystem).Manufacturer
        $ManufacturerBaseBoard = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Manufacturer
        $ComputerModel = (Get-WmiObject -Class:Win32_ComputerSystem).Model
        if ($ManufacturerBaseBoard -eq "Intel Corporation")
            {
            $ComputerModel = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product
            }
        $HPProdCode = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product
        $Serial = (Get-WmiObject -class:win32_bios).SerialNumber
        $cpuDetails = @(Get-WmiObject -Class Win32_Processor)[0]

        Write-Output "Computer Name: $env:computername"
        $CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        $WindowsRelease = $CurrentOSInfo.GetValue('ReleaseId')
        if ($WindowsRelease -eq "2009"){$WindowsRelease = $CurrentOSInfo.GetValue('DisplayVersion')}
        $Build = $($CurrentOSInfo.GetValue('CurrentBuild'))
        $BuildUBR_CurrentOS = $Build +"."+$($CurrentOSInfo.GetValue('UBR'))
        if ($Build -le 19045){$WinVer = "10"}
        else {$WinVer = "11"}
        Write-Output "Windows $WinVer $WindowsRelease | $BuildUBR_CurrentOS"
        Write-Output "Architecture ('env:PROCESSOR_ARCHITECTURE'): $env:PROCESSOR_ARCHITECTURE "
        Write-Output "Architecture (Get-NativeMatchineImage): $((Get-NativeMatchineImage).NativeMachine)"
        Write-Output "Computer Model: $ComputerModel"
        Write-Output "Serial: $Serial"
        if ($Manufacturer -like "H*"){Write-Output "Computer Product Code: $HPProdCode"}
        Write-Output $cpuDetails.Name
        Write-Output "Current BIOS Level: $($BIOSInfo.SMBIOSBIOSVersion) From Date: $CurrentBIOSDate"
        Get-TPMVer
        $TimeUTC = [System.DateTime]::UtcNow
        $TimeCLT = get-date
        Write-Output "Current Client Time: $TimeCLT"
        Write-Output "Current Client UTC: $TimeUTC"
        Write-Output "Time Zone: $(Get-TimeZone)"
        $Locale = Get-WinSystemLocale
        if ($Locale -ne "en-US"){Write-Output "WinSystemLocale: $locale"}
        $FreeSpace = (Get-CimInstance win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace/1GB -as [int]
        $DiskSize = (Get-CimInstance win32_LogicalDisk -Filter "DeviceID='C:'").Size/1GB -as [int]
        Write-Output "C:\ Drive Size: $DiskSize, Freespace: $FreeSpace"

        if ($Build -le 19045){
            $Win11 = Get-Win11Readiness
            if ($Win11.Return -eq "CAPABLE"){
                Write-Log "Device is Windows 11 CAPABLE"
            }
            else {
                Write-Log "Device is !NOT! Windows 11 CAPABLE"
                if ($Build -eq 19045){
                    Write-Log "This Device is already at the latest supported Version of Windows for this Hardware"
                }
                elseif ($Build -lt 19045){
                    Write-Log "But.. You can upgrade it to Windows 10 22H2"
                }
            }
        }

        #$OSVersion = "Windows $($OSName.split(" ")[1])"
        #$OSReleaseID = $OSName.split(" ")[2]
        #$Product = (Get-MyComputerProduct)

        $DriverPack = Get-OSDCloudDriverPack # -Product $Product -OSVersion $OSVersion -OSReleaseID $OSReleaseID
        if ($DriverPack){
            Write-Log "Recommended Driverpack for upgrade: $($DriverPack.Name)"
            if ($SkipDriverPack){
                Write-Log "Skipping Download and Integration [-SkipDriverPack]"
            }
        }

        #endregion Device Info

        #============================================================================
        #region Current Activiation
        #============================================================================

        if (!($OSEdition)){
            $OSEdition = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name "EditionID"
        }
        if (!($OSLanguage)){
            $OSLanguage = (Get-WinSystemLocale).Name
        }
        if (!($OSActivation)){
            $OSActivation = (Get-CimInstance SoftwareLicensingProduct -Filter "Name like 'Windows%'" | Where-Object { $_.PartialProductKey }).ProductKeyChannel
        }
        if ($OSActivation -match "OEM"){
            $OSActivation = "Retail"
        }
        $OSArch = $env:PROCESSOR_ARCHITECTURE   
        if ($OSArch -eq "AMD64"){$OSArch = 'x64'}
        #endregion Current Activiation

        if ($OSArch -eq "ARM64"){
            #=================================================
            #	OSEditionId and OSActivation ARM64
            #=================================================
            if (($OSEdition -eq 'Home') -or ($OSEdition -eq 'Core')) {
                $OSEditionId = 'Core'
                $OSActivation = 'Retail'
                $OSImageIndex = 4
            }
            if ($OSEdition -eq 'Home Single Language') {
                $OSEditionId = 'CoreSingleLanguage'
                $OSActivation = 'Retail'
                $OSImageIndex = 5
            }
            if (($OSEdition -eq 'Pro') -or ($OSEdition -eq 'Professional'))  {
                $OSEditionId = 'Professional'
                if ($OSActivation -eq 'Retail') {$OSImageIndex = 6}
                if ($OSActivation -eq 'Volume') {$OSImageIndex = 8}
            }
        }
        else {
            #=================================================
            #	OSEditionId and OSActivation x64 (AMD64)
            #=================================================
            if (($OSEdition -eq 'Home') -or ($OSEdition -eq 'Core')) {
                $OSEditionId = 'Core'
                $OSActivation = 'Retail'
                $OSImageIndex = 4
            }
            if (($OSEdition -eq 'Home N') -or ($OSEdition -eq 'CoreN')) {
                $OSEditionId = 'CoreN'
                $OSActivation = 'Retail'
                $OSImageIndex = 5
            }
            if ($OSEdition -eq 'Home Single Language') {
                $OSEditionId = 'CoreSingleLanguage'
                $OSActivation = 'Retail'
                $OSImageIndex = 6
            }
            if ($OSEdition -eq 'Enterprise') {
                $OSEditionId = 'Enterprise'
                $OSActivation = 'Volume'
                $OSImageIndex = 6
            }
            if (($OSEdition -eq 'Enterprise N') -or ($OSEdition -eq 'EnterpriseN')) {
                $OSEditionId = 'EnterpriseN'
                $OSActivation = 'Volume'
                $OSImageIndex = 7
            }
            if ($OSEdition -eq 'Education') {
                $OSEditionId = 'Education'
                if ($OSActivation -eq 'Retail') {$OSImageIndex = 7}
                if ($OSActivation -match 'Volume*') {$OSImageIndex = 4}
            }
            if (($OSEdition -eq 'Education N') -or ($OSEdition -eq 'EducationN')) {
                $OSEditionId = 'EducationN'
                if ($OSActivation -eq 'Retail') {$OSImageIndex = 8}
                if ($OSActivation -Match 'Volume*') {$OSImageIndex = 5}
            }
            if (($OSEdition -eq 'Pro') -or ($OSEdition -eq 'Professional'))  {
                $OSEditionId = 'Professional'
                if ($OSActivation -eq 'Retail') {$OSImageIndex = 9}
                if ($OSActivation -Match 'Volume*') {$OSImageIndex = 8}
            }
            if (($OSEdition -eq 'Pro N') -or ($OSEdition -eq 'ProfessionalN')) {
                $OSEditionId = 'ProfessionalN'
                if ($OSActivation -eq 'Retail') {$OSImageIndex = 10}
                if ($OSActivation -Match 'Volume*') {$OSImageIndex = 9}
            }
        }
        Write-Log "========================================================================="
        Write-Log "These are set automatically based on your current OS"
        Write-Log "OSEditionId: " 
        Write-Log $OSEditionId
        Write-Log "OSImageIndex: " 
        Write-Log $OSImageIndex
        Write-Log "OSLanguage: "
        Write-Log $OSLanguage
        Write-Log "OSActivation: "
        Write-Log $OSActivation
        Write-Log "OSArch: "
        Write-Log $OSArch

        Write-Log "========================================================================="
        Write-Log "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Starting Feature Update lookup and Download"

        #============================================================================
        #region Detect & Download ESD File
        #============================================================================

        $ScratchLocation = 'c:\OSDCloud\IPU'
        $OSMediaLocation = 'c:\OSDCloud\OS'
        $MediaLocation = "$ScratchLocation\Media"
        if (!(Test-Path -Path $OSMediaLocation)){New-Item -Path $OSMediaLocation -ItemType Directory -Force | Out-Null}
        if (!(Test-Path -Path $ScratchLocation)){New-Item -Path $ScratchLocation -ItemType Directory -Force | Out-Null}
        if (Test-Path -Path $MediaLocation){Remove-Item -Path $MediaLocation -Force -Recurse}
        New-Item -Path $MediaLocation -ItemType Directory -Force | Out-Null

        # Check $OSActivaation variable if it contains Volume:GVLK then change it to Volume.
        if($OSActivation -match "Volume*" ) 
        {
        $OSActivation = "Volume"
        }
        elseif ($OSActivation -match "Retail*")
        {
        $OSActivation = "Retail"
        } 

        $ESD = Get-FeatureUpdate -OSName $OSName -OSActivation $OSActivation -OSLanguage $OSLanguage -OSArchitecture $OSArch
        if (!($ESD)){
            Write-Log "Unable to Determine proper ESD Upgrade File"
            throw "Unable to Determine proper ESD Upgrade File"
        }
        Write-Log "Name: " 
        Write-Log $ESD.Name
        Write-Log "Architecture: " 
        Write-Log $ESD.Architecture
        Write-Log "Activation: " 
        Write-Log $ESD.Activation
        Write-Log "Build: " 
        Write-Log $ESD.Build    
        Write-Log "FileName: " 
        Write-Log $ESD.FileName   
        Write-Log "Url: " 
        Write-Log $ESD.Url   
        Write-Log "========================================================================="
        Write-Log "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Getting Content for Upgrade Media"   

        #Build Media Paths
        $SubFolderName = "$($ESD.Version) $($ESD.ReleaseId)"
        $ImageFolderPath = "$OSMediaLocation\$SubFolderName"
        if (!(Test-Path -Path $ImageFolderPath)){New-Item -Path $ImageFolderPath -ItemType Directory -Force | Out-Null}
        $ImagePath = "$ImageFolderPath\$($ESD.FileName)"
        $ImageDownloadRequired = $true

        #Check Flash Drive for Media
        $OSDCloudUSB = Get-Volume.usb | Where-Object {($_.FileSystemLabel -match 'OSDCloud') -or ($_.FileSystemLabel -match 'BHIMAGE')} | Select-Object -First 1
        if ($OSDCloudUSB){
            $USBImagePath = "$($OSDCloudUSB.DriveLetter):\OSDCloud\OS\$SubFolderName\$($ESD.FileName)"
            if ((Test-Path -path $USBImagePath) -and (!(Test-Path -path $ImagePath))){
                Write-Log "Found media on OSDCloudUSB - Copying Local"
                Copy-Item -Path $USBImagePath -Destination $ImagePath
            }
        }

        #Test for Media
        if (Test-path -path $ImagePath){
            Write-Log "Found previously downloaded media, getting SHA1 Hash"
            $SHA1Hash = Get-FileHash $ImagePath -Algorithm SHA1
            if ($SHA1Hash.Hash -eq $esd.SHA1){
                Write-Log "SHA1 Match on $ImagePath, skipping Download"
                $ImageDownloadRequired = $false
            }
            else {
                Write-Log "SHA1 Match Failed on $ImagePath, removing content"
            }
            
        }
        if ($ImageDownloadRequired -eq $true){
            # Save-WebFile -SourceUrl $ESD.Url -DestinationDirectory $ImageFolderPath -DestinationName $ESD.FileName
            Write-Log "Starting Download to $ImagePath, this takes awhile"
                
            <# This was taking way too long for some files
            #Get ESD Size
            $req = [System.Net.HttpWebRequest]::Create("$($ESD.Url)")
            $res = $req.GetResponse()
            (Invoke-WebRequest $ESD.Url -UseBasicParsing -Method Head).Headers.'Content-Length'
            $ESDSizeMB = $([Math]::Round($res.ContentLength /1000000)) 
            Write-Host "Total Size: $ESDSizeMB MB"
            #>

            #Clear Out any Previous Attempts
            $ExistingBitsJob = Get-BitsTransfer -Name "$($ESD.FileName)" -AllUsers -ErrorAction SilentlyContinue
            If ($ExistingBitsJob) {
                Remove-BitsTransfer -BitsJob $ExistingBitsJob
            }

            if ((Get-Service -name BITS).Status -ne "Running"){
                Write-Log "BITS Service is not Running, which is required to download ESD File, attempting to Start"
                $StartBITS = Start-Service -Name BITS -PassThru
                Start-Sleep -Seconds 2
                if ($StartBITS.Status -ne "Running"){

                }
            }
            #Start Download using BITS
            Write-Log "Start-BitsTransfer -Source $($ESD.Url) -Destination $ImageFolderPath -DisplayName $($ESD.FileName) -Description 'Windows Media Download' -RetryInterval 60"
            $BitsJob = Start-BitsTransfer -Source $ESD.Url -Destination $ImageFolderPath -DisplayName "$($ESD.FileName)" -Description "Windows Media Download" -RetryInterval 60
            If ($BitsJob.JobState -eq "Error"){
                Write-Log "BITS tranfer failed: $($BitsJob.ErrorDescription)"
            }

        }

#endregion Detect & Download ESD File

        #============================================================================
        #region Extract of ESD file to create Setup Content
        #============================================================================


        #Grab ESD File and create bootable ISO
        if ((!(Test-Path -Path $ImagePath)) -or (!(Test-Path -Path $MediaLocation))){
            if (!(Test-Path -Path $ImagePath)){
                Write-Log "Missing $ImagePath, double check download process"
                throw "Failed to find $ImagePath, double check download process"
            }
            if (!(Test-Path -Path $MediaLocation)){
                Write-Log "Missing $MediaLocation, double check folder exist"
                throw "Faield to find $MediaLocation, double check folder exist"
            }
        }
        if ((Test-Path -Path $ImagePath) -and (Test-Path -Path $MediaLocation)){
            Write-Log "========================================================================="
            Write-Log "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Starting Extract of ESD file to create Setup Content"
            $ApplyPath = $MediaLocation
            Write-Log "Expanding $ImagePath Index 1 to $ApplyPath"
            $Expand = Expand-WindowsImage -ImagePath $ImagePath -Index 1 -ApplyPath $ApplyPath
            ##Export-WindowsImage -SourceImagePath $ImagePath -SourceIndex 2 -DestinationImagePath "$ApplyPath\Sources\boot.wim" -CompressionType max -CheckIntegrity
            ##Export-WindowsImage -SourceImagePath $ImagePath -SourceIndex 3 -DestinationImagePath "$ApplyPath\Sources\boot.wim" -CompressionType max -CheckIntegrity -Setbootable
            Write-Log "Expanding $ImagePath Index $OSImageIndex to $ApplyPath\Sources\install.wim"
            $Expand = Export-WindowsImage -SourceImagePath $ImagePath -SourceIndex $OSImageIndex -DestinationImagePath "$ApplyPath\Sources\install.wim" -CheckIntegrity
            ##Export-WindowsImage -SourceImagePath $ImagePath -SourceIndex 5 -DestinationImagePath "$ApplyPath\Sources\install.wim" -CompressionType max -CheckIntegrity
            $null = $Expand
        }

        #endregion Extract of ESD file to create Setup Content

        if (!(Test-Path -Path "$MediaLocation\Setup.exe")){
            Write-Log "Setup.exe not found, something went wrong"
            throw
        }
        if (!(Test-Path -Path "$MediaLocation\sources\install.wim")){
            Write-Log "install.wim not found, something went wrong"
            throw
        }


        if (($DriverPack) -and (!($SkipDriverPack))){
            Write-Log "========================================================================="
            Write-Log "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Getting Driver Pack for IPU Integration"           
            $DriverPackDownloadRequired = $true
            if (!(Test-Path -Path "C:\Drivers")){New-Item -Path "C:\Drivers" -ItemType Directory -Force | Out-Null}
            $DriverPackPath = "C:\Drivers\$($DriverPack.FileName)"
            if (Test-path -path $DriverPackPath){
                Write-Log "Found previously downloaded DriverPack File, getting MD5 Hash"
                $MD5Hash = Get-FileHash $DriverPackPath -Algorithm MD5
                if ($MD5Hash.Hash -eq $DriverPack.HashMD5){
                    Write-Log "MD5 Match on $DriverPackPath, skipping Download"
                    $DriverPackDownloadRequired = $false
                }
                else {
                    Write-Log "MD5 Match Failed on $DriverPackPath, removing content"
                }
            }
            
            IF ($DriverPackDownloadRequired -eq $true){
                Write-Log "Starting Download to $DriverPackPath, this takes awhile"
                <#
                #Get DrivePack Size
                $req = [System.Net.HttpWebRequest]::Create("$($DriverPack.Url)")
                $res = $req.GetResponse()
                (Invoke-WebRequest $ESD.Url -UseBasicParsing -Method Head).Headers.'Content-Length'
                $SizeMB = $([Math]::Round($res.ContentLength /1000000)) 
                Write-Host "Total Size: $SizeMB MB"
                #>

                #Clear Out any Previous Attempts
                $ExistingBitsJob = Get-BitsTransfer -Name "$($DriverPack.FileName)" -AllUsers -ErrorAction SilentlyContinue
                If ($ExistingBitsJob) {
                    Remove-BitsTransfer -BitsJob $ExistingBitsJob
                }

                #Start Download using BITS
                $BitsJob = Start-BitsTransfer -Source $DriverPack.Url -Destination $DriverPackPath -DisplayName "$($DriverPack.FileName)" -Description "Driver Pack Download" -RetryInterval 60
                If ($BitsJob.JobState -eq "Error"){
                    Write-Log "BITS tranfer failed: $($BitsJob.ErrorDescription)"
                }
            }
            #Expand Driver Pack
            if (Test-path -path $DriverPackPath){
                Write-Log "========================================================================="
                Write-Log "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Expanding DriverPack for Upgrade Media"   
                Expand-StagedDriverPack
                $DriverPackFile = Get-ChildItem -Path $DriverPackPath -Filter $DriverPack.FileName
                $DriverPackExpandPath = Join-Path $DriverPackFile.Directory $DriverPackFile.BaseName
                if (Test-Path -Path $DriverPackExpandPath){

                }
            }
        }
            Write-Log "========================================================================="
            Write-Log "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Triggering Windows Upgrade Setup"   

            if ($DownloadOnly){
            Write-Log "Download Complete, exiting script before install based on 'DownloadOnly' switch"
        }
     
        #### (Pre-Install) Delete Scheduled Task

        $DELTaskName = "OSDWin11Upgrade"

        # Check if the task exists
        $DELTaskExists = Get-ScheduledTask -TaskName $DELTaskName -ErrorAction SilentlyContinue

        if ($DELTaskExists) {
            # Delete the task
            Unregister-ScheduledTask -TaskName $DELTaskName -Confirm:$false
            Write-Output "(Pre-Install) Task '$DELTaskName' has been deleted."
        } else {
            Write-Output "(Pre-Install) Task '$DELTaskName' does not exist.  Moving on to Installation"
        }

        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        ## Handle Zero-Config MSI Installations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) {
                $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ }
            }
        }

        ## <Perform Installation tasks here>
        #### CREATE SCHEDULED TASK

        #########################################

        if ($DriverPack){
            if ($DriverPackPath){
                if (Test-path -path $DriverPackPath){
                    $driverarg = "/InstallDrivers $DriverPackExpandPath"
                }
            }
        }
        else {
            $DriverArg = ""
        }

        $STExecutable = "$MediaLocation\Setup.exe"
        $STArguments = "/Auto Upgrade /EULA accept $driverarg /NoReboot"
        $STTaskName = "OSDWin11Upgrade"
        $STTriggerTime = (Get-Date).AddSeconds(15)
        $STPriority = 4

        Write-Log -Message "Creating scheduled task $STTaskName to run `"$STExecutable $STArguments`""

        $STTrigger = New-ScheduledTaskTrigger -Once -At $STTriggerTime
        $STSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable -Priority $STPriority -RunOnlyIfNetworkAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

        # Create a new scheduled task action
        $STAction = New-ScheduledTaskAction -Execute $STExecutable -Argument $STArguments -WorkingDirectory (Split-Path $STExecutable)

        # Create a new scheduled task principal for the SYSTEM account
        $STPrincipal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

        # Create and register the new scheduled task
        $STTask = New-ScheduledTask -Action $STAction -Trigger $STTrigger -Settings $STSettings -Principal $STPrincipal
        Register-ScheduledTask -TaskName $STTaskName -InputObject $STTask


        #### KICK OFF SCHEDULED TASK
        Start-Sleep 10
        Start-ScheduledTask -TaskName "OSDWin11Upgrade"

        #### MONITOR SCHEDULED TASK
        $STTaskName = "OSDWin11Upgrade"

        # Loop until the task is no longer running
        while ((Get-ScheduledTask -TaskName $STTaskName).State -eq "Running")
        {
            # Get task information
            $taskInfo = Get-ScheduledTaskInfo -TaskName $STTaskName

            # Verify if the task is being run by SYSTEM
            if ((Get-ScheduledTask -TaskName $STTaskName).Principal.UserId -eq "SYSTEM")
            {
                # Write to the output
                Write-Output "$STTaskName is still running as SYSTEM"
            }
            else
            {
                Write-Output "$STTaskName is still running, but not as SYSTEM"
            }

            # Wait for 10 seconds before checking again
            Start-Sleep -Seconds 10
        }

        Write-Output "$STTaskName has finished running"

        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>
        #### (Post-Install) Delete Scheduled Task>

       $DELTaskName = "OSDWin11Upgrade"

        # Check if the task exists
        $DELTaskExists = Get-ScheduledTask -TaskName $DELTaskName -ErrorAction SilentlyContinue

        if ($DELTaskExists) {
            # Delete the task
            Unregister-ScheduledTask -TaskName $DELTaskName -Confirm:$false
            Write-Output "(Post-Install) Task '$DELTaskName' has been deleted."
        } else {
            Write-Output "(Post-Install) Task '$DELTaskName' does not exist."
        }

        # Create OSDCloud Clean up task.
        $ST1Executable = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
        $ST1Arguments = "Remove-Item -Path `"C:\OSDCloud`" -Recurse"
        $ST1TaskName = "DeleteOSDCloudDownloads"
        $ST1TriggerTime = (Get-Date).AddDays(1)
        $ST1Priority = 4

        Write-Log -Message "Creating scheduled task $ST1TaskName to run `"$ST1Executable $ST1Arguments`""

        $ST1Trigger = New-ScheduledTaskTrigger -Once -At $ST1TriggerTime
        $ST1Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -Priority $ST1Priority -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

        # Create a new scheduled task action.
        $ST1Action = New-ScheduledTaskAction -Execute $ST1Executable -Argument $ST1Arguments -WorkingDirectory (Split-Path $ST1Executable)

        # Create a new scheduled task principal for the SYSTEM account
        $ST1Principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

        # Create and register the new scheduled task
        $ST1Task = New-ScheduledTask -Action $ST1Action -Trigger $ST1Trigger -Settings $ST1Settings -Principal $ST1Principal
        Register-ScheduledTask -TaskName $ST1TaskName -InputObject $ST1Task

        # Create intune Detection Method
        Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Intune_Installations' -Name 'Win11-23H2-Upgrade' -Value '"Installed"' -Type String

        ## Display a message at the end of the install
        # Show-DialogBox -Title "Windows 11 Upgrade" -Text "The Windows 11 Upgrade has completed, Please click OK to restart your computer." -Icon "Information"
        Show-InstallationRestartPrompt -Countdownseconds 600 -CountdownNoHideSeconds 60
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Uninstallation tasks here>


        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'

        ## Handle Zero-Config MSI Uninstallations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }

        ## <Perform Uninstallation tasks here>


        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'

        ## <Perform Post-Uninstallation tasks here>


    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [String]$installPhase = 'Pre-Repair'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Repair tasks here>

        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [String]$installPhase = 'Repair'

        ## Handle Zero-Config MSI Repairs
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }
        ## <Perform Repair tasks here>

        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [String]$installPhase = 'Post-Repair'

        ## <Perform Post-Repair tasks here>


    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [Int32]$mainExitCode = 60001
    [String]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
