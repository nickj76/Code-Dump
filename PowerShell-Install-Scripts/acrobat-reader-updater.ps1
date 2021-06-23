<# 
.SYNOPSIS
   Adobe Reader Updater 

.DESCRIPTION
   Updates Adobe Reader.

.EXAMPLE
   PS C:\> .\Adobe Reader Updater.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.NOTES
   None.

.FUNCTIONALITY
   PowerShell v3+
#>


# Get Current Adobe reader version.
$CurrentReaderVersion = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Where-Object{$_.DisplayName -like "*Adobe*" -and $_.DisplayName -like "*Reader*"}

# If reader is installed then...
If ($CurrentReaderVersion -ne $null) {

# Tidy version to numeric string.
$CurrentReaderVersion = ($CurrentReaderVersion.DisplayVersion.ToString()).Replace(".","")

# Set download folder and ftp folder variables
$DownloadFolder = "C:\Windows\Temp\"
$FTPFolderUrl = "ftp://ftp.adobe.com/pub/adobe/reader/win/AcrobatDC/"

#connect to ftp, and get directory listing
$FTPRequest = [System.Net.FtpWebRequest]::Create("$FTPFolderUrl")
$FTPRequest.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory
$FTPResponse = $FTPRequest.GetResponse()
$ResponseStream = $FTPResponse.GetResponseStream()
$FTPReader = New-Object System.IO.Streamreader -ArgumentList $ResponseStream
$DirList = $FTPReader.ReadToEnd()

#from Directory Listing get last entry in list, but skip one to avoid the 'misc' dir
$LatestUpdate = $DirList -split '[\r\n]' | Where {$_} | Select -Last 1 -Skip 1

# Compare latest availiable update version to currently installed version.
If ($LatestUpdate -ne $CurrentReaderVersion){

#build file name
$LatestFile = "AcroRdrDC" + $LatestUpdate + "_en_US.exe"

#build download url for latest file
$DownloadURL = "$FTPFolderUrl$LatestUpdate/$LatestFile"

# Build filepath
$FilePath = "$DownloadFolder$LatestFile"

#download file
"1. Downloading latest Reader version."
(New-Object System.Net.WebClient).DownloadFile($DownloadURL, $FilePath)

# Install quietly
"2. Installing."
Start $FilePath /sAll -NoNewWindow -Wait

# Clean up after install
"3. Cleaning."
Remove-Item -Path $FilePath
}

Else
{"Latest version already installed."}
}

Else
{"Reader not installed."}