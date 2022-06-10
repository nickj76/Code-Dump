$Result = @()
 
$AllUsers = Import-Csv "C:\Temp\Users.csv"

# Get all Azure AD Users with required properties
# $AllUsers = Get-AzureADUser -All $true | Select-Object DisplayName,UserPrincipalName,Mail,ProxyAddresses,ObjectId
 
ForEach ($User in $AllUsers)
{
    Get-AzureADUser -Filter "startswith(Mail,'$Users')" | Select-Object DisplayName,UserPrincipalName,Mail,ObjectId
 
# Add user detail to $Result array one by one
$Result += New-Object PSObject -property $([ordered]@{
UserName = $User.DisplayName
UserPrincipalName = $User.UserPrincipalName
PrimarySmtpAddress = $User.Mail
AliasSmtpAddresses = ($User.ProxyAddresses | Where-Object {$_ -clike 'smtp:*'} | ForEach-Object {$_ -replace 'smtp:',''}) -join ','
UserId= $User.ObjectId
})
}
# Export Users Details to CSV file
$Result | Export-CSV "C:\Temp\output.csv" -NoTypeInformation -Encoding UTF8