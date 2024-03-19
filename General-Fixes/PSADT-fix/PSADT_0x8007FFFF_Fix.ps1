<#
got tons of 0x8007FFFF (no logged on user) in intune ?? this is due to ServiceUI.exe -Process:explorer.exe

Use this as the install script
#>


$ExplorerIsRunning = Get-Process explorer -ErrorAction SilentlyContinue

if($ExplorerIsRunning) {
    Write-Host "Launching install with ServiceUI"
    & .\ServiceUI.exe -process:explorer.exe Deploy-Application.exe
}
else {
    Write-Host "Launching install without ServiceUI"
    & .\Deploy-Application.exe
}