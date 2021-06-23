<#

Setup Google Chrome Policies iaw MSDE Guidelines
Test to see if it is installed using the key defined by MSDE Software evidence
Delete the previous key if in existance to allow for a complete refresh of that registry key
Recreate the key properly iaw guideance gained from Chrome and the GP Policy installed and configured via ADMX
Updated 22-06-2021

#>


#Define the registry key
$installevidence = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe"
$regkey = "Registry::HKLM\SOFTWARE\Policies\Google\Chrome\"

If (Test-Path -Path $installevidence)
    {
    #If the key already exists just set the value
    Write-Output "True Google Chrome Installed"
    
    If (Test-Path -Path $regkey)
        {
        #If the key already exists delete the entire content
        Write-Output "True the Update key already exists - Delete the key to allow for a complete refresh"
        Remove-Item -Path $regkey -Force
       
        }
        else
        {
         Write-Output "True the Update key doesnt exist - create and edit it"
        }
        #Rebuild the key and its entries
        Write-Output "Rebuilding the Google Policy keys"

        New-Item -Path $regkey -Force
        New-ItemProperty -Path $regkey -Name 'CloudPolicyOverridesPlatformPolicy' -value '1'
        New-ItemProperty -Path $regkey -Name 'BackgroundModeEnabled' -value '0'
        New-ItemProperty -Path $regkey -Name 'DefaultPluginsSetting' -value '3'
        New-ItemProperty -Path $regkey -Name 'AllowOutdatedPlugins' -value '0'
        New-ItemProperty -Path $regkey -Name 'ComponentUpdatesEnabled' -value '1'
        New-ItemProperty -Path $regkey -Name 'DnsOverHttpsMode' -value 'automatic'
        New-ItemProperty -Path $regkey -Name 'BackgroundModeEnabled' -value '0'
        Get-ItemProperty -Path $regkey
    }
    else
    {
     ##If the key doesnt exist then the program is not installed and doesnt need rectification
     Write-Output "False Google Chrome not installed"
     }

