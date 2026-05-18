<#
.SYNOPSIS
    Perform Intune actions on a device or devices, including wiping, retiring, syncing, locking, deleting, restarting, and shutting down devices.

.DESCRIPTION
    Perform specified remote actions on Intune enrolled devices using Microsoft Graph API.
    The actions include wiping, retiring, syncing, locking (Android, iOS, MacOS Only), deleting, restarting, and shutting down devices.
    Actions can be performed on individual devices or on all devices in specified Azure AD groups.
    Script input requires one or multiple Device Name/Host Name, Device Serial Number, or AAD Group names for performing the specified actions as parameters.

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
    Switch to bypass confirmation prompts for all actions on each targeted device (use with caution).

.EXAMPLE
    .\IntuneRemoteActions.ps1 -DisplayNames 'Device1','Device2' -Wipe
    .\IntuneRemoteActions.ps1 -Serials 'ABC123','XYZ789' -Sync
    .\IntuneRemoteActions.ps1 -AADGroups 'Marketing Devices','Finance Laptops' -Restart

.Notes
    Connect to graph using secret script first before running this script.
#>

param (
    [Parameter(ParameterSetName='DisplayName',Mandatory=$true)]
    [string[]]$DisplayNames,
    [Parameter(ParameterSetName='Serial',Mandatory=$true)]
    [string[]]$Serials,
    [Parameter(ParameterSetName='Group',Mandatory=$true)]
    [string[]]$AADGroups,

    [switch]$Wipe,
    [switch]$Retire,
    [switch]$Sync,
    [switch]$Lock,
    [switch]$Delete,
    [switch]$Restart,
    [switch]$Shutdown,

    [switch]$Force = $false
)


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
        [string]$Action,
        [array]$Devices,
        [switch]$Force = $false
    )

    $IntuneDevices = $Devices

    if (-not $IntuneDevices -or $IntuneDevices.Count -le 0) {
        Write-Host "no devices found." -ForegroundColor Yellow
        return
    }

    foreach ($IntuneDevice in $IntuneDevices) {

        # Show confirmation prompt before executing action (unless Force is specified)
        if (-not $Force) {
            Write-Host ""
            Write-Host "WARNING: You are about to perform a '$Action' action on device: $($Intunedevice.deviceName)" -ForegroundColor Yellow
            Write-Host "Device Details:" -ForegroundColor Cyan
            Write-Host "  - Device Name: $($IntuneDevice.DeviceName)" -ForegroundColor White
            Write-Host "  - Serial Number: $($IntuneDevice.SerialNumber)" -ForegroundColor White
            Write-Host "  - Operating System: $($IntuneDevice.OperatingSystem)" -ForegroundColor White
            Write-Host "  - Device ID: $($IntuneDevice.Id)" -ForegroundColor White
            Write-Host ""

            do {
                $confirmation = Read-Host "Are you sure you want to perform '$Action' on this device? (Y/N/A(to abort all))"
                $confirmation = $confirmation.ToUpper()
            } while ($confirmation -notin @('Y', 'N', 'A'))
                
            if ($confirmation -eq 'A') {
                Write-Host "Operation cancelled by user." -ForegroundColor Red
                return
            }
            elseif ($confirmation -eq 'N') {
                Write-Host "Skipping device: $($Intunedevice.deviceName)" -ForegroundColor Yellow
                continue
            }
        }

        Write-Host "Initiating $Action action for $($Intunedevice.deviceName) $($Intunedevice.serialNumber)..." -ForegroundColor Cyan

        try {
            switch ($Action) {
                "Wipe" {
                    Clear-MgDeviceManagementManagedDevice -ManagedDeviceId $IntuneDevice.Id
                    Write-Host "Remote wipe initiated for Device $($Intunedevice.deviceName) $($Intunedevice.serialNumber)." -ForegroundColor Green
                }
                "Retire" {
                    Invoke-MgRetireDeviceManagementManagedDevice -ManagedDeviceId $IntuneDevice.Id
                    Write-Host "Remote retire initiated for Device $($Intunedevice.deviceName) $($Intunedevice.serialNumber)." -ForegroundColor Green
                }
                "Delete" {
                    Remove-MgDeviceManagementManagedDevice -ManagedDeviceId $IntuneDevice.Id -Force
                    Write-Host "Remote delete initiated for Device $($Intunedevice.deviceName) $($Intunedevice.serialNumber)." -ForegroundColor Green
                }                
                "Sync" {
                    Sync-MgDeviceManagementManagedDevice -ManagedDeviceId $IntuneDevice.Id
                    Write-Host "Remote sync initiated for Device $($Intunedevice.deviceName) $($Intunedevice.serialNumber)." -ForegroundColor Green
                }
                "Lock" {
                    Lock-MgDeviceManagementManagedDeviceRemote -ManagedDeviceId $IntuneDevice.Id
                    Write-Host "Remote lock initiated for Device '$($Intunedevice.deviceName) $($Intunedevice.serialNumber)." -ForegroundColor Green
                }
                "Restart" {
                    Restart-MgDeviceManagementManagedDeviceNow -ManagedDeviceId $IntuneDevice.Id
                    Write-Host "Remote restart initiated for Device $($Intunedevice.dieviceName) $($Intunedevice.serialNumber)." -ForegroundColor Green
                }
                "Shutdown" {
                    Invoke-MgDownDeviceManagementManagedDeviceShut -ManagedDeviceId $IntuneDevice.Id
                    Write-Host "Remote shutdown initiated for Device $($Intunedevice.deviceName) $($Intunedevice.serialNumber)." -ForegroundColor Green
                }
            }
                
            # Log to console instead of UI
            $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Write-Host "[$timestamp] Device: $($Intunedevice.deviceName) $($Intunedevice.serialNumber) - Action: $Action - Status: Success" -ForegroundColor Green
        }
        catch {
            Write-Host "Error performing ${Action} on $($Intunedevice.deviceName) $($Intunedevice.serialNumber): $($_.Exception.Message)" -ForegroundColor Red
                
            # Log error to console
            $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Write-Host "[$timestamp] Device: $($Intunedevice.deviceName) $($Intunedevice.serialNumber) - Action: $Action - Status: Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}


# BEGIN


$num_actions = 0
$action = $null
if ($Wipe) { $num_actions++ ; $action = "Wipe" }
if ($Retire) { 
    $num_actions++ ; $action = "Retire"
    Write-Host "Retire action has not yet been tested, please hold, your call is important to us"
    exit
} 
if ($Sync) { $num_actions++ ; $action = "Sync" }
if ($Lock) { 
    $num_actions++ ; $action = "Lock"
    Write-Host "Lock action will not work on Windows devices"
    exit
}
if ($Delete) { 
    $num_actions++ ; $action = "Delete" 
    Write-Host "Delete action has not yet been tested, please hold, your call is important to us"
    exit
}
if ($Restart) { $num_actions++ ; $action = "Restart" }
if ($Shutdown) {
    $num_actions++ ; $action = "Shutdown"
    Write-Host "Shutdown action does not currently work, blame Microsoft"
    exit
}

if ($num_actions -eq 0) {
    Write-Host "No actions specified. Please specify at least one action to perform." -ForegroundColor Red
    exit
}
if ($num_actions -gt 1) {
    Write-Host "Multiple actions specified. Please only specify one action." -ForegroundColor Yellow
}

If (!(Get-mgContext)) {
    Write-Host "You are not connected to Microsoft Graph. Please connect first." -ForegroundColor Red
    exit
}

$devicelist = @()
If ($PSCmdlet.ParameterSetName -eq 'DisplayName') {
    Write-Host "Performing action '$action' on devices with Display Names: $($DisplayNames -join ', ')" -ForegroundColor Cyan
    foreach ($DisplayName in $DisplayNames) {
        $devices = Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$DisplayName'"
        if ($devices -and $devices.Count -gt 0) {
            foreach ($device in $devices) {
                $devicelist += $device
            }
        }
        else {
            Write-Host "No devices found with Display Name '$DisplayName'." -ForegroundColor Yellow
        }
    }

} ElseIf ($PSCmdlet.ParameterSetName -eq 'Serial') {
    Write-Host "Performing action '$action' on devices with Serial Numbers: $($Serials -join ', ')" -ForegroundColor Cyan
    foreach ($serial in $serials) {
        $devices = Get-MgDeviceManagementManagedDevice -Filter "contains(serialNumber,'$Serial')"
        if ($devices -and $devices.Count -gt 0) {
            foreach ($device in $devices) {
                $devicelist += $device
            }
        }
        else {
            Write-Host "No devices found with Serial '$serial'." -ForegroundColor Yellow
        }
    }

} ElseIf ($PSCmdlet.ParameterSetName -eq 'Group') {
    Write-Host "Performing action '$action' on devices in AAD Groups: $($AADGroups -join ', ')" -ForegroundColor Cyan
    Foreach ($GroupName in $AADGroups) {
        $devices = Get-DevicesFromAADGroup -GroupName $GroupName
        if ($devices) {
            $devicelist += $devices
        } else {
            Write-Host "No devices found in group '$GroupName'." -ForegroundColor Yellow
        }
    }
}

Write-Host "The action '$action' will be performed on the following $($devicelist.Count) devices:" -ForegroundColor Cyan

Foreach ($device in $devicelist) {
    #Write-Host "Processing device: $($device.DeviceName) ($($device.SerialNumber))" -ForegroundColor Cyan
    Write-Host "$($device.DeviceName) ($($device.SerialNumber))" -ForegroundColor Cyan
}

Write-Host "Are you sure you want to perform the action '$action' on these devices? (Yes/No)" -ForegroundColor Yellow
$confirmation = Read-Host
if ($confirmation -ne "Yes") {
    Write-Host "Action cancelled." -ForegroundColor Red
    exit
}


Perform-RemoteAction -Device $devicelist -Action $action -Force:$Force
