$MYTEXT = 'base64stringhere'
$DECODED = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($MYTEXT)) 
Write-Output $DECODED | Out-File "C:\temp\nj.msi" -NoClobber