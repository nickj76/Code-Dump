<#
.SYNOPSIS
    Intune Remote Actions PowerShell script can perform various management actions on devices that are no longer needed, being repurposed, or missing.
    Supported actions include wiping, retiring, syncing, locking, deleting, restarting, and shutting down devices.
    Script input requires one or multiple Device Name/Host Name or Device Serial Number for performing the specified actions as parameters.

.DESCRIPTION
    IntuneRemoteActions.ps1 is a PowerShell script to find Intune Enrolled Device information from Microsoft Endpoint Management and perform specified remote actions.
    The actions include wiping, retiring, syncing, locking (Android, iOS, MacOS Only), deleting, restarting, and shutting down devices.

.Notes
    Connect to graph using secret script first before running this script
#>

param (
    [string[]]$DisplayNames,
    [string[]]$Serials,
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
    Import-Module -Name 'Microsoft.Graph.DeviceManagement','Microsoft.Graph.DeviceManagement.Actions'
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
    Import-Module -Name 'Microsoft.Graph.DeviceManagement','Microsoft.Graph.DeviceManagement.Actions'
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

function Perform-RemoteAction {
    param (
        [string]$Identifier,
        [string]$Action,
        [string]$Filter
    )

    Write-Host "Searching Intune Devices with Identifier '$Identifier'....." -ForegroundColor Cyan
    $IntuneDevices = Get-MgDeviceManagementManagedDevice -Filter $Filter
    if ($IntuneDevices) {
        foreach ($IntuneDevice in $IntuneDevices) {
            Write-Host "Device found in Intune. Initiating $Action action....." -ForegroundColor Green
            switch ($Action) {
                "Wipe" {
                    Clear-MgDeviceManagementManagedDevice -ManagedDeviceId $IntuneDevice.Id
                    Write-Host "Remote wipe initiated for Device '$Identifier'. Please keep the device online for at least an hour." -ForegroundColor Green
                }
                "Retire" {
                    Invoke-MgRetireDeviceManagementManagedDevice -ManagedDeviceId $IntuneDevice.Id
                    Write-Host "Remote retire initiated for Device '$Identifier'." -ForegroundColor Green
                }
                "Delete" {
                    Remove-MgDeviceManagementManagedDevice -ManagedDeviceId $IntuneDevice.Id -Force
                    Write-Host "Remote delete initiated for Device '$Identifier'." -ForegroundColor Green
                }                
                "Sync" {
                    Sync-MgDeviceManagementManagedDevice -ManagedDeviceId $IntuneDevice.Id
                    Write-Host "Remote sync initiated for Device '$Identifier'." -ForegroundColor Green
                }
                "Lock" {
                    Lock-MgDeviceManagementManagedDeviceRemote -ManagedDeviceId $IntuneDevice.Id
                    Write-Host "Remote lock initiated for Device '$Identifier'." -ForegroundColor Green
                }
                "Restart" {
                    Restart-MgDeviceManagementManagedDeviceNow -ManagedDeviceId $IntuneDevice.Id
                    Write-Host "Remote restart initiated for Device '$Identifier'." -ForegroundColor Green
                }
                "Shutdown" {
                    Invoke-MgDownDeviceManagementManagedDeviceShut -ManagedDeviceId $IntuneDevice.Id
                    Write-Host "Remote shutdown initiated for Device '$Identifier'." -ForegroundColor Green
                }
            }
        }
    } else {
        Write-Host "Device with Identifier '$Identifier' not found in Intune or already removed from Intune." -ForegroundColor Yellow
    }
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
} else {
    Write-Host "Enter the Display Name or Serial Number as parameters. (Example: .\IntuneRemoteActions.ps1 -DisplayNames 'Device1','Device2' -Wipe)" -ForegroundColor Red
}
