$regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client\'
if ((Test-Path -Path $regPath)) {
    Write-Host "TLS 1.2 Key Present"
    exit 1
}
else {
    Write-Host "TLS 1.2 Not Present"
    exit 0
}