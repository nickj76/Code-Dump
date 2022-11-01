#set KB using kb followed by the KB number
$KBfind = "KB5020953"

$hotfix1 = Get-HotFix | Select-Object -ExpandProperty HotFixID

#This example determines compliance in KB is installed, but can be altered to meet other purposes
if ($hotfix1 -eq $KBfind)
{
$compliance = "true"
}
else
{
$compliance = "false"
}
$compliance