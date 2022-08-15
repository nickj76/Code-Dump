<#  
    .SYNOPSIS
    Powershell Script to find all computers in Intune and when the last time they were online.
    
    .NOTES
    filename: Disable-remove-devices-intune.ps1
    
    Powershell Script to find all computers in Intune and when the last time they were online.
    If not older used in last 365 days to remove them.
    
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

#Get CSV to Desktop of all Devices not used in 365 Days
$dt = (Get-Date).AddDays(-365)
Get-AzureADDevice -All:$true | Where-Object {$_.ApproximateLastLogonTimeStamp -le $dt} | select-object -Property AccountEnabled, DeviceId, DeviceOSType, DeviceOSVersion, DisplayName, DeviceTrustType, ApproximateLastLogonTimestamp | export-csv C:\IntuneFiles\devicelist-olderthan-365days-summary.csv -NoTypeInformation

#Get Disable all Devices not used in 365 Days
$disyesorno = Read-Host -Prompt "Would you like to disable all devices (Y/N)?"

if($disyesorno -eq "Y") {
        $dt = (Get-Date).AddDays(-365)
        Get-AzureADDevice -All:$true | Where-Object {$_.ApproximateLastLogonTimeStamp -le $dt} | Set-AzureADDevice -AccountEnabled $false
        write-host("All Devices older than 365 Days have been disabled!")
    }else{
      write-host("No Devices have been disabled!")
}

#Remove all Devices not used in 365 Days
$rmvyesorno = Read-Host -Prompt "Would you like to remove all devices (Y/N)?"

if($rmvyesorno -eq "Y") {
        $dt = (Get-Date).AddDays(-365)
        $Devices = Get-AzureADDevice -All:$true | Where-Object {($_.ApproximateLastLogonTimeStamp -le $dt) -and ($_.AccountEnabled -eq $false)}
            foreach ($Device in $Devices) {
            Remove-AzureADDevice -ObjectId $Device.ObjectId
        }
        write-host("All Devices older than 365 Days have been removed!")
    }else{
      write-host("No Devices have been removed!")
}

pause