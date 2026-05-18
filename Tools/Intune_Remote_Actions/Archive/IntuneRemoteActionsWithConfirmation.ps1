<#
.SYNOPSIS
    Intune Remote Actions PowerShell script for managing Intune-enrolled devices via Microsoft Graph.

.DESCRIPTION
    This script enables administrators to perform remote management actions on Intune-enrolled devices that are no longer needed, being repurposed, or missing. 
    Supported actions include wiping, retiring, syncing, locking (Android, iOS, MacOS only), deleting, restarting, and shutting down devices.
    Devices can be targeted individually by Device Name, Serial Number, or collectively via Azure AD Group names.
    The script requires prior authentication to Microsoft Graph using a separate secret script.

.PARAMETER DisplayNames
    An array of device display names (host names) to target for remote actions.

.PARAMETER Serials
    An array of device serial numbers to target for remote actions.

.PARAMETER AADGroups
    An array of Azure AD group display names. All Intune-managed devices in these groups will be targeted.

.PARAMETER Wipe
    Switch to initiate a remote wipe on the targeted devices.

.PARAMETER Retire
    Switch to initiate a remote retire on the targeted devices.

.PARAMETER Sync
    Switch to initiate a remote sync on the targeted devices.

.PARAMETER Lock
    Switch to initiate a remote lock on the targeted devices (Android, iOS, MacOS only).

.PARAMETER Delete
    Switch to initiate a remote delete on the targeted devices.

.PARAMETER Restart
    Switch to initiate a remote restart on the targeted devices.

.PARAMETER Shutdown
    Switch to initiate a remote shutdown on the targeted devices.

.PARAMETER Force
    Switch to bypass confirmation prompts for all actions (use with caution).

.EXAMPLE
    .\IntuneRemoteActions.ps1 -DisplayNames 'Device1','Device2' -Wipe
    Initiates a remote wipe on devices named 'Device1' and 'Device2'.

.EXAMPLE
    .\IntuneRemoteActions.ps1 -Serials 'ABC123','XYZ789' -Sync
    Initiates a remote sync on devices with serial numbers 'ABC123' and 'XYZ789'.

.EXAMPLE
    .\IntuneRemoteActions.ps1 -AADGroups 'Marketing Devices','Finance Laptops' -Restart
    Initiates a remote restart on all Intune-managed devices in the specified Azure AD groups.

.EXAMPLE
    .\IntuneRemoteActions.ps1 -DisplayNames 'Device1' -Delete -Force
    Initiates a remote delete on 'Device1' without confirmation prompt.

