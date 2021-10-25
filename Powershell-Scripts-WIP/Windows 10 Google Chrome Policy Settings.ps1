﻿<#
Setup Google Chrome Policies iaw MSDE Guidelines
Test to see if it is installed using the key defined by MSDE Software evidence
Delete the previous key if in existance to allow for a complete refresh of that registry key
Recreate the key properly iaw guideance gained from Chrome and the GP Policy installed and configured via ADMX
Updated 29-06-2021
#>


#Define the registry key
#Need to redefine this as not taking into account the two different install methods for Chrome or need a new test case
$regkey = "HKLM:\SOFTWARE\Policies\Google\Chrome\"
 
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

        New-Item $regkey -Force

       #Security settings
        New-ItemProperty -Path $regkey -Name 'CloudPolicyOverridesPlatformPolicy' -value '1'
        New-ItemProperty -Path $regkey -Name 'ComponentUpdatesEnabled' -value '1'
        New-ItemProperty -Path $regkey -Name 'DnsOverHttpsMode' -value 'secure'
        New-ItemProperty -Path $regkey -Name 'DnsOverHttpsTemplates' -value 'https://security.cloudflare-dns.com/dns-query'
        New-ItemProperty -Path $regkey -Name 'BuiltInDnsClientEnabled' -value '1'
        New-ItemProperty -Path $regkey -Name 'SSLVersionMin' -value 'tls1.2'

        New-ItemProperty -Path $regkey -Name 'PasswordLeakDetectionEnabled' -value '1'
        New-ItemProperty -Path $regkey -Name 'PasswordManagerEnabled' -value '1'
        New-ItemProperty -Path $regkey -Name 'PasswordProtectionWarningTrigger' -value '1'


        #Extensions - cant be bothered managing these so just kill the buggers
        New-ItemProperty -Path $regkey -Name 'BackgroundModeEnabled' -value '0'
        New-ItemProperty -Path $regkey -Name 'BlockExternalExtensions' -value '1'
        
        Get-ItemProperty -Path $regkey

