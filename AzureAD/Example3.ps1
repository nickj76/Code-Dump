$UserCSV = Import-Csv -Path "C:\Temp\Users.csv"

foreach($email in $UserCSV)
{
        Get-AzureADUser -ObjectID $email.EmailAddress | Select-Object DisplayName,UserPrincipalName,Department 
     
}

_______________



$User = "n.jenkins@surrey.ac.uk"
Get-AzureADUser -Filter "startswith(Mail,'$User')" | Select-Object DisplayName,UserPrincipalName,Mail,ObjectId

_________________


$AllUsers = Import-Csv -Path "C:\Temp\Users.csv"

ForEach ($User in $AllUsers) {
Get-AzureADUser -Filter "startswith(Mail,'$User')" | Select-Object DisplayName,UserPrincipalName,Mail,ProxyAddresses,ObjectId
}

________________________
