#region Setup
Set-Location $PSScriptRoot
Remove-Module PSScriptMenuGui -ErrorAction SilentlyContinue
try {
    Import-Module PSScriptMenuGui -ErrorAction Stop
}
catch {
    Write-Warning $_
    Write-Verbose 'Attempting to import from parent directory...' -Verbose
    Import-Module '..\'
}
#endregion

$params = @{
    csvPath = '.\data.csv'
    windowTitle = 'Fix issues with my computer'
    buttonForegroundColor = 'Azure'
    buttonBackgroundColor = '#C00077'
    iconPath = '.\Fixmypc.ico'
    hideConsole = $true
    noExit = $true
    Verbose = $true
}
Show-ScriptMenuGui @params