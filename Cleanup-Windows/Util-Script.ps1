<#
.SYNOPSIS
    Runs generic PC checks on a machine
.DESCRIPTION
    A set of generic PC checks for machine troubleshooting;
        Restart Spooler
        GPUpdate
        Get Logged in User
        Get PC OU
        Get User OU
        Reboot machine
        Shut Down Machine
        Logoff User
        Display PC Uptime
        WOL
        List installed apps
        Get user group membership
        Show PC Info
        Clean up Windows
        List free disk space
        List services and their status
        Open explorer to C:\

.INPUTS
PC Name
.OUTPUTS
Verbose output
.NOTES
  Version:        1.0
  
.EXAMPLE
generic-pc-checks.ps1 -Hosts "PC-Name"
  
#>

param (   
    [Parameter(Mandatory=$True)]
    [string] $hosts = "localhost",  
    [switch] $addcomputer = $false,  
    [switch] $removecomputer = $false,  
    [string] $log = "")  
Import-Module ac*  -ErrorAction SilentlyContinue

function Get-LoggedOnUser { 
#Requires -Version 2.0             
[CmdletBinding()]             
 Param              
   (                        
    [Parameter(Mandatory=$true, 
               Position=0,                           
               ValueFromPipeline=$true,             
               ValueFromPipelineByPropertyName=$true)]             
    [String[]]$ComputerName 
   )#End Param 

Begin             
{             
 Write-Host "`n Checking Users . . . " 
 $i = 0             
}#Begin           
Process             
{ 
    $ComputerName | Foreach-object { 
    $Computer = $_ 
    try 
        { 
            $processinfo = @(Get-WmiObject -class win32_process -ComputerName $Computer -EA "Stop") 
                if ($processinfo) 
                {     
                    $processinfo | Foreach-Object {$_.GetOwner().User} |  
                    Where-Object {$_ -ne "NETWORK SERVICE" -and $_ -ne "LOCAL SERVICE" -and $_ -ne "SYSTEM"} | 
                    Sort-Object -Unique | 
                    ForEach-Object { New-Object psobject -Property @{Computer=$Computer;LoggedOn=$_} } |  
                    Select-Object Computer,LoggedOn 
                }#If 
        } 
    catch 
        { 
            "Cannot find any processes running on $computer" | Out-Host 
        } 
     }#Forech-object(Comptuters)        

}#Process 
End 
{ 

}#End 

}#Get-LoggedOnUser 

