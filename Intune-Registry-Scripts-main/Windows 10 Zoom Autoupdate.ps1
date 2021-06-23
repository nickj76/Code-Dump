<#
Test for the installation of Zoom Desktop Client and force updates
Test to see if it is installed using the key defined by MSDE Software evidence

Recreate the key properly iaw guideance gained from Zoom and the GP Policy installed and configured via ADMX
Updated 01-04-2021

#>



$regpath1 = “Registry::HKLM\SOFTWARE\Policies\Zoom\Zoom Meetings\General"
$regpath2 = "Registry::HKLM\SOFTWARE\Policies\Zoom\Zoom Meetings\Recommended\General"


If (Test-Path -Path 'Registry::HKLU\S-1-5-21-1383276029-1848211696-1003303358-1002\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\ZoomUMX')
    {
    #If the key already exists delete the key for a complete refresh
    Write-Output "True Windows Policy Key exists"
    

    If (Test-Path -Path $regpath1)
        {
        #If the key already exists just modify the value
        Write-Output "True the policy key already exists - modify the value"
        Set-ItemProperty -Path $regpath1 -Name 'EnableClientAutoUpdate' -value '1'
        Get-ItemProperty -Path $regpath1
       
        }
        else
        {
         Write-Output "True the policy key doesnt exist - create and edit it"
         New-Item -Path $regpath1
         New-ItemProperty -Path $regpath1 -Name 'EnableClientAutoUpdate' -value '1'
         Get-ItemProperty -Path $regpath1
        }

    If (Test-Path -Path $regpath2)
        {
        #If the key already exists just modify the value
        Write-Output "True the policy key already exists - modify the value"
        Set-ItemProperty -Path $regpath2 -Name 'EnableClientAutoUpdate' -value '1'
        Get-ItemProperty -Path $regpath2
       
        }
        else
        {
         Write-Output "True the policy key doesnt exist - create and edit it"
         New-Item -Path $regpath2
         New-ItemProperty -Path $regpath2 -Name 'EnableClientAutoUpdate' -value '1'
         Get-ItemProperty -Path $regpath2
        }

    }
    else
    {
     ##If the key doesnt exist then the program is not installed and doesnt need rectification
     Write-Output "False Windows Policy Key doesnt exist"
    }
