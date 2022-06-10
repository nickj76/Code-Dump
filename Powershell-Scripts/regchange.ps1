<# 
.SYNOPSIS
   Disable News & Interest Feed on Taskbar

.DESCRIPTION
   Disables News & Interest Feed on Taskbar

.EXAMPLE
   PS C:\> .\Windows-10-Disable-News-Interests-Taskbar.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v4+
#>

$registryPath = "HKCU:\Software\UNIT4\ReportEngine\Login\WebService"
$Name = "DataSource"
$Name2 = "DataSources"
$Auth = "Authenticator"
$value = "https://agresso.surrey.ac.uk/Unit4ERP-reportengine/service.asmx"
$Value2 = "https://agresso.surrey.ac.uk/Unit4ERP-reportengine/service.asmx"
$AuthValue = "AgressoAuthenticator"

$registryPath2 = "HKCU:\Software\UNIT4\ReportEngine\Login\WebService\AgressoAuthenticator"
$Username = "UserName"
$Username2 = "%username%"
$Client = "Client"
$Client2 = "SY" 

 IF(!(Test-Path $registryPath))
{
New-Item -Path $registryPath -Force | Out-Null
New-ItemProperty -Path $registryPath -Name $name -Value $value -Type String -Force | Out-Null}

ELSE {

New-ItemProperty -Path $registryPath -Name $name -Value $value -Type String -Force | Out-Null}

IF(!(Test-Path $registryPath))
{
New-Item -Path $registryPath -Force | Out-Null
New-ItemProperty -Path $registryPath -Name $Name2 -Value $value2 -Type String -Force | Out-Null}

ELSE {

New-ItemProperty -Path $registryPath -Name $Name2 -Value $Value2 -Type String -Force | Out-Null}

IF(!(Test-Path $registryPath))
{
New-Item -Path $registryPath -Force | Out-Null
New-ItemProperty -Path $registryPath -Name $Auth -Value $AuthValue -Type String -Force | Out-Null}

ELSE {

New-ItemProperty -Path $registryPath -Name $Auth -Value $AuthValue -Type String -Force | Out-Null}

IF(!(Test-Path $registryPath2))
{
New-Item -Path $registryPath2 -Force | Out-Null
New-ItemProperty -Path $registryPath2 -Name $Username -Value $Username2 -Type String -Force | Out-Null}

ELSE {

New-ItemProperty -Path $registryPath2-Name $Username -Value $Username2 -Type String -Force | Out-Null}

IF(!(Test-Path $registryPath2))
{
New-Item -Path $registryPath2 -Force | Out-Null
New-ItemProperty -Path $registryPath2 -Name $Client -Value $Client2 -Type String -Force | Out-Null}

ELSE {

New-ItemProperty -Path $registryPath2-Name $Client -Value $Client2 -Type String -Force | Out-Null}