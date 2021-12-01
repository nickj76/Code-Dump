Add-Type -AssemblyName PresentationCore,PresentationFramework
$ButtonType = [System.Windows.MessageBoxButton]::YesNoCancel
$MessageIcon = [System.Windows.MessageBoxImage]::Error
$MessageBody = "Microsoft Office Requires and Upgrade"
$MessageTitle = "Microsoft 365 Apps for Enterprise"
$Result = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)
Write-Host "Your choice is $Result"