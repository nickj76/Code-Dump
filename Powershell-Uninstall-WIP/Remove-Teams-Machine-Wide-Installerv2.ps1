  # Remove Teams Machine-Wide Installer
  Write-Host "Removing Teams Machine-wide Installer" -ForegroundColor Yellow
  
  Get-CimInstance -Classname Win32_Product | Where-Object Name -Match ‘Teams Machine-Wide Installer’ | Invoke-CimMethod -MethodName UnInstall

  ## Pause for 30 seconds to allow install to completed.
  Start-Sleep -Seconds 30

  Set-Location -Path 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run\'
  Remove-ItemProperty -Path . -Name "TeamsMachineUninstallerLocalAppData"
  Remove-ItemProperty -Path . -Name "TeamsMachineUninstallerProgramData"