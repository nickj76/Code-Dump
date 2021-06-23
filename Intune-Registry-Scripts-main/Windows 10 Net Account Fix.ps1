<#
Test configuration for solving the account problems in net
Original source code here

https://github.com/TristanvanOnselen/WorkplaceAsCode/blob/master/ProActive_Remediation/Remediate_WorkplaceHardening.ps1



#>       
        
        
        
try
    {        
        #Fix the Accounts issue in MSDE Security portal
        net accounts /lockoutthreshold:10
        net accounts /minpwlen:14
        net accounts /uniquepw:24
        }

catch{
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
    }