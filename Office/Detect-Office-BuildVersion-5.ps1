$version = 0
Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Office' -Name | Where-Object {$_ -match '(\d+)\.\d+'} | ForEach-Object {
    $version = [math]::Max([byte]$_, $version)
}
Add-Content -Path C:\NJ\oversion.txt -Value "$env:COMPUTERNAME, $env:USERNAME, $version"
