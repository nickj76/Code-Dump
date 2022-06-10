# Add devices to security group AAD
# 13416352-b67a-4f55-8ba3-5604f844c679 is the group object ID in Azure change as needed.


$devices = Import-Csv C:\temp\SPSS-Devices.csv

foreach ($device in $devices)
{
    $azureCheck = $null
    $azureCheck = Get-AzureADDevice -SearchString $device.Machine

    foreach ($azDevice in $azureCheck)
    {
        Write-Host $device.Machine $azDevice.ObjectId
        Add-AzureADGroupMember -ObjectId 13416352-b67a-4f55-8ba3-5604f844c679 -RefObjectId $azDevice.ObjectId
    }
}