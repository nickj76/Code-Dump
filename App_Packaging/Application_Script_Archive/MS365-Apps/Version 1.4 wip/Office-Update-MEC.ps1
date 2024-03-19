$UpdateChannel = "http://officecdn.microsoft.com/pr/55336b82-a18d-4dd6-b5f6-9e5095c314a6"
$CTRConfigurationPath = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
$CDNBaseUrl = Get-ItemProperty -Path $CTRConfigurationPath -Name "CDNBaseUrl" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty "CDNBaseUrl"
if ($null -ne $CDNBaseUrl) {
    if ($CDNBaseUrl -notmatch $UpdateChannel) {
        # Set new update channel
        Set-ItemProperty -Path $CTRConfigurationPath -Name "CDNBaseUrl" -Value $UpdateChannel -Force
    }
}