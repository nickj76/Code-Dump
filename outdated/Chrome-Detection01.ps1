$software = "Google Chrome";
$version = "91.0.4472.114";
$installed = $null -ne (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -eq $software })
$installed = $null -ne (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayVersion -eq $version })


If(-Not $installed) {
	Write-Host "'$software $version' NOT is installed.";
} else {
	Write-Host "'$software $version' is installed."
}