#Setup Require domain users to elevate when setting a networks location
#Call the registry value and if existing set the value, if not create it
#The test case exists by default - the entry does not - create it
#Created 28-01-2021


If (Get-ItemProperty -Path 'Registry::HKLM\SOFTWARE\Policies\Microsoft\Windows\Network Connections\')
    {
    #If the key already exists just set the value
    Write-Output "True"
    Set-Itemproperty -Path 'Registry::HKLM\SOFTWARE\Policies\Microsoft\Windows\Network Connections\' -Name 'NC_StdDomainUserSetLocation' -value '1'
    Get-ItemProperty -Path 'Registry::HKLM\SOFTWARE\Policies\Microsoft\Windows\Network Connections\' -Name NC_StdDomainUserSetLocation
    }
    else
    {
     #If the key doesnt exist create it and set the value
     Write-Output "False"
     Get-ItemProperty -Path 'Registry::HKLM\SOFTWARE\Policies\Microsoft\Windows\Network Connections\'
     }