.NOTES
    - Requires Microsoft Graph PowerShell SDK modules.
    - Must authenticate to Microsoft Graph before running this script.
    - Use the -Force parameter with caution, as it will skip all confirmation prompts.
    - For more information, visit:
        https://github.com/UoS-CAVE/Intune_Remote_Actions
        https://learn.microsoft.com/en-us/graph/api/resources/intune-devices-manageddevice?view=graph-rest-1.0
        https://learn.microsoft.com/en-us/mem/intune/remote-actions/device-management
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
    [switch]$Shutdown,
    [switch]$Force
)

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
        [PSCustomObject]$Device = $null,
        [switch]$Force
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
            
            # Show confirmation prompt before executing action (unless Force is specified)
            if (-not $Force) {
                Write-Host ""
                Write-Host "WARNING: You are about to perform a '$Action' action on device: $deviceIdentifier" -ForegroundColor Yellow
                Write-Host "Device Details:" -ForegroundColor Cyan
                Write-Host "  - Device Name: $($IntuneDevice.DeviceName)" -ForegroundColor White
                Write-Host "  - Serial Number: $($IntuneDevice.SerialNumber)" -ForegroundColor White
                Write-Host "  - Operating System: $($IntuneDevice.OperatingSystem)" -ForegroundColor White
                Write-Host "  - Device ID: $($IntuneDevice.Id)" -ForegroundColor White
                Write-Host ""
                
                do {
                    $confirmation = Read-Host "Are you sure you want to perform '$Action' on this device? (Y/N/S to Skip)"
                    $confirmation = $confirmation.ToUpper()
                } while ($confirmation -notin @('Y', 'N', 'S'))
                
                if ($confirmation -eq 'N') {
                    Write-Host "Operation cancelled by user." -ForegroundColor Red
                    return
                }
                elseif ($confirmation -eq 'S') {
                    Write-Host "Skipping device: $deviceIdentifier" -ForegroundColor Yellow
                    continue
                }
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
        [string]$Action,
        [switch]$Force
    )
    
    $devices = Get-DevicesFromAADGroup -GroupName $GroupName
    
    if ($devices) {
        Write-Host "Performing $Action action on all devices in group '$GroupName'..." -ForegroundColor Cyan
        foreach ($device in $devices) {
            Perform-RemoteAction -Action $Action -Device $device -Force:$Force
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
            Perform-RemoteAction -Identifier $DisplayName -Action "Wipe" -Filter "deviceName eq '$DisplayName'" -Force:$Force
        }
        if ($Retire) {
            Perform-RemoteAction -Identifier $DisplayName -Action "Retire" -Filter "deviceName eq '$DisplayName'" -Force:$Force
        }
        if ($Sync) {
            Perform-RemoteAction -Identifier $DisplayName -Action "Sync" -Filter "deviceName eq '$DisplayName'" -Force:$Force
        }
        if ($Lock) {
            Perform-RemoteAction -Identifier $DisplayName -Action "Lock" -Filter "deviceName eq '$DisplayName'" -Force:$Force
        }
        if ($Delete) {
            Perform-RemoteAction -Identifier $DisplayName -Action "Delete" -Filter "deviceName eq '$DisplayName'" -Force:$Force
        }
        if ($Restart) {
            Perform-RemoteAction -Identifier $DisplayName -Action "Restart" -Filter "deviceName eq '$DisplayName'" -Force:$Force
        }
        if ($Shutdown) {
            Perform-RemoteAction -Identifier $DisplayName -Action "Shutdown" -Filter "deviceName eq '$DisplayName'" -Force:$Force
        }
    }
} elseif ($Serials) {
    foreach ($Serial in $Serials) {
        if ($Wipe) {
            Perform-RemoteAction -Identifier $Serial -Action "Wipe" -Filter "contains(serialNumber,'$Serial')" -Force:$Force
        }
        if ($Retire) {
            Perform-RemoteAction -Identifier $Serial -Action "Retire" -Filter "contains(serialNumber,'$Serial')" -Force:$Force
        }
        if ($Sync) {
            Perform-RemoteAction -Identifier $Serial -Action "Sync" -Filter "contains(serialNumber,'$Serial')" -Force:$Force
        }
        if ($Lock) {
            Perform-RemoteAction -Identifier $Serial -Action "Lock" -Filter "contains(serialNumber,'$Serial')" -Force:$Force
        }
        if ($Delete) {
            Perform-RemoteAction -Identifier $Serial -Action "Delete" -Filter "contains(serialNumber,'$Serial')" -Force:$Force
        }
        if ($Restart) {
            Perform-RemoteAction -Identifier $Serial -Action "Restart" -Filter "contains(serialNumber,'$Serial')" -Force:$Force
        }
        if ($Shutdown) {
            Perform-RemoteAction -Identifier $Serial -Action "Shutdown" -Filter "contains(serialNumber,'$Serial')" -Force:$Force
        }       
    }
} elseif ($AADGroups) {
    foreach ($GroupName in $AADGroups) {
        if ($Wipe) {
            Perform-ActionOnGroup -GroupName $GroupName -Action "Wipe" -Force:$Force
        }
        if ($Retire) {
            Perform-ActionOnGroup -GroupName $GroupName -Action "Retire" -Force:$Force
        }
        if ($Sync) {
            Perform-ActionOnGroup -GroupName $GroupName -Action "Sync" -Force:$Force
        }
        if ($Lock) {
            Perform-ActionOnGroup -GroupName $GroupName -Action "Lock" -Force:$Force
        }
        if ($Delete) {
            Perform-ActionOnGroup -GroupName $GroupName -Action "Delete" -Force:$Force
        }
        if ($Restart) {
            Perform-ActionOnGroup -GroupName $GroupName -Action "Restart" -Force:$Force
        }
        if ($Shutdown) {
            Perform-ActionOnGroup -GroupName $GroupName -Action "Shutdown" -Force:$Force
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
    Write-Host "  .\IntuneRemoteActions.ps1 -DisplayNames 'Device1' -Delete -Force" -ForegroundColor White
    Write-Host "" -ForegroundColor Yellow
    Write-Host "Use -Force parameter to skip confirmation prompts (use with caution!)" -ForegroundColor Red
}