Add-Type -AssemblyName PresentationCore,PresentationFramework
$msgBody = "This Computer has not checked in for over 90 days and has now been locked, please contact ITServicedesk@surrey.ac.uk to get the computer unlocked"
$msgTitle = "Unknown Computer"
$msgButton = 'ok'
$msgImage = 'Question'
$Result = [System.Windows.MessageBox]::Show($msgBody,$msgTitle,$msgButton,$msgImage)
