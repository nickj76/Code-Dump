
Try
{
    $computername = (Get-CimInstance -ClassName Win32_ComputerSystem).Name

    if ($computername -like "*UWS*")
    {
        #Exit 0 Machine Name Correct.
        Write-Host "All Ok"            
        exit 0
    }
    else 
    {
        #Exit 1 has been renamed
        Write-Host "Machine has been Renamed"
        exit 1        
    }

}

catch
{
    $errMsg = $_.Exception.Message
    return $errMsg
    exit 1
}