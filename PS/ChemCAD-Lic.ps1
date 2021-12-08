<#
.SYNOPSIS
    Modify the registry for the CURRENT user when coming from SYSTEM context.
 
.DESCRIPTION
    add ChemCAD 7 License server details to Registry.   
#> 
function Get-CurrentUser() {
    try { 
        $currentUser = (Get-Process -IncludeUserName -Name explorer | Select-Object -First 1 | Select-Object -ExpandProperty UserName).Split("\")[1] 
    } 
    catch { 
        Write-Output "Failed to get current user." 
    }
    if (-NOT[string]::IsNullOrEmpty($currentUser)) {
        Write-Output $currentUser
    }
}
function Get-UserSID([string]$fCurrentUser) {
    try {
        $user = New-Object System.Security.Principal.NTAccount($fcurrentUser) 
        $sid = $user.Translate([System.Security.Principal.SecurityIdentifier]) 
    }
    catch { 
        Write-Output "Failed to get current user SID."   
    }
    if (-NOT[string]::IsNullOrEmpty($sid)) {
        Write-Output $sid.Value
    }
}
$currentUser = Get-CurrentUser
$currentUserSID = Get-UserSID $currentUser
$userRegistryPath = "Registry::HKEY_USERS\$($currentUserSID)\SOFTWARE\Chemstations\CHEMCAD 7\Authorization\specified_servers"
New-Item -Path $userRegistryPath -ItemType RegistryKey -Force | Out-Null
$userRegistryPath1 = "Registry::HKEY_USERS\$($currentUserSID)\SOFTWARE\Chemstations\CHEMCAD 7\Authorization\specified_servers\dongle02.surrey.ac.uk"
New-Item -Path $userRegistryPath1 -ItemType RegistryKey -Force | Out-Null
$userRegistryPath2 = "Registry::HKEY_USERS\$($currentUserSID)\SOFTWARE\Chemstations\CHEMCAD 7\Authorization\specified_servers\dongle02.surrey.ac.uk\Superpro"
New-Item -Path $userRegistryPath2 -ItemType RegistryKey -Force | Out-Null

# Create Detection Method. 
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\Chemcad7-Reg.txt"