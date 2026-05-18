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
