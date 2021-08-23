<# 
.SYNOPSIS
   Download & Install Latest Version of Mozilla Firefox(x64).

.DESCRIPTION
   Downloads & Installs Latest Version of Mozilla Firefox(x64). 
   
.EXAMPLE
   PS C:\> .\Windows-Install-Firefox-latest.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v4+
#>
function get-LatestFirefoxURL {
    [cmdletbinding()]
    [outputtype([String])]
    param(
        [ValidateSet("bn-BD","bn-IN","en-CA","en-GB","en-ZA","es-AR","es-CL","es-ES","es-MX")][string]$culture = "en-GB",
        [ValidateSet("win32","win64")][string]$architecture="win64"
    
    )
    
    # JSON that provide details on Firefox versions
    $uriSource = "https://product-details.mozilla.org/1.0/firefox_versions.json"
    
    # Read the JSON and convert to a PowerShell object
    $firefoxVersions = (Invoke-WebRequest -uri $uriSource).Content | ConvertFrom-Json
    
    $VersionURL = "https://download-installer.cdn.mozilla.net/pub/firefox/releases/$($firefoxVersions.LATEST_FIREFOX_VERSION)/$($architecture)/$($culture)/Firefox%20Setup%20$($firefoxVersions.LATEST_FIREFOX_VERSION).exe"
    Write-Output $VersionURL
    }
    
    function get-LatestFirefoxVersion {
    [cmdletbinding()]
    [outputtype([String])]
    param(
        [ValidateSet("bn-BD","bn-IN","en-CA","en-GB","en-ZA","es-AR","es-CL","es-ES","es-MX")][string]$culture = "en-GB",
        [ValidateSet("win32","win64")][string]$architecture="win64"
    
    )
    
    # JSON that provide details on Firefox versions
    $uriSource = "https://product-details.mozilla.org/1.0/firefox_versions.json"
    
    # Read the JSON and convert to a PowerShell object
    $firefoxVersions = (Invoke-WebRequest -uri $uriSource).Content | ConvertFrom-Json
    
    $Version = [Version]$firefoxVersions.LATEST_FIREFOX_VERSION.replace("LATEST_FIREFOX_VERSION","")
    Write-Output $Version
    }
    
    get-LatestFirefoxURL
    get-LatestFirefoxVersion
       
    Write-Verbose "Setting Arguments" -Verbose
    $StartDTM = (Get-Date)
    
    $Vendor = "Mozilla"
    $Product = "FireFox"
    $Version = "$(get-LatestFirefoxVersion)"
    $PackageName = "Firefox"
    $InstallerType = "exe"
    $Source = "$PackageName" + "." + "$InstallerType"
    $LogPS = "${env:SystemRoot}" + "\Temp\$Vendor $Product $Version PS Wrapper.log"
    $UnattendedArgs = '/SILENT'
    $url = "$(get-LatestFirefoxURL)"
    $ProgressPreference = 'SilentlyContinue'
    
    Start-Transcript $LogPS
    
    if( -Not (Test-Path -Path $Version ) )
    {
        New-Item -ItemType directory -Path $Version
    }
    
    Set-Location $Version
    
    Write-Verbose "Downloading $Vendor $Product $Version" -Verbose
    If (!(Test-Path -Path $Source)) {
        Invoke-WebRequest -Uri $url -OutFile $Source
             }
            Else {
                Write-Verbose "File exists. Skipping Download." -Verbose
             }
    
    Write-Verbose "Starting Installation of $Vendor $Product $Version" -Verbose
    (Start-Process "$PackageName.$InstallerType" $UnattendedArgs -Wait -Passthru).ExitCode
    
    # Write-Verbose "Customization" -Verbose
    # sc.exe config MozillaMaintenance start= disabled
    
    Write-Verbose "Stop logging" -Verbose
    $EndDTM = (Get-Date)
    Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalSeconds) Seconds" -Verbose
    Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalMinutes) Minutes" -Verbose
    Stop-Transcript