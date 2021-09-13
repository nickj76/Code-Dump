$Path = "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run\"
$Name = "TeamsMachineUninstallerProgramData"

Try {
    $Registry = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop | Select-Object -ExpandProperty $Name
    If ($Registry -eq $Name){
        Write-Warning "Not Compliant"
        Exit 1
    } 
    Write-Output "Compliant"
    Exit 0
} 
Catch {
    Write-Warning "Not Compliant"
    Exit 1
}