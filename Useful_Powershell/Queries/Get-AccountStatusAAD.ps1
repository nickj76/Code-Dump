<#
.SYNOPSIS
   Look up graphpad users in AAD

.DESCRIPTION

  Inputfile is a csv with one column, header email, followed by a list of email addresses to look up
  Outputs a tab separated list to stdout of email, display name, and enabled or disabled
   

.EXAMPLE
   PS C:\> .\lookup.ps1 -inputfile input.csv -outputfile output.csv -delete
   input.csv containts a list of Grpahpad users, will have the users that are disabled in AAD

.FUNCTIONALITY
   PowerShell v1+
#>


param (
    [Parameter(Mandatory)][string]$inputfile

#    [Parameter(Mandatory)][string]$outputfile
) 


#$null | Set-Content $outputfile
$usersin = Import-Csv $inputfile



# connect to Azure AD
# might need Import-Module AzureAD -UseWindowsPowerShell for powershell 7
Import-Module AzureAD
Connect-AzureAD


foreach ($userline in $usersin)
{
    $outline = $null
    $email = $userline.EMail

    $aadacc = Get-AzureADUser -searchstring $email
    if ($aadacc -ne $null)
    {
        #Write-Host $aadacc
        if ($aadacc.AccountEnabled -eq $true)
        {
            $outline = $email + "|" + $aadacc.DisplayName + "|enabled"
            Write-Output $outline
        } else {
            $outline = $email + "|" + $aadacc.DisplayName + "|disabled"
            Write-Output $outline
        }
    } else {
        $outline = $email + "| |not found"
        Write-Output $outline
    }


}



