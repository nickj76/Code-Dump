#***********************************************************************
# Author: James Everett
# Written: 02/16/2023
# Purpose: Discover all mobile apps assigned to a group.
# Usage: .\Get-WinAppsAssignedToGroup.ps1 -GroupName {displayName}
#***********************************************************************

param (
	[parameter(Mandatory=$true)]
	[ValidateNotNullorEmpty()]
   	[string]$GroupName = $Null
)

<# Run this as an admin if needed
Install-Module Microsoft.Graph.Groups
Install-Module Microsoft.Graph.Devices.CorporateManagement
#>

Import-Module Microsoft.Graph.Groups
Import-Module Microsoft.Graph.Devices.CorporateManagement

#Connect-MgGraph -Scopes "DeviceManagementApps.Read.All","Device.Read.All"

$GroupInfo = (Get-MgGroup -ConsistencyLevel eventual -Search "displayName: $($GroupName)")

ForEach($app in Get-MgDeviceAppMgtMobileApp -Property "Id, displayName" -All:$true)
{
	$targets = (Get-MgDeviceAppMgtMobileAppAssignment -MobileAppId $app.Id -All:$true | Select-Object -ExpandProperty target)
	ForEach($target in $targets)
	{
		Switch($target['@odata.type'])
		{
			"#microsoft.graph.groupAssignmentTarget" {
				If($GroupInfo.Id -eq $target['groupId'])
				{
					Write-Host "$($app.displayName) -> $($GroupInfo.displayName) [$($GroupInfo.Id)]"
				}
			}
			"#microsoft.graph.allDevicesAssignmentTarget" {
				Write-Host "$($app.displayName) -> All Devices"
			}
		}
	}
}
