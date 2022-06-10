Connect-AzureAD
$usercsv = Import-Csv -Path C:\temp\users.csv #  -Delimiter "," > Is default for this cmdlet
foreach($user in $usercsv)
{
    $upn = $user.UserPrincipalName.Trim()
    $azUser = Get-AzureADUser -Filter "userPrincipalName eq '$upn'"

    if(-not $azUser)
    {
        Write-Warning "$upn could not be found in AzureAD"
        continue
    }

    $azUser
}