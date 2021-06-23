$registryPath = "HKLM:\\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"

$Name = "EnableFeeds"

$value = "0"

 IF(!(Test-Path $registryPath))

{

New-Item -Path $registryPath -Force | Out-Null

New-ItemProperty -Path $registryPath -Name $name -Value $value -Type DWORD -Force | Out-Null}

ELSE {

New-ItemProperty -Path $registryPath -Name $name -Value $value -Type DWORD -Force | Out-Null}