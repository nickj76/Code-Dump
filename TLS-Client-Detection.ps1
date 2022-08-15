$key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client\'
if (Test-Path $key) {
  $TLS12 = Get-ItemProperty $key
  if ($TLS12.DisabledByDefault -ne 0 -or $TLS12.Enabled -eq 0) {
    Write-Host "TLS 1.2 Not Enabled. "
    Exit 0
}else{
    Write-Host "TLS 1.2 Enabled"
    Exit 1
}
} 