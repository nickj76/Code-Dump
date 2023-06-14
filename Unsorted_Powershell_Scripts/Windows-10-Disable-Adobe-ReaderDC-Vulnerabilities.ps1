<# 
.SYNOPSIS
   Disable flash & Java in Adobe Reader DC.

.DESCRIPTION
   Disables flash & Java in Adobe Reader DC, after checking to see if Adobe Reader DC is installed.

.EXAMPLE
   PS C:\> .\Windows-10-Disable-Adobe-ReaderDC-Vulnerabilities.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v4+
#>

If (Test-path -Path 'Registry::HKLM\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown')
    {
    #If the key already exists just set the value
    Write-Output "True"
    Set-Itemproperty -Path 'Registry::HKLM\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown' -Name 'bDisableJavaScript' -value '1'
    Set-Itemproperty -Path 'Registry::HKLM\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown' -Name 'bEnableFlash' -value '0'
    Get-ItemProperty -Path 'Registry::HKLM\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown'
    }
    else
    {
     #If the key doesnt exist then the program is not installed and doesnt need rectification
     Write-Output "False"
     }

