Try {
    $AppXStatus = Get-AppxPackage -allusers MicrosoftCorporationII.QuickAssist -ErrorAction Stop
        If ($AppXStatus.status -eq 'OK'){
                Write-Host "Quick Assist is installed"
                Exit 0
            } else {
                Write-Warning "Quick Assist not installed"
                Exit -1
        }
        } Catch [exception]{
            Write-Error "[Error] $($_.Exception.Message)"
    }