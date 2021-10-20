<#
Setup Auto update on Google Chrome
Test to see if it is installed using the key defined by MSDE Software evidence
Delete the previous key if in existance to allow for a complete refresh of that registry key
Recreate the key properly iaw guideance gained from Chrome and the GP Policy installed and configured via ADMX
Updated 01-04-2021
#>
 
    If (Test-Path "HKLM:\SOFTWARE\Policies\Google")
        {
        #If the key already exists delete the value and start again
        Write-Output "True the Update key already exists - Delete the key to allow for a complete refresh"
        Remove-Item -Path 'HKLM:\SOFTWARE\Policies\Google\Update'
       
        }
        else
        {
         Write-Output "True the Update key doesnt exist - create and edit it"
        }
        #Rebuild the key and its entries
        #Might need to change these to Dword entries but no problem reported in GP using this script.  Upload - distribute - test.
        Write-Output "Rebuilding the Google Update keys"
        New-Item 'HKLM:\SOFTWARE\Policies\Google' -force
        New-Item 'HKLM:\SOFTWARE\Policies\Google\Update' -force
        New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Google\Update' -Name 'AutoUpdateCheckPeriodMinutes' -type Dword -value '00000078'
        New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Google\Update' -Name 'CloudPolicyOverridesPlatformPolicy' -type Dword -value '00000001'
        New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Google\Update' -Name 'UpdateDefault' -type Dword -value '00000001'
        New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Google\Update' -Name 'InstallDefault' -type Dword -value '00000001'
        Get-ItemProperty -Path 'Registry::HKLM\SOFTWARE\Policies\Google\Update'
