Write-Verbose "Checking Google Chrome compliancy..." -Verbose

$ComputerList = Get-Content -Path "$env:USERPROFILE\Desktop\computers.txt"

$InvokeCommandScriptBlock = {

    $Chrome = Get-Package -Name "Google Chrome" -ErrorAction SilentlyContinue

    if ($Chrome) {

        $Installed = "True"
        $Version = $Chrome.Version

        if ($Version -eq "80.0.3987.122") {$Compliant = "True"}
        else {$Compliant = "False"}
    }
    else {

        $Installed = "False"
        $Compliant = "True"
    }
    
    [PSCustomObject]@{
        Installed = $Installed
        Compliant = $Compliant
    }
}


$InvokeCommandParams = @{

    ComputerName = $ComputerList
    ScriptBlock = $InvokeCommandScriptBlock
    ErrorAction = 'SilentlyContinue'
}

$Results = Invoke-Command @InvokeCommandParams

$Results | Select-Object -Property PSComputerName, Installed, Compliant |
Export-Csv -Path "$env:USERPROFILE\Desktop\CheckChrome.csv" -NoTypeInformation