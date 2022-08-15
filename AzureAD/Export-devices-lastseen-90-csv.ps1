<#  .SYNOPSIS
    Powershell Script to find all computers in Intune and when the last time they were online.

    .NOTES
    filename: Get-old-devices.ps1
    
    If computer not used in 90 day export list to CSV located: export-csv C:\IntuneFiles\devicelist-olderthan-90days-summary.csv
    Change line 28 as required e.g. .AddDays(-90) or .AddDays(-60)     
    #>
    
#Sign-in to AzureAD
Connect-AzureAD

#check if Folder exists
$folderName = "IntuneFiles"
$Path="C:\"+$folderName

if (!(Test-Path $Path))
{
New-Item -itemType Directory -Path C:\ -Name $FolderName
}
else
{
write-host "Folder already exists"
}

#Get CSV to Desktop of all Devices not used in 90 Days
$dt = (Get-Date).AddDays(-90)
Get-AzureADDevice -All:$true | Where-Object {$_.ApproximateLastLogonTimeStamp -le $dt} | select-object -Property AccountEnabled, DeviceId, DeviceOSType, DeviceOSVersion, DisplayName, DeviceTrustType, ApproximateLastLogonTimestamp | export-csv C:\IntuneFiles\devicelist-olderthan-90days-summary.csv -NoTypeInformation
