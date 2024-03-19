<# 
.SYNOPSIS
   Install the Libkey Nomad Add-in for Google Chrome & Microsoft Edge and set the LibraryId.

.DESCRIPTION
   Script to install and configure the thirdiron Libkey Nomad Addin for Google Chrome & Microsoft Edge.

.EXAMPLE
   PS C:\> .\Win10-Install-LibkeyNomad.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.
   
.FUNCTIONALITY
   PowerShell v1+
#>

# Install Libkey Nomad Add-in For Chrome.
#Set variables as input for the script
$KeyPathGC = "HKLM:\Software\Policies\Google\Chrome\ExtensionInstallForcelist"
$KeyNameGC = "20"
$KeyTypeGC = "String"
$KeyValueGC = "lkoeejijapdihgbegpljiehpnlkadljb;https://clients2.google.com/service/update2/crx"

$KeyPathGCsetting = "HKLM:\Software\Policies\Google\Chrome\"
$KeyNameGCsetting = "ExtensionSettings"
$KeyTypeGCsetting = "String"
$KeyValueGCsetting = '{"lkoeejijapdihgbegpljiehpnlkadljb": {"toolbar_pin":"force_pinned"}}'

#Verify if the registry path already exists
if(!(Test-Path $KeyPathGC)) {
    try {
        #Create registry path
        New-Item -Path $KeyPathGC -ItemType RegistryKey -Force -ErrorAction Stop
    }
    catch {
        Write-Output "FAILED to create the registry path"
    }
}
 
#Verify if the registry key already exists
if(!((Get-ItemProperty $KeyPathGC).$KeyNameGC)) {
    try {
        #Create registry key 
        New-ItemProperty -Path $KeyPathGC -Name $KeyNameGC -PropertyType $KeyTypeGC -Value $KeyValueGC
    }
    catch {
        Write-Output "FAILED to create the registry key"
    }
}

#Verify if the registry key already exists
if(!((Get-ItemProperty $KeyPathGCsetting).$KeyNameGCsetting)) {
    try {
        #Create registry key 
        New-ItemProperty -Path $KeyPathGCsetting -Name $KeyNameGCsetting -PropertyType $KeyTypeGCsetting -Value $KeyValueGCsetting
    }
    catch {
        Write-Output "FAILED to create the registry key"
    }
}


# Install Libkey Nomad Add-in For Microsoft Edge.
#Set variables as input for the script
$KeyPathEdge = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"
$KeyNameEdge = "20"
$KeyTypeEdge = "String"
$KeyValueEdge = "aegommgkkknipcpebmcbepdapjdojiji;https://edge.microsoft.com/extensionwebstorebase/v1/crx"

$KeyPathMSEsetting = "HKLM:\Software\Policies\Microsoft\Edge\"
$KeyNameMSEsetting = "ExtensionSettings"
$KeyTypeMSEsetting = "String"
$KeyValueMSEsetting = '{"aegommgkkknipcpebmcbepdapjdojiji": {"toolbar_pin":"force_pinned"}}'
 
#Verify if the registry path already exists
if(!(Test-Path $KeyPathEdge)) {
    try {
        #Create registry path
        New-Item -Path $KeyPathEdge -ItemType RegistryKey -Force -ErrorAction Stop
    }
    catch {
        Write-Output "FAILED to create the registry path"
    }
}
 
#Verify if the registry key already exists
if(!((Get-ItemProperty $KeyPathEdge).$KeyNameEdge)) {
    try {
        #Create registry key 
        New-ItemProperty -Path $KeyPathEdge -Name $KeyNameEdge -PropertyType $KeyTypeEdge -Value $KeyValueEdge
    }
    catch {
        Write-Output "FAILED to create the registry key"
    }
}

#Verify if the registry key already exists
if(!((Get-ItemProperty $KeyPathMSEsetting).$KeyNameMSEsetting)) {
    try {
        #Create registry key 
        New-ItemProperty -Path $KeyPathMSEsetting -Name $KeyNameMSEsetting -PropertyType $KeyTypeMSEsetting -Value $KeyValueMSEsetting
    }
    catch {
        Write-Output "FAILED to create the registry key"
    }
}

#Set Libkey Nomad Library Id in Edge & Chrome.
#Set variables as input for the script
$KeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\3rdparty\extensions\aegommgkkknipcpebmcbepdapjdojiji\policy"
$KeyName = "libraryId"
$KeyType = "String"
$KeyValue = "2269"

$KeyPath2 = "HKLM:\Software\Policies\Google\Chrome\3rdparty\extensions\lkoeejijapdihgbegpljiehpnlkadljb\policy"
$KeyName2 = "libraryId"
$KeyType2 = "String"
$KeyValue2 = "2269"

# Check if the variable $KeyPath5 already exists and if it does not create it.   
if(!(Test-Path $KeyPath)) {
    try {
        #Create registry path
        New-Item -Path $KeyPath -ItemType RegistryKey -Force -ErrorAction Stop
    }
    catch {
        Write-Output "FAILED to create the registry path"
    }
}
 
#Verify if the registry path already exists and if it does not create it.
if(!((Get-ItemProperty $KeyPath).$KeyName)) {
    try {
        #Create registry key 
        New-ItemProperty -Path $KeyPath -Name $KeyName -PropertyType $KeyType -Value $KeyValue
    }
    catch {
        Write-Output "FAILED to create the registry key"
    }
}

# Check if the variable $KeyPath6 already exists and if it does not create it.
if(!(Test-Path $KeyPath2)) {
    try {
        #Create registry path
        New-Item -Path $KeyPath2 -ItemType RegistryKey -Force -ErrorAction Stop
    }
    catch {
        Write-Output "FAILED to create the registry path"
    }
}

#Verify if the registry key already exists
if(!((Get-ItemProperty $KeyPath2).$KeyName2)) {
    try {
        #Create registry key 
        New-ItemProperty -Path $KeyPath2 -Name $KeyName2 -PropertyType $KeyType2 -Value $KeyValue2
    }
    catch {
        Write-Output "FAILED to create the registry key"
    }
}