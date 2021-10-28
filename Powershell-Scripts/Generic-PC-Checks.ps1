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
        Unlock AD account
        Reset AD password
        Recreate MSLicensing

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
    [string] $hosts = "",  
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
        Write-Host "`t`t`t18. Unlock AD account" -Fore yellow
        Write-Host "`t`t`t19. Reset AD password" -Fore yellow
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
Get-LoggedOnUser -ComputerName $PCname 
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
[Management.ManagementDateTimeConverter]::ToDateTime( (Get-WmiObject Win32_OperatingSystem -Comp SMSTEST).LastBootUpTime )
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
Get-WmiObject -Class Win32_ComputerSystem -ComputerName $PCname | Select-Object Manufacturer, Model, Name, @{L='RAM-Gb';E={[math]::round($_.TotalPhysicalMemory/1Gb)}}
returnMenu $a;
}
14 {
#Clean Windows Caches
    $objShell = New-Object -ComObject Shell.Application
    $objFolder = $objShell.Namespace(0xA)
    $WinTemp = "c:\Windows\Temp\*"
    
    #1# Remove Temp Files
    write-Host "Removing Temp" -ForegroundColor Green
    Set-Location “C:\Windows\Temp”
    Remove-Item * -Recurse -Force -ErrorAction SilentlyContinue
    
    Set-Location “C:\Windows\Prefetch”
    Remove-Item * -Recurse -Force -ErrorAction SilentlyContinue
    
    Set-Location “C:\Documents and Settings”
    Remove-Item “.\*\Local Settings\temp\*” -Recurse -Force -ErrorAction SilentlyContinue
    
    Set-Location “C:\Users”
    Remove-Item “.\*\Appdata\Local\Temp\*” -Recurse -Force -ErrorAction SilentlyContinue
    
    #2# Empty Recycle Bin #
    write-Host "Emptying Recycle Bin." -ForegroundColor Blue 
    $objFolder.items() | ForEach-Object{ remove-item $_.path -Recurse -Confirm:$false}
    
        #3# Running Disk Clean up Tool 
    write-Host "Running the Windows Disk Clean up Tool" -ForegroundColor White
    cleanmgr /sagerun:1 | out-Null 
    
    $([char]7)
    Start-Sleep 3
    write-Host "Bada Bing! cleanup task complete" -ForegroundColor Yellow 
    Start-Sleep 3
    ##### End of the Script #####
}
15 {
#Free disk space
Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3" -ComputerName $PCname | Select-Object DeviceID, VolumeName, @{L='Free Space';E={($_.freespace/$_.size).ToString("P", $nfi)}}
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