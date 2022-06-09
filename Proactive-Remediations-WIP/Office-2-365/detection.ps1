
Try
{
    if (Test-Path -Path C:\logfiles\365AppsUpgrade-Reboot.txt -PathType Leaf)
    {
        #Exit 0 for machine licensed.
        Write-Host "Installed"            
        exit 0
    }
    else 
    {
        #Exit 1 for machine not licensed correctly
        Write-Host "Not Installed"
        exit 1        
    }

}

catch
{
    $errMsg = $_.Exception.Message
    return $errMsg
    exit 1
}