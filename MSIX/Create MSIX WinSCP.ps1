Function New-VersionNumber
{
    Param
    (
        [Parameter(Mandatory)]
        [string]$versionNumber ,
        [switch]$silent
    )

    if( $null -ne ( [version]$version = $versionNumber -as [version] ) )
    {
        if( ( [int]$major = $version.Major ) -lt 0 )
        {
            $major = 0
        }
        if( ( [int]$minor = $version.Minor ) -lt 0 )
        {
            $minor = 0
        }
        if( ( [int]$build = $version.Build ) -lt 0 )
        {
            $build = 0
        }
        if( ( [int]$revision = $version.Revision ) -lt 0 )
        {
            $revision = 0
        }

        ( '{0}.{1}.{2}.{3}' -f $major , $minor , $build , $revision ) -as [version]
    }
    elseif( ! $silent )
    {
        Write-Warning -Message "Failed to convert version number `"$versionNumber`""
    }
}

Clear-Host
Write-Verbose "Setting Arguments" -Verbose
$StartDTM = (Get-Date)

Write-Verbose "Installing Modules" -Verbose
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
Install-PackageProvider -Name 'Nuget' -Force
Install-Module Evergreen -Force | Import-Module Evergreen

$Path = Get-Location
$Path = $Path.Path
$PackageName = "WinSCP"
$Architecture = "x86"
$Evergreen = Get-WinSCP | Where-Object { $_.Architecture -eq "$Architecture" -and $_.URI -like "*.exe" }
$Version = $Evergreen.Version
$Version = New-VersionNumber $Version
$Version = $Version.ToString()
$URL = $Evergreen.uri
$InstallerType = "exe"
$Source = "$PackageName" + "." + "$InstallerType"
$UnattendedArgs = '/verysilent /ALLUSERS'
$Source = "$PackageName" + "." + "$InstallerType"
$Template = "$Path\$PackageName.xml"
$Certificate = "$Path" + "\Test.pfx"
$CertificatePwd = "P@ssw0rd"
$xmlTemplate = "$Path" + "\MSIX_Template.xml"
$ProgressPreference = 'SilentlyContinue'

Write-Verbose "Downloading MSIX Template" -Verbose
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/haavarstein/Applications/master/MSIX_Template.xml" -OutFile $xmlTemplate
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/haavarstein/Applications/master/Modules/Get-MSIDatabaseProperties.ps1" -OutFile Get-MSIDatabaseProperties.ps1

Write-Verbose "Downloading $PackageName $Version" -Verbose
Invoke-WebRequest -Uri $url -OutFile $Source

$MSIXFileName = "$PackageName" + "_" + "$Version" + "_" + "$Architecture.msix"

Write-Verbose "Creating Template XML"
$xml = Get-Content $xmlTemplate
$xml.replace("SetPackagePath","$Path\$MSIXFileName") | Out-File $Template

$xml = Get-Content $Template
$xml.replace("SetTemplatePath","$Template") | Out-File $Template
$xml = Get-Content $Template
$xml.replace("SetInstallerPath","$Path\$Source") | Out-File $Template
$xml = Get-Content $Template
$xml.replace("SetPackageName","$PackageName") | Out-File $Template
$xml = Get-Content $Template
$xml.replace("SetPackageDisplayName","$PackageName") | Out-File $Template
$xml = Get-Content $Template
$xml.replace("SetPublisherDisplayName","$PackageName") | Out-File $Template
$xml = Get-Content $Template
$xml.replace("SetVersion","$Version") | Out-File $Template
$xml = Get-Content $Template
$xml.replace("SetPackageDescription","$PackageName") | Out-File $Template
$xml = Get-Content $Template
$xml.replace("setArguments","/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-") | Out-File $Template

Write-Verbose "Creating $MSIXFileName" -Verbose
MsixPackagingTool.exe create-package --template $Template

Write-Verbose "Signing $MSIXFileName" -Verbose
msixherocli sign --file $Certificate --password $CertificatePwd "$Path\$MSIXFileName"

$EndDTM = (Get-Date)
Write-Verbose "Elapsed Time: $([math]::Round( ($EndDTM-$StartDTM).TotalMinutes )) Minutes" -Verbose