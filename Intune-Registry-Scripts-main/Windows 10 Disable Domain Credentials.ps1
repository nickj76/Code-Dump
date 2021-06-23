#Setup Disable Domain Credentials
#Call the registry value at and then set the value
#Updated on 07-06-2021 - Previous error has been fixed and reported as propagated via MEM.


If (Get-ItemProperty -Path Registry::HKLM\SYSTEM\CurrentControlSet\Control\Lsa\)
    {
    #If the key already exists just set the value
    Write-Output "True"
    #Apply the correct setting to the CORRECT ITEM
    Set-Itemproperty -Path Registry::HKLM\SYSTEM\CurrentControlSet\Control\Lsa\ -Name 'disabledomaincreds' -value '1'
    Get-ItemProperty -Path Registry::HKLM\SYSTEM\CurrentControlSet\Control\Lsa\
    }
    else
    {
     #If the key doesnt exist create it and set the value
     Write-Output "False"
     New-Item -Path Registry::HKLM\SYSTEM\CurrentControlSet\Control\Lsa\
     New-Itemproperty -Path Registry::HKLM\SYSTEM\CurrentControlSet\Control\Lsa\ -Name 'disabledomaincreds' -value '1' -Force
     Get-ItemProperty -Path Registry::HKLM\SYSTEM\CurrentControlSet\Control\Lsa\
     }
