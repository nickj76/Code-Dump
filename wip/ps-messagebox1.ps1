
Add-Type –AssemblyName PresentationCore,PresentationFramework
$ButtonType = [System.Windows.MessageBoxButton]::YesNoCancel
$MessageIcon = [System.Windows.MessageBoxImage]::Exclamation
$MessageBody = "This computer has not checked in with the university of surrey for more than 90 days, please return the computer to IT services."
$MessageTitle = "Unknown Computer"
$ButtonType2 = [System.Windows.MessageBoxButton]::OK
$MessageIcon2 = [System.Windows.MessageBoxImage]::Error
$MessageBody2 = "The system will not operate correctly until a restart is completed. Remember to restart ASAP!"
$MessageTitle2 = "WARNING!!"
$Choice = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)
Else {
# Restart-Computer
}