<#
.SYNOPSIS
   Look up graphpad users in AD

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



# connect to AD
Import-Module activedirectory


foreach ($userline in $usersin)
{
    $outline = $null
    $email = $userline.EMail

    #$aadacc = Get-AzureADUser -searchstring $email
    $adacc = get-aduser -filter 'emailaddress -like "$email"'

    if ($adacc -ne $null)
    {
        #Write-Host $aadacc
        if ($adacc.Enabled -eq $true)
        {
            $outline = $email + "|" + $adacc.DisplayName + "|enabled|N/A"
            Write-Output $outline
        } else {
            $outline = $email + "|" + $adacc.DisplayName + "|disabled|" + $adacc.accountexpirationdate
            Write-Output $outline
        }
    } else {
        $outline = $email + "| |not found|N/A"
        Write-Output $outline
    }


}