function Send-WOL 
{ 
<#  
  .SYNOPSIS   
    Send a WOL packet to a broadcast address 
  .PARAMETER mac 
   The MAC address of the device that need to wake up 
  .PARAMETER ip 
   The IP address where the WOL packet will be sent to 
  .EXAMPLE  
   Send-WOL -mac 00:11:32:21:2D:11 -ip 192.168.8.255  
  .EXAMPLE  
   Send-WOL -mac 00:11:32:21:2D:11  
 
#> 

[CmdletBinding()] 
param( 
[Parameter(Mandatory=$True,Position=1)] 
[string]$mac, 
[string]$ip="255.255.255.255",  
[int]$port=9 
) 
$broadcast = [Net.IPAddress]::Parse($ip) 

$mac=(($mac.replace(":","")).replace("-","")).replace(".","") 
$target=0,2,4,6,8,10 | ForEach-Object {[convert]::ToByte($mac.substring($_,2),16)} 
$packet = (,[byte]255 * 6) + ($target * 16) 

$UDPclient = new-Object System.Net.Sockets.UdpClient 
$UDPclient.Connect($broadcast,$port) 
[void]$UDPclient.Send($packet, 102)  

} 
$PCname = $hosts
if (test-Connection -ComputerName $PCname -quiet) {
function mainMenu()
{
		Write-Host "`n`t=============================================" -ForegroundColor Magenta
        Write-Host "`t||                  MAIN                   ||" -ForegroundColor Magenta
        Write-Host "`t||                  MENU                   ||" -ForegroundColor Magenta
        Write-Host "`t=============================================`n" -ForegroundColor Magenta
		Write-Host "`t`tPlease select the tool you require`n" -Fore green
		Write-Host "`t`t`t1. Restart Spooler" -Fore yellow
        Write-Host "`t`t`t2. GPUpdate" -Fore yellow
        Write-Host "`t`t`t3. Get Logged in User" -Fore yellow
        Write-Host "`t`t`t4. Get PC OU" -Fore yellow
        Write-Host "`t`t`t5. Get User OU" -Fore yellow
        Write-Host "`t`t`t6. Reboot machine" -Fore yellow
        Write-Host "`t`t`t7. Shut Down Machine" -Fore yellow
        Write-Host "`t`t`t8. Logoff User" -Fore yellow
        Write-Host "`t`t`t9. Display PC Uptime" -Fore yellow
        Write-Host "`t`t`t10. WOL" -Fore yellow
		Write-Host "`t`t`t11. List installed apps" -Fore yellow
        Write-Host "`t`t`t12. Get user group membership" -Fore yellow
        Write-Host "`t`t`t13. Show PC Info" -Fore yellow
        Write-Host "`t`t`t14. Clean up Windows" -Fore yellow
        Write-Host "`t`t`t15. List free disk space" -Fore yellow
        Write-Host "`t`t`t16. List services and their status" -Fore yellow
        Write-Host "`t`t`t17. Open explorer to C:\" -Fore yellow
       # Write-Host "`t`t`t18. Unlock AD account" -Fore yellow
       # Write-Host "`t`t`t19. Reset AD password" -Fore yellow
        Write-Host "`t`t`t20. Recreate MSLicensing" -Fore yellow
        Write-Host "`t`t`tType quit to close" -Fore yellow

}

function returnMenu($option)
{

	Write-Host "Press any key to return to the main menu.";
	$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown");
}

do
{
	mainMenu;
$a = Read-Host "`t`tEnter Menu Option Number"
switch ($a)
{
1 {
#Restart Spooler
Restart-Service -InputObject $(Get-Service -Computer $PCname -Name spooler)
write-host "Spooler Restarted"
returnMenu $a;
}
2 {#GPUpdate
Invoke-GPUpdate -Computer $PCname -Force }

3 {
#Find logged in user
Get-WMIObject -class Win32_ComputerSystem | Select-Object username 
returnMenu $a;}
4 {
#Check PC OU
Get-ADComputer -Identity $PCname | Select-Object DistinguishedName
returnMenu $a;
}
5 {
#Check User OU
$usercheck = Read-Host "Enter Username"
Get-ADUser -Identity $usercheck | Select-Object DistinguishedName
returnMenu $a;
}
6 {
#Reboot
restart-computer $PCname -Force
returnMenu $a; }
7 {
#ShutDown
stop-computer $PCname -Force
returnMenu $a;
}
8 {
#Logoff user
(Get-WmiObject win32_operatingsystem -ComputerName $PCname ).Win32Shutdown(4)
returnMenu $a;
}
9 {
#System Uptime
$bootuptime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
$CurrentDate = Get-Date
$uptime = $CurrentDate - $bootuptime
$uptime
returnMenu $a;
}
10 {
#WOL
$colItems = Get-WmiObject -Class "Win32_NetworkAdapterConfiguration" -ComputerName $PCname -Filter "IpEnabled = TRUE"
ForEach ($objItem in $colItems)
{
    $IPa = $objItem.IpAddress[0]
    $Maca = $objItem.MacAddress
}
Send-WOL -mac $Maca -ip $IPa
returnMenu $a;
}
11 {
#List apps
get-wmiobject -class win32_product -Impersonation 3 -ComputerName $PCname | select-object -property name
returnMenu $a;
}
12 {
#Get user group membership
$username = Read-Host 'What username?'
(GET-ADUSER –Identity $username –Properties MemberOf | Select-Object MemberOf).MemberOf | get-adgroup | Select-Object Name
returnMenu $a;
}
13 {
#Show PC make, model, name and RAM
Get-WmiObject win32_baseboard; Get-WmiObject Win32_Bios; Get-WmiObject win32_physicalmemory | Select-Object Manufacturer,Banklabel,Configuredclockspeed,Devicelocator,Capacity,Serialnumber; Get-ComputerInfo OSName, OsArchitecture; Get-WmiObject -class win32_quickfixengineering; Get-Disk | Get-StorageReliabilityCounter | Select-Object -Property “*”; Get-CimInstance Win32_OperatingSystem
returnMenu $a;
}
14 {
#Clean Windows Caches
    ## Stops the windows update service so that c:\windows\softwaredistribution can be cleaned up
    Get-Service -Name wuauserv | Stop-Service -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Verbose

    ## Deletes the contents of windows software distribution.
    Get-ChildItem "C:\Windows\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -recurse -ErrorAction SilentlyContinue -Verbose
    Write-Host "The Contents of Windows SoftwareDistribution have been removed successfully!                      " -NoNewline -ForegroundColor Green
    Write-Host "[DONE]" -ForegroundColor Green -BackgroundColor Black

    ## Deletes the contents of the Windows Temp folder.
    Get-ChildItem "C:\Windows\Temp\*" -Recurse -Force -Verbose -ErrorAction SilentlyContinue |
    Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays( - $DaysToDelete)) } | Remove-Item -force -recurse -ErrorAction SilentlyContinue -Verbose
    Write-host "The Contents of Windows Temp have been removed successfully!                                      " -NoNewline -ForegroundColor Green
    Write-Host "[DONE]" -ForegroundColor Green -BackgroundColor Black

    ## Removes *.log from C:\windows\CBS
    if(Test-Path C:\Windows\logs\CBS\){
        Get-ChildItem "C:\Windows\logs\CBS\*.log" -Recurse -Force -ErrorAction SilentlyContinue |
        remove-item -force -recurse -ErrorAction SilentlyContinue -Verbose
        Write-Host "All CBS logs have been removed successfully!                                                      " -NoNewline -ForegroundColor Green
        Write-Host "[DONE]" -ForegroundColor Green -BackgroundColor Black
        } else {
            Write-Host "C:\inetpub\logs\LogFiles\ does not exist, there is nothing to cleanup.                         " -NoNewline -ForegroundColor DarkGray
            Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
        }

    ## Removes C:\Config.Msi
    if (test-path C:\Config.Msi){
        remove-item -Path C:\Config.Msi -force -recurse -Verbose -ErrorAction SilentlyContinue
    } else {
        Write-Host "C:\Config.Msi does not exist, there is nothing to cleanup.                                        " -NoNewline -ForegroundColor DarkGray
        Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Removes c:\Intel
    if (test-path c:\Intel){
        remove-item -Path c:\Intel -force -recurse -Verbose -ErrorAction SilentlyContinue
    } else {
        Write-Host "c:\Intel does not exist, there is nothing to cleanup.                                             " -NoNewline -ForegroundColor DarkGray
        Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Removes c:\PerfLogs
    if (test-path c:\PerfLogs){
        remove-item -Path c:\PerfLogs -force -recurse -Verbose -ErrorAction SilentlyContinue
    } else {
        Write-Host "c:\PerfLogs does not exist, there is nothing to cleanup.                                          " -NoNewline -ForegroundColor DarkGray
        Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Removes $env:windir\memory.dmp
    if (test-path $env:windir\memory.dmp){
        remove-item $env:windir\memory.dmp -force -Verbose -ErrorAction SilentlyContinue
    } else {
        Write-Host "C:\Windows\memory.dmp does not exist, there is nothing to cleanup.                                " -NoNewline -ForegroundColor DarkGray
        Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Removes rouge folders
    Write-host "Deleting Rouge folders                                                                            " -NoNewline -ForegroundColor Green
    Write-Host "[DONE]" -ForegroundColor Green -BackgroundColor Black

    ## Removes Windows Error Reporting files
    if (test-path C:\ProgramData\Microsoft\Windows\WER){
        Get-ChildItem -Path C:\ProgramData\Microsoft\Windows\WER -Recurse | Remove-Item -force -recurse -Verbose -ErrorAction SilentlyContinue
            Write-host "Deleting Windows Error Reporting files                                                            " -NoNewline -ForegroundColor Green
            Write-Host "[DONE]" -ForegroundColor Green -BackgroundColor Black
        } else {
            Write-Host "C:\ProgramData\Microsoft\Windows\WER does not exist, there is nothing to cleanup.            " -NoNewline -ForegroundColor DarkGray
            Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

## Removes System and User Temp Files - lots of access denied will occur.
    ## Cleans up c:\windows\temp
    if (Test-Path $env:windir\Temp\) {
        Remove-Item -Path "$env:windir\Temp\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "C:\Windows\Temp does not exist, there is nothing to cleanup.                                 " -NoNewline -ForegroundColor DarkGray
            Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up minidump
    if (Test-Path $env:windir\minidump\) {
        Remove-Item -Path "$env:windir\minidump\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "$env:windir\minidump\ does not exist, there is nothing to cleanup.                           " -NoNewline -ForegroundColor DarkGray
            Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up prefetch
    if (Test-Path $env:windir\Prefetch\) {
        Remove-Item -Path "$env:windir\Prefetch\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "$env:windir\Prefetch\ does not exist, there is nothing to cleanup.                           " -NoNewline -ForegroundColor DarkGray
            Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up each users temp folder
    if (Test-Path "C:\Users\*\AppData\Local\Temp\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Temp\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "C:\Users\*\AppData\Local\Temp\ does not exist, there is nothing to cleanup.                  " -NoNewline -ForegroundColor DarkGray
            Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up all users windows error reporting
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\WER\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\WER\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "C:\ProgramData\Microsoft\Windows\WER does not exist, there is nothing to cleanup.            " -NoNewline -ForegroundColor DarkGray
            Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up users temporary internet files
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "C:\Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\ does not exist.              " -NoNewline -ForegroundColor DarkGray
            Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up Internet Explorer cache
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatCache\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatCache\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatCache\ does not exist.                         " -NoNewline -ForegroundColor DarkGray
            Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up Internet Explorer cache
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatUaCache\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatUaCache\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatUaCache\ does not exist.                       " -NoNewline -ForegroundColor DarkGray
            Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up Internet Explorer download history
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\IEDownloadHistory\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\IEDownloadHistory\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "C:\Users\*\AppData\Local\Microsoft\Windows\IEDownloadHistory\ does not exist.                     " -NoNewline -ForegroundColor DarkGray
            Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up Internet Cache
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\INetCache\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\INetCache\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "C:\Users\*\AppData\Local\Microsoft\Windows\INetCache\ does not exist.                             " -NoNewline -ForegroundColor DarkGray
            Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up Internet Cookies
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\INetCookies\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\INetCookies\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "C:\Users\*\AppData\Local\Microsoft\Windows\INetCookies\ does not exist.                           " -NoNewline -ForegroundColor DarkGray
            Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up terminal server cache
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Terminal Server Client\Cache\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Terminal Server Client\Cache\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "C:\Users\*\AppData\Local\Microsoft\Terminal Server Client\Cache\ does not exist.                  " -NoNewline -ForegroundColor DarkGray
            Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    Write-host "Removing System and User Temp Files                                                               " -NoNewline -ForegroundColor Green
    Write-Host "[DONE]" -ForegroundColor Green -BackgroundColor Black

    ## Removes the hidden recycling bin.
    if (Test-path 'C:\$Recycle.Bin'){
        Remove-Item 'C:\$Recycle.Bin' -Recurse -Force -Verbose -ErrorAction SilentlyContinue
    } else {
        Write-Host "C:\`$Recycle.Bin does not exist, there is nothing to cleanup.                                      " -NoNewline -ForegroundColor DarkGray
        Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

## Checks the version of PowerShell
    ## If PowerShell version 4 or below is installed the following will process
    if ($PSVersionTable.PSVersion.Major -le 4) {

        ## Empties the recycling bin, the desktop recyling bin
        $Recycler = (New-Object -ComObject Shell.Application).NameSpace(0xa)
        $Recycler.items() | ForEach-Object { 
            ## If PowerShell version 4 or bewlow is installed the following will process
            Remove-Item -Include $_.path -Force -Recurse -Verbose
            Write-Host "The recycling bin has been cleaned up successfully!                                        " -NoNewline -ForegroundColor Green
            Write-Host "[DONE]" -ForegroundColor Green -BackgroundColor Black
        }
    } elseif ($PSVersionTable.PSVersion.Major -ge 5) {
         ## If PowerShell version 5 is running on the machine the following will process
         Clear-RecycleBin -DriveLetter C:\ -Force -Verbose
         Write-Host "The recycling bin has been cleaned up successfully!                                               " -NoNewline -ForegroundColor Green
         Write-Host "[DONE]" -ForegroundColor Green -BackgroundColor Black
    }

    # Empty Recycle Bin #
    write-Host "Emptying Recycle Bin." -ForegroundColor Blue 
    $objFolder.items() | ForEach-Object{ remove-item $_.path -Recurse -Confirm:$false}

    # Running Disk Clean up Tool 
    write-Host "Running the Windows Disk Clean up Tool" -ForegroundColor White
    cleanmgr /sagerun:1 | out-Null 

    $([char]7)
    Start-Sleep 3
    write-Host "Bada Bing! cleanup task complete" -ForegroundColor Yellow 
    Start-Sleep 3

    # Turns errors back on
    $ErrorActionPreference = "Continue"

    # Restarts wuauserv
    Get-Service -Name wuauserv | Start-Service -ErrorAction SilentlyContinue

    ##### End of the Script #####
}
15 {
#Free disk space
(Get-CimInstance -ClassName Win32_LogicalDisk | Select-Object -Property DeviceID,@{'Name' = 'FreeSpace (GB)'; Expression= { [int]($_.FreeSpace / 1GB) }} | Measure-Object -Property 'FreeSpace (GB)' -Sum).Sum
returnMenu $a;
}
16 {
#Get running services
Get-WmiObject -Class Win32_Service -ComputerName PBRN7RZ | Format-Table -Property StartMode, State, Name,DisplayName -AutoSize -Wrap
returnMenu $a;
}
 17 {
 #Open windows explorer
 $filePath2 = "\\"+$Pcname
$filePath = $filePath2+"\c$\"
Invoke-Item $filePath
returnMenu $a;
 }
 18 {
 #Unlock AD account
 $username = Read-Host 'What username?'
Unlock-ADAccount -Identity $username 
returnMenu $a;
 }
19 {
#Reset password
$username = Read-Host 'What username?'
Set-ADAccountPassword -Identity $username -Reset 
returnMenu $a;
}
20 {
#MSLicensing
$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $PCname)

# connect to the needed key :
$regKey= $reg.OpenSubKey("SOFTWARE\\Microsoft",$true).DeleteSubKeyTree("MSLicensing")
$regKey= $reg.OpenSubKey("SOFTWARE\\Microsoft",$true).CreateSubKey("MSLicensing")
$regKey.Close()

 & c:\labscript\SetACL.exe -on "\\$PCname\hklm\software\microsoft\MSLicensing" -ot reg -actn ace -ace "n:Users;p:full"
 returnMenu $a;
 }
}

} until ($a -eq "quit");

Clear-Host;
}
     else {
     write-host "PC OFFLINE"
     }