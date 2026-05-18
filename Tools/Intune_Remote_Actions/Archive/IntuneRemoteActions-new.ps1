<#
.SYNOPSIS
    Intune Remote Actions PowerShell script can perform various management actions on devices that are no longer needed, being repurposed, or missing.
    Supported actions include wiping, retiring, syncing, locking, deleting, restarting, and shutting down devices.
    Script input requires one or multiple Device Name/Host Name, Device Serial Number, or AAD Group names for performing the specified actions as parameters.

.DESCRIPTION
    IntuneRemoteActions.ps1 is a PowerShell script to find Intune Enrolled Device information from Microsoft Endpoint Management and perform specified remote actions.
    The actions include wiping, retiring, syncing, locking (Android, iOS, MacOS Only), deleting, restarting, and shutting down devices.
    Actions can be performed on individual devices or on all devices in specified Azure AD groups.

.EXAMPLE
    .\IntuneRemoteActions.ps1 -DisplayNames 'Device1','Device2' -Wipe
    .\IntuneRemoteActions.ps1 -Serials 'ABC123','XYZ789' -Sync
    .\IntuneRemoteActions.ps1 -AADGroups 'Marketing Devices','Finance Laptops' -Restart

.Notes
    Connect to graph using secret script first before running this script.
#>

param (
    [string[]]$DisplayNames,
    [string[]]$Serials,
    [string[]]$AADGroups,
    [switch]$Wipe,
    [switch]$Retire,
    [switch]$Sync,
    [switch]$Lock,
    [switch]$Delete,
    [switch]$Restart,
    [switch]$Shutdown
)

