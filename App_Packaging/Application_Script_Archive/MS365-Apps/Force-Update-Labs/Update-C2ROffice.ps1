# Automated Update of 365Apps
# Find the OfficeC2RClient.exe executable, show the toast notification and start the update
    $Configuration = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" -ErrorAction "SilentlyContinue"
    if (Test-Path -Path "$($Configuration.ClientFolder)\OfficeC2RClient.exe") {
        $params = @{
            FilePath     = "$($Configuration.ClientFolder)\OfficeC2RClient.exe"
            ArgumentList = "/update user"
            Wait         = $true
            PassThru     = $true
        }
        $result = Start-Process @params
        exit $result.ExitCode
    } else {
        Write-Output "OfficeC2RClient.exe not found !"
    }

