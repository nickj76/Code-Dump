# Obtain UPN from Email address

# for each value in the "EmailAddress" Column
(Import-Csv "C:\Temp\Users.csv").EmailAddress | ForEach-Object {
    # if the user exists in Azure AD
    if($azusr = Get-AzureADUser -Filter "mail eq '$_'") {
        # output this object
        [pscustomobject]@{
            UserName           = $azusr.DisplayName
            UserPrincipalName  = $azusr.UserPrincipalName
            PrimarySmtpAddress = $azusr.Mail
            AliasSmtpAddresses = $azusr.ProxyAddresses -clike 'smtp:*' -replace 'smtp:' -join ','
            UserId             = $azusr.ObjectId
        }
    }
 } | Export-CSV "C:\Temp\output.csv" -NoTypeInformation -Encoding UTF8