$TpmProtectorID = ((Get-BitLockerVolume -MountPoint c).KeyProtector | Where-Object KeyProtectorType -EQ 'Tpm').KeyProtectorID
Remove-BitLockerKeyProtector -MountPoint c -KeyProtectorId $TpmProtectorID
Restart-Computer -Force