Function CheckInternet
{
$statuscode = (Invoke-WebRequest -Uri https://adminwebservice.microsoftonline.com/ProvisioningService.svc).statuscode
if ($statuscode -ne 200){
''
''
Write-Host "Operation aborted. Unable to connect to Microsoft Graph, please check your internet connection." -ForegroundColor red -BackgroundColor Black
exit
}
}

Function CheckMSGraph{
''
Write-Host "Checking Microsoft Graph Module..." -ForegroundColor Yellow
                            
    if (Get-Module -ListAvailable | Where-Object {$_.Name -like "Microsoft.Graph"}) 
    {
    Write-Host "Microsoft Graph Module has installed." -ForegroundColor Green
    Import-Module -Name 'Microsoft.Graph.DeviceManagement','Microsoft.Graph.DeviceManagement.Actions','Microsoft.Graph.Groups','Microsoft.Graph.Identity.DirectoryManagement'
    Write-Host "Microsoft Graph Module has imported." -ForegroundColor Cyan
    ''
    ''
    } else
    {
    Write-Host "Microsoft Graph Module is not installed." -ForegroundColor Red
    ''
    Write-Host "Installing Microsoft Graph Module....." -ForegroundColor Yellow
    Install-Module -Name "Microsoft.Graph" -Force
                                
    if (Get-Module -ListAvailable | Where-Object {$_.Name -like "Microsoft.Graph"}) {                                
    Write-Host "Microsoft Graph Module has installed." -ForegroundColor Green
    Import-Module -Name 'Microsoft.Graph.DeviceManagement','Microsoft.Graph.DeviceManagement.Actions','Microsoft.Graph.Groups','Microsoft.Graph.Identity.DirectoryManagement'
    Write-Host "Microsoft Graph Module has imported." -ForegroundColor Cyan
    ''
    ''
    } else
    {
    ''
    ''
    Write-Host "Operation aborted. Microsoft Graph Module was not installed." -ForegroundColor Red
    Exit}
    }

# Write-Host "Connecting to Microsoft Graph PowerShell..." -ForegroundColor Magenta
# Connect to Graph using your personal script 
# Connect-MgGraph -ClientId "App Client ID" -TenantId "Entra ID Tenant ID" -NoWelcome
# Connect to graph using secret script first before running this script

$MgContext= Get-mgContext

Write-Host "User '$($MgContext.Account)' has connected to TenantId '$($MgContext.TenantId)' Microsoft Graph API successfully." -ForegroundColor Green
''
''
}
Clear-Host

'===================================================================================================='
Write-Host '                                       Intune Device Actions                                      ' -ForegroundColor Green
'===================================================================================================='

''                    
Write-Host "                                          IMPORTANT NOTES                                           " -ForegroundColor Red 
Write-Host "===================================================================================================="

Write-Host "Using the remote actions script, you can manage devices in Intune that are no longer needed, being" -ForegroundColor Yellow 
Write-Host "repurposed, or missing. Supported actions include wiping, retiring, syncing, locking (Android, iOS, MacOS Only), deleting," -ForegroundColor Yellow  
Write-Host "restarting, and shutting down devices. Each action has specific implications and should be used" -ForegroundColor Yellow 
Write-Host "with caution." -ForegroundColor Yellow  
''
Write-Host "For more information, kindly visit the below links:" -ForegroundColor Yellow 
Write-Host "https://github.com/UoS-CAVE/Intune_Remote_Actions" -ForegroundColor Yellow 
Write-Host "https://learn.microsoft.com/en-us/graph/api/resources/intune-devices-manageddevice?view=graph-rest-1.0" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/mem/intune/remote-actions/device-management" -ForegroundColor Yellow

"===================================================================================================="
''
CheckInternet
CheckMSGraph

function Get-DevicesFromAADGroup {
    param (
        [string]$GroupName
    )
    
    try {
        Write-Host "Searching for AAD Group '$GroupName'..." -ForegroundColor Cyan
        $group = Get-MgGroup -Filter "displayName eq '$GroupName'" -ErrorAction Stop
        
        if (-not $group) {
            Write-Host "Group '$GroupName' not found in Azure AD." -ForegroundColor Yellow
            return $null
        }
        
        Write-Host "Found AAD Group '$GroupName' with ID: $($group.Id)" -ForegroundColor Green
        Write-Host "Retrieving devices from group..." -ForegroundColor Cyan
        
        # Get devices that are direct members of the group
        $groupMembers = Get-MgGroupMember -GroupId $group.Id -All
        $devices = @()
        
        foreach ($member in $groupMembers) {
            $deviceObj = Get-MgDevice -DeviceId $member.Id -ErrorAction SilentlyContinue
            if ($deviceObj) {
                # Find the corresponding Intune managed device
                $intuneDevice = Get-MgDeviceManagementManagedDevice -Filter "azureADDeviceId eq '$($deviceObj.DeviceId)'"
                if ($intuneDevice) {
                    $devices += $intuneDevice
                }
            }
        }
        
        if ($devices.Count -eq 0) {
            Write-Host "No Intune managed devices found in group '$GroupName'." -ForegroundColor Yellow
            return $null
        }
        
        Write-Host "Found $($devices.Count) devices in group '$GroupName'." -ForegroundColor Green
        return $devices
    }
    catch {
        Write-Host "Error retrieving devices from group '$GroupName': $_" -ForegroundColor Red
        return $null
    }
}

function Perform-RemoteAction {
    param (
        [string]$Identifier,
        [string]$Action,
        [string]$Filter,
        [PSCustomObject]$Device = $null
    )

    if ($Device) {
        $IntuneDevices = @($Device)
    } else {
        Write-Host "Searching Intune Devices with Identifier '$Identifier'..." -ForegroundColor Cyan
        $IntuneDevices = Get-MgDeviceManagementManagedDevice -Filter $Filter
    }
    
    if ($IntuneDevices -and $IntuneDevices.Count -gt 0) {
        foreach ($IntuneDevice in $IntuneDevices) {
            # Fix for line 176 - replacing ternary operator with proper if-else
            $deviceIdentifier = if ($Device) { 
                "$($IntuneDevice.DeviceName) ($($IntuneDevice.SerialNumber))" 
            } else { 
                $Identifier 
            }
            Write-Host "Initiating $Action action for $deviceIdentifier..." -ForegroundColor Cyan
            
            try {
                switch ($Action) {
                    "Wipe" {
                        Clear-MgDeviceManagementManagedDevice -ManagedDeviceId $IntuneDevice.Id
                        Write-Host "Remote wipe initiated for Device '$deviceIdentifier'." -ForegroundColor Green
                    }
                    "Retire" {
                        Invoke-MgRetireDeviceManagementManagedDevice -ManagedDeviceId $IntuneDevice.Id
                        Write-Host "Remote retire initiated for Device '$deviceIdentifier'." -ForegroundColor Green
                    }
                    "Delete" {
                        Remove-MgDeviceManagementManagedDevice -ManagedDeviceId $IntuneDevice.Id -Force
                        Write-Host "Remote delete initiated for Device '$deviceIdentifier'." -ForegroundColor Green
                    }                
                    "Sync" {
                        Sync-MgDeviceManagementManagedDevice -ManagedDeviceId $IntuneDevice.Id
                        Write-Host "Remote sync initiated for Device '$deviceIdentifier'." -ForegroundColor Green
                    }
                    "Lock" {
                        Lock-MgDeviceManagementManagedDeviceRemote -ManagedDeviceId $IntuneDevice.Id
                        Write-Host "Remote lock initiated for Device '$deviceIdentifier'." -ForegroundColor Green
                    }
                    "Restart" {
                        Restart-MgDeviceManagementManagedDeviceNow -ManagedDeviceId $IntuneDevice.Id
                        Write-Host "Remote restart initiated for Device '$deviceIdentifier'." -ForegroundColor Green
                    }
                    "Shutdown" {
                        Invoke-MgDownDeviceManagementManagedDeviceShut -ManagedDeviceId $IntuneDevice.Id
                        Write-Host "Remote shutdown initiated for Device '$deviceIdentifier'." -ForegroundColor Green
                    }
                }
                
                # Log to console instead of UI
                $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                Write-Host "[$timestamp] Device: $deviceIdentifier - Action: $Action - Status: Success" -ForegroundColor Green
            }
            catch {
                Write-Host "Error performing ${Action} on ${deviceIdentifier}: $($_.Exception.Message)" -ForegroundColor Red
                
                # Log error to console
                $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                Write-Host "[$timestamp] Device: $deviceIdentifier - Action: $Action - Status: Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "Device with Identifier '$Identifier' not found in Intune or already removed from Intune." -ForegroundColor Yellow
    }
}

function Perform-ActionOnGroup {
    param (
        [string]$GroupName,
        [string]$Action
    )
    
    $devices = Get-DevicesFromAADGroup -GroupName $GroupName
    
    if ($devices) {
        Write-Host "Performing $Action action on all devices in group '$GroupName'..." -ForegroundColor Cyan
        foreach ($device in $devices) {
            Perform-RemoteAction -Action $Action -Device $device
        }
        Write-Host "Completed $Action action for all available devices in group '$GroupName'." -ForegroundColor Green
    }
}

# Check if any actions are specified
$actionsSpecified = $Wipe -or $Retire -or $Sync -or $Lock -or $Delete -or $Restart -or $Shutdown
if (-not $actionsSpecified) {
    Write-Host "No action specified. Please include at least one action (e.g., -Wipe, -Sync, -Restart)." -ForegroundColor Red
    exit
}

if ($DisplayNames) {
    foreach ($DisplayName in $DisplayNames) {
        if ($Wipe) {
            Perform-RemoteAction -Identifier $DisplayName -Action "Wipe" -Filter "deviceName eq '$DisplayName'"
        }
        if ($Retire) {
            Perform-RemoteAction -Identifier $DisplayName -Action "Retire" -Filter "deviceName eq '$DisplayName'"
        }
        if ($Sync) {
            Perform-RemoteAction -Identifier $DisplayName -Action "Sync" -Filter "deviceName eq '$DisplayName'"
        }
        if ($Lock) {
            Perform-RemoteAction -Identifier $DisplayName -Action "Lock" -Filter "deviceName eq '$DisplayName'"
        }
        if ($Delete) {
            Perform-RemoteAction -Identifier $DisplayName -Action "Delete" -Filter "deviceName eq '$DisplayName'"
        }
        if ($Restart) {
            Perform-RemoteAction -Identifier $DisplayName -Action "Restart" -Filter "deviceName eq '$DisplayName'"
        }
        if ($Shutdown) {
            Perform-RemoteAction -Identifier $DisplayName -Action "Shutdown" -Filter "deviceName eq '$DisplayName'"
        }
    }
} elseif ($Serials) {
    foreach ($Serial in $Serials) {
        if ($Wipe) {
            Perform-RemoteAction -Identifier $Serial -Action "Wipe" -Filter "contains(serialNumber,'$Serial')"
        }
        if ($Retire) {
            Perform-RemoteAction -Identifier $Serial -Action "Retire" -Filter "contains(serialNumber,'$Serial')"
        }
        if ($Sync) {
            Perform-RemoteAction -Identifier $Serial -Action "Sync" -Filter "contains(serialNumber,'$Serial')"
        }
        if ($Lock) {
            Perform-RemoteAction -Identifier $Serial -Action "Lock" -Filter "contains(serialNumber,'$Serial')"
        }
        if ($Delete) {
            Perform-RemoteAction -Identifier $Serial -Action "Delete" -Filter "contains(serialNumber,'$Serial')"
        }
        if ($Restart) {
            Perform-RemoteAction -Identifier $Serial -Action "Restart" -Filter "contains(serialNumber,'$Serial')"
        }
        if ($Shutdown) {
            Perform-RemoteAction -Identifier $Serial -Action "Shutdown" -Filter "contains(serialNumber,'$Serial')"
        }       
    }
} elseif ($AADGroups) {
    foreach ($GroupName in $AADGroups) {
        if ($Wipe) {
            Perform-ActionOnGroup -GroupName $GroupName -Action "Wipe"
        }
        if ($Retire) {
            Perform-ActionOnGroup -GroupName $GroupName -Action "Retire"
        }
        if ($Sync) {
            Perform-ActionOnGroup -GroupName $GroupName -Action "Sync"
        }
        if ($Lock) {
            Perform-ActionOnGroup -GroupName $GroupName -Action "Lock" 
        }
        if ($Delete) {
            Perform-ActionOnGroup -GroupName $GroupName -Action "Delete"
        }
        if ($Restart) {
            Perform-ActionOnGroup -GroupName $GroupName -Action "Restart"
        }
        if ($Shutdown) {
            Perform-ActionOnGroup -GroupName $GroupName -Action "Shutdown"
        }
    }
} else {
    Write-Host "Please specify targets using one of these parameters:" -ForegroundColor Red
    Write-Host "  -DisplayNames: For individual device names" -ForegroundColor Yellow
    Write-Host "  -Serials: For device serial numbers" -ForegroundColor Yellow
    Write-Host "  -AADGroups: For Azure AD groups containing devices" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Yellow
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\IntuneRemoteActions.ps1 -DisplayNames 'Device1','Device2' -Wipe" -ForegroundColor White
    Write-Host "  .\IntuneRemoteActions.ps1 -Serials 'ABC123','XYZ789' -Sync" -ForegroundColor White
    Write-Host "  .\IntuneRemoteActions.ps1 -AADGroups 'Marketing Devices','Finance Laptops' -Restart" -ForegroundColor White
}