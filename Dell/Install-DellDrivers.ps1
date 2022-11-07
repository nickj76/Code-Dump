Invoke-Command -ComputerName "MyComputer" -ScriptBlock {    
    $ExitCode = 0             

    #Declare path and arguments
    $DcuCliPath = 'C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe'                              
    $DellCommand = "/applyUpdates -autoSuspendBitLocker=enable -outputLog=C:\Dell_Update.log"
                
    #Verify Dell Command | Update exists
    If (Test-Path -Path $DcuCliPath) {
        $objWMI = Get-WmiObject Win32_ComputerSystem
        Write-Host ("Dell Model [{0}]" -f $objWMI.Model.Trim())

        $serviceName = "DellClientManagementService"
        Write-Host ("Service [{0}] is currently [{1}]" -f $serviceName, (Get-Service $serviceName).Status)
        If ((Get-Service $serviceName).Status -eq 'Stopped') {    
            Start-Service $serviceName
            Write-Host "Service [$serviceName] started"    
        }

        #Update the system with the latest drivers
        Write-Host "Starting Dell Command | Update tool with arguments [$DellCommand] dcu-cli found at [$DcuCliPath]"
        $ExitCode = (Start-Process -FilePath ($DcuCliPath) -ArgumentList ($DellCommand) -PassThru -Wait).ExitCode
        Write-Host ("Dell Command | Update tool finished with ExitCode: [$ExitCode] current Win32 ExitCode: [$LastExitCode] Check log for more information: C:\Dell_Update.log")
    }
}