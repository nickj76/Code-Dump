$MYTEXT = '<Configuration>
<!--Uninstall complete Office 365-->
<Display Level="None" AcceptEULA="TRUE" />
<Logging Level="Standard" Path="%temp%" />
<Remove All="TRUE" />
</Configuration>'
$ENCODED = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($MYTEXT))
Write-Output $ENCODED