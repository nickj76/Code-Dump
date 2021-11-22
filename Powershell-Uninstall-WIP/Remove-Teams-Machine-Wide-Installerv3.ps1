  # Remove Teams Machine-Wide Installer
  Write-Host "Removing Teams Machine-wide Installer" -ForegroundColor Yellow
  
   # Remove Teams Machine-Wide Installer
   Write-Host "Removing Teams Machine-wide Installer" -ForegroundColor Yellow
  
   $MachineWide = Get-CimInstance -Class Win32_Product | Where-Object{$_.Name -eq "Teams Machine-Wide Installer"}
   $MachineWide.Uninstall()

  ## Pause for 30 seconds to allow install to completed.
  Start-Sleep -Seconds 30

  Set-Location -Path 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run\'
  Remove-ItemProperty -Path . -Name "TeamsMachineUninstallerLocalAppData"
  Remove-ItemProperty -Path . -Name "TeamsMachineUninstallerProgramData"