<#
.SYNOPSIS
    Get enrollment date of Intune managed devices.

.DESCRIPTION
    Get the enrollment date of Intune managed devices. Primarily useful to check all have been rebuilt after performing a bulk wipe/retire.
    Can be performed on individual devices or on all devices in specified Azure AD groups.
    Script input requires one or multiple Device Name/Host Name, Device Serial Number, or AAD Group names.

.PARAMETER DisplayNames
    An array of device display names (host names) to target for remote actions.

.PARAMETER Serials
    An array of device serial numbers to target for remote actions.

.PARAMETER AADGroups
    An array of Azure AD group display names. All Intune-managed devices in these groups will be targeted.

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
    [string[]]$AADGroups
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
                } else {
                    Write-Host "Device with AAD Device ID '$($deviceObj.DeviceId)' $($deviceObj.DisplayName) has no intune record" -ForegroundColor Yellow
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


If (!(Get-mgContext)) {
    Write-Host "You are not connected to Microsoft Graph. Please connect first." -ForegroundColor Red
    exit
}

$devicelist = @()
If ($PSCmdlet.ParameterSetName -eq 'DisplayName') {
    Write-Host "Getting enrollment date for devices with Display Names: $($DisplayNames -join ', ')" -ForegroundColor Cyan
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
    Write-Host "Getting enrollment date for devices with Serial Numbers: $($Serials -join ', ')" -ForegroundColor Cyan
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
    Write-Host "Getting enrollment date for devices in AAD Groups: $($AADGroups -join ', ')" -ForegroundColor Cyan
    Foreach ($GroupName in $AADGroups) {
        $devices = Get-DevicesFromAADGroup -GroupName $GroupName
        if ($devices) {
            $devicelist += $devices
        } else {
            Write-Host "No devices found in group '$GroupName'." -ForegroundColor Yellow
        }
    }
}


Foreach ($device in $devicelist) {
    #Write-Host "Processing device: $($device.DeviceName) ($($device.SerialNumber))" -ForegroundColor Cyan
    Write-Host "$($device.DeviceName) ($($device.SerialNumber)) $($device.EnrolledDateTime) $($device.ManagedDeviceName)" -ForegroundColor Cyan
}

