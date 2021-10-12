try {
    $ErrorActionPreference = "Stop"
    $LocalTempDir = $env:TEMP; 
    $ChromeInstaller = "googlechromestandaloneenterprise64.msi"; (new-object System.Net.WebClient).DownloadFile('https://dl.google.com/tag/s/dl/chrome/install/googlechromestandaloneenterprise64.msi', "$LocalTempDir\$ChromeInstaller"); & "$LocalTempDir\$ChromeInstaller" /silent /install; $Process2Monitor = "ChromeInstaller"; Do { $ProcessesFound = Get-Process | Where-Object { $Process2Monitor -contains $_.Name } | Select-Object -ExpandProperty Name; If ($ProcessesFound) { "Still running: $($ProcessesFound -join ', ')" | Write-Host; Start-Sleep -Seconds 2 } else { Remove-Item "$LocalTempDir\$ChromeInstaller" -ErrorAction SilentlyContinue -Verbose } } Until (!$ProcessesFound)
    exit 0
}
catch {
    $errMsg = $_.Exception.Message
    Write-Host $errMsg
    exit 1
}