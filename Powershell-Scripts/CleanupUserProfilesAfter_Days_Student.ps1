<#
    .SYNOPSIS
    Sets the number of days after which Windows should clean up an inactive profile.
    Deploy through Intune and target SYSTEM (this script will not work under user context)

    .NOTES
    filename: set-CleanupUserProfilesAfterDays.ps1
#>

$maxProfileAgeInDays = 60

try{
    New-Item -Path "HKLM:\Software\Policies\Microsoft\Windows" -Name "System" -Force -ErrorAction SilentlyContinue | Out-Null 
    Write-Output "System key was created or already exists"
    Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\System" -Name 'CleanupProfiles' -Value $maxProfileAgeInDays -Type 'Dword' -Force 
}catch{
    Throw "Warning: Failed to set registry key"
}