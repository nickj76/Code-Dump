<# 
.SYNOPSIS
   Script that can be used to obtain ObjectID's from Intune without using graph.

.DESCRIPTION
   Obtain ObjectID's from Azure AD, -Searchstring can be used to target devices or be removed if you wish to search entire inventory.

.EXAMPLE
   PS C:\> .\Get-Device-ObjectID.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.
   
.FUNCTIONALITY
   PowerShell v1+
#>

Connect-AzureAD ## You will be prompted to enter your service account details
$PathCsv = "C:\temp\UWSA-DeviceList.csv"
$deviceList = Get-AzureADDevice -All $True -Searchstring "uwsa"| Select-Object @(
    'DisplayName'
    'ObjectId'
    'AccountEnabled'
    'DeviceOSType'
    'DeviceOSVersion'
    'DeviceTrustType'
    'ApproximateLastLogonTimeStamp'
    'DeviceId'
   )
$devices = @()
   
foreach($device in $deviceList){
    $deviceOwner = $device | Get-AzureADDeviceRegisteredOwner
    $deviceProps = [ordered] @{
        DeviceName = $device.DisplayName
        ObjectId = $device.ObjectId
        Enabled = $device.AccountEnabled
        OS = $device.DeviceOSType
        Version = $device.DeviceOSVersion
        JoinType = $device.DeviceTrustType
        Owner = $deviceOwner.DisplayName
        LastLogonTimestamp = $device.ApproximateLastLogonTimeStamp
    }
    $deviceObj = New-Object -Type PSObject -Property $deviceProps
    $devices += $deviceObj
}
   
$devices | Export-Csv -Path $PathCsv -NoTypeInformation -Append