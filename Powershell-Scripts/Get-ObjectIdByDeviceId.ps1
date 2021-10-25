[CmdletBinding()]
Param (
    # Id of Distribution Group
    [Parameter(Mandatory=$true)]
    [string]
    $AzureDeviceIDFile,
    [Parameter(Mandatory=$true)]
    [string]
    $ExportFile
)

# Check and Import Modules
Write-Host "Checking for Microsoft.Graph Modules..." -ForegroundColor Yellow
$MicrosoftGraphModules = Get-InstalledModule -Name 'Microsoft.Graph*'
if($MicrosoftGraphModules.Name -eq 'Microsoft.Graph.Identity.DirectoryManagement' -and $MicrosoftGraphModules.Name -eq 'Microsoft.Graph')
{
    Write-Host "Importing Modules..." -ForegroundColor Yellow
    Import-Module -Name Microsoft.Graph.Identity.DirectoryManagement
    Write-Host "Modules Imported!" -ForegroundColor Green
}
else 
{
    Write-Host "Unable to find Microsoft.Graph Module(s)" -ForegroundColor Red
    Write-Host "Please Run Install-Module -Name Microsoft.Graph -Force" -ForegroundColor Yellow
    exit    
}

# Connect to Microsoft Graph - Utilizing the Microsoft.Graph Module
try 
{
    Write-Host "Connecting to MgGraph..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes "Directory.AccessAsUser.All"
}
catch 
{
    Write-Host "Unable to connect to MgGraph" -ForegroundColor Red
    Write-Error $_
}


# Import AzureAD Device IDs
$AzureADDeviceIDs = Get-Content -Path $AzureDeviceIDFile
Write-Host "Processing $($AzureADDeviceIDs.Count) Devices..." -ForegroundColor Yellow

# Initialize Array
$DevicesArray = @()

# Loop Through
foreach ($DeviceId in $AzureADDeviceIDs)
{
    # Search for the Device in AzureAD by DeviceId
    $Device = Get-MgDevice -Filter "deviceId eq '$DeviceId'"

    # Check Variable
    if($Device)
    {
        $DevicesArray += New-Object PsObject -Property @{
            DeviceName = $Device.DisplayName
            ObjectId = $Device.Id
            DeviceId = $Device.DeviceId
        }
    }
}

Write-Host "Complete!" -ForegroundColor Green

# Export Array
$DevicesArray | Export-CSV -NoTypeInformation -Path $ExportFile -Force