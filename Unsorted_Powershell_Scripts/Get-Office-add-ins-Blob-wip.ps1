<<<<<<< HEAD
function Check-FileOpen {
    param (
    [parameter(Mandatory=$true)]
    [string]$Path
    )
    
    $oFile = New-Object System.IO.FileInfo $Path
    if ((Test-Path -Path $Path) -eq $false)
    {
    $false
    return
    }
    
    try
    {
    $oStream = $oFile.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    if ($oStream)
    {
    
    $oStream.Close()
    }
    $false
    }
    
    catch
    {
    # file is locked by a process.
    $true
    }
    }
    
    $searchScopes = 
    "HKLM:\SOFTWARE\Microsoft\Office\Outlook\Addins",
    "HKCU:\SOFTWARE\Microsoft\Office\Outlook\Addins",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Office\Outlook\Addins",
    "HKLM:\SOFTWARE\Microsoft\Office\Word\Addins",
    "HKCU:\SOFTWARE\Microsoft\Office\Word\Addins",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Office\Word\Addins",
    "HKLM:\SOFTWARE\Microsoft\Office\Excel\Addins",
    "HKCU:\SOFTWARE\Microsoft\Office\Excel\Addins",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Office\Excel\Addins",
    "HKLM:\SOFTWARE\Microsoft\Office\MS Project\Addins",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Office\MS Project\Addins",
    "HKCU:\SOFTWARE\Microsoft\Office\PowerPoint\Addins",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Office\PowerPoint\Addins"

    $test = $searchScopes | ForEach-Object {Get-ChildItem -Path $_ | ForEach-Object {Get-ItemProperty -Path $_.PSPath} | Select-Object @{n="Name";e={Split-Path $_.PSPath -leaf}},FriendlyName,Description} | Sort-Object -Unique -Property name
    
    foreach ($tst in $test){
    $test | Add-Member -Name 'Computer Name' -Type NoteProperty -Value $env:COMPUTERNAME
    }
    
    $path = "C:\temp"
    If(!(test-path $path))
    {
          New-Item -ItemType Directory -Force -Path $path
    }
    
    write-host $test
    while ((Check-FileOpen -Path "C:\Temp\$env:COMPUTERNAME-OfficeAddins.csv")){
    Start-Sleep -s 15
    Write-Host "File in Use"
    }
    
    Write-Host "File Not in Use"
    $test | export-csv -Path C:\Temp\$env:COMPUTERNAME-OfficeAddins.csv -NoTypeInformation -Append

=======
function Check-FileOpen {
    param (
    [parameter(Mandatory=$true)]
    [string]$Path
    )
    
    $oFile = New-Object System.IO.FileInfo $Path
    if ((Test-Path -Path $Path) -eq $false)
    {
    $false
    return
    }
    
    try
    {
    $oStream = $oFile.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    if ($oStream)
    {
    
    $oStream.Close()
    }
    $false
    }
    
    catch
    {
    # file is locked by a process.
    $true
    }
    }
    
    $searchScopes = 
    "HKLM:\SOFTWARE\Microsoft\Office\Outlook\Addins",
    "HKCU:\SOFTWARE\Microsoft\Office\Outlook\Addins",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Office\Outlook\Addins",
    "HKLM:\SOFTWARE\Microsoft\Office\Word\Addins",
    "HKCU:\SOFTWARE\Microsoft\Office\Word\Addins",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Office\Word\Addins",
    "HKLM:\SOFTWARE\Microsoft\Office\Excel\Addins",
    "HKCU:\SOFTWARE\Microsoft\Office\Excel\Addins",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Office\Excel\Addins",
    "HKLM:\SOFTWARE\Microsoft\Office\MS Project\Addins",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Office\MS Project\Addins",
    "HKCU:\SOFTWARE\Microsoft\Office\PowerPoint\Addins",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Office\PowerPoint\Addins"

    $test = $searchScopes | ForEach-Object {Get-ChildItem -Path $_ | ForEach-Object {Get-ItemProperty -Path $_.PSPath} | Select-Object @{n="Name";e={Split-Path $_.PSPath -leaf}},FriendlyName,Description} | Sort-Object -Unique -Property name
    
    foreach ($tst in $test){
    $test | Add-Member -Name 'Computer Name' -Type NoteProperty -Value $env:COMPUTERNAME
    }
    
    $path = "C:\temp"
    If(!(test-path $path))
    {
          New-Item -ItemType Directory -Force -Path $path
    }
    
    write-host $test
    while ((Check-FileOpen -Path "C:\Temp\$env:COMPUTERNAME-OfficeAddins.csv")){
    Start-Sleep -s 15
    Write-Host "File in Use"
    }
    
    Write-Host "File Not in Use"
    $test | export-csv -Path C:\Temp\$env:COMPUTERNAME-OfficeAddins.csv -NoTypeInformation -Append

>>>>>>> 6fc2d1d688fccab7c433899542cae16e993b985f
    