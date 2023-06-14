<# 
.SYNOPSIS
   Fix LSA for joined machines and set prerequisites for advanced auditing controls

.DESCRIPTION
   Creates or modifies the registry keys no matter what
   
.EXAMPLE
   PS C:\> .\Windows-10-LSA-and-Auditing.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v4+
#>


#
#Create or modify the registry keys no matter what
#Test machine had second key - other test machine did not have second key and is required.
#created based on research 05-03-2021


If (Test-path -Path 'Registry::HKLM\SYSTEM\CurrentControlSet\Control\Lsa\')
    {
    #If the key already exists just set the value
    Write-Output "True"
    Set-Itemproperty -Path Registry::HKLM\SYSTEM\CurrentControlSet\Control\Lsa\ -Name 'RunAsPPL' -value '1'
    Set-ItemProperty -Path Registry::HKLM\SYSTEM\CurrentControlSet\Control\Lsa\ -Name 'SCENoApplyLegacyAuditPolicy' -value '1'
    }
    else
    {
    Write-Output "False"
    }